class SmsDetectionUtil {
  /// TEMP TEST: any SMS from this number is treated as a debit transaction.
  static const String testSenderDigits = '7678029909';

  /// Currency + amount: supports `Rs.19.40`, `Rs 19.40`, `INR1,234.50`, `₹19.40`.
  static final RegExp amountRegex = RegExp(
    r'(?:(?:inr|rs|rupees?)\.?\s*|₹\s*)([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  /// Fallback when currency is omitted: `amount 19.40` / `txn of 19.40`.
  static final RegExp amountFallbackRegex = RegExp(
    r'(?:amount|amt|txn(?:\s+of)?|of)\s*(?:is\s*)?(?:inr|rs\.?|₹)?\s*([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  static bool isTestSender(String address) {
    final digits = address.replaceAll(RegExp(r'\D'), '');
    return digits.endsWith(testSenderDigits);
  }

  /// Checks if SMS is a credit/debit transaction and extracts details.
  static SmsDetectionResult? detectCreditDebit(String body, {String? address}) {
    // TEMP TEST: accept SMS from test number even without bank keywords.
    if (address != null && isTestSender(address)) {
      final amount = extractAmount(body) ?? 1.0;
      return SmsDetectionResult(
        isCreditDebit: true,
        isCredit: false,
        amount: amount,
        transactionType: 'debit',
      );
    }

    final lower = body.toLowerCase();

    final isCredit = _matchesAny(lower, const [
      r'\bcredited\b',
      r'\bcr\.?\b',
      r'\breceived\b',
      r'\bcredit(?:ed)?\b',
      r'\bdeposited\b',
      r'\badded\s+to\b',
      r'\bmoney\s+received\b',
    ]);

    // Includes UPI "Sent Rs…" Kotak/SBI style messages.
    final isDebit = _matchesAny(lower, const [
      r'\bdebited\b',
      r'\bdr\.?\b',
      r'\bspent\b',
      r'\bwithdrawn\b',
      r'\bdebit(?:ed)?\b',
      r'\bpaid\b',
      r'\bsent\b',
      r'\btransfer(?:red)?\b',
      r'\bpurchase(?:d)?\b',
      r'\bpayment\b',
      r'\bwithdraw(?:al|n)?\b',
      r'\bupi\s+(?:ref|txn|payment)\b',
      r'\bcharged\b',
    ]);

    if (!isCredit && !isDebit) {
      return null;
    }

    final amount = extractAmount(body);
    if (amount == null) {
      return null;
    }

    // Prefer debit when both match (e.g. "credit card … paid").
    final treatAsCredit = isCredit && !isDebit;

    return SmsDetectionResult(
      isCreditDebit: true,
      isCredit: treatAsCredit,
      amount: amount,
      transactionType: treatAsCredit ? 'credit' : 'debit',
    );
  }

  /// Extracts the first plausible money amount from SMS body.
  static double? extractAmount(String body) {
    for (final regex in [amountRegex, amountFallbackRegex]) {
      for (final match in regex.allMatches(body)) {
        final raw = (match.group(1) ?? '').replaceAll(',', '');
        final amount = double.tryParse(raw);
        if (amount != null && amount > 0 && amount < 100000000) {
          return amount;
        }
      }
    }
    return null;
  }

  static bool _matchesAny(String lower, List<String> patterns) {
    for (final p in patterns) {
      if (RegExp(p).hasMatch(lower)) return true;
    }
    return false;
  }

  /// Extracts the name that appears after "from" in bank SMS text.
  static String? extractFromName(String body) {
    final patterns = <RegExp>[
      RegExp(
        r'\bfrom\s+([A-Za-z0-9][A-Za-z0-9 .&/@_-]{1,48}?)(?:\s+on|\s+at|\s+to|\s+ref|\s+avl|\s+through|\.|,|\s+bal|\s+upi|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:received|credited|credit)\s+from\s+([A-Za-z0-9][A-Za-z0-9 .&/@_-]{1,48}?)(?:\s+on|\.|,|\s+ref|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:paid|sent|transfer(?:red)?|trf|debited)\s+from\s+([A-Za-z0-9][A-Za-z0-9 .&/@_-]{1,48}?)(?:\s+on|\s+at|\s+ref|\.|,|\s+bal|$)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match == null) continue;
      final cleaned = _cleanExtractedName(match.group(1)?.trim() ?? '');
      if (cleaned != null) return cleaned;
    }

    return null;
  }

  /// Tries to extract merchant / payee name from other common bank SMS formats.
  static String? extractPayeeName(String body) {
    final patterns = <RegExp>[
      // Prefer full UPI VPA when present: bdpg2.iruts@sbi
      RegExp(r'\b([A-Za-z0-9][A-Za-z0-9._-]{1,40}@[A-Za-z0-9]+)\b'),
      // "Sent Rs.19.40 from Kotak Bank AC to payee on …"
      RegExp(
        r'(?:paid|sent|transfer(?:red)?|trf|debited|credited)\b[\s\S]{0,80}?\bto\s+'
        r'([A-Za-z0-9][A-Za-z0-9 .&/@_-]{1,48}?)(?=\s+on\b|\s+at\b|\s+ref\b|\s+avl\b|\s+upi\b|,|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:paid|sent|transfer(?:red)?|trf|debited|credited)\s+to\s+'
        r'([A-Za-z0-9][A-Za-z0-9 .&/@_-]{1,48}?)(?=\s+on\b|\s+at\b|\s+ref\b|\s+avl\b|,|$)',
        caseSensitive: false,
      ),
      RegExp(r'upi[/-](?:\d+/)*([^/\n]+)', caseSensitive: false),
      RegExp(
        r'\bat\s+([A-Za-z0-9][A-Za-z0-9 .&_-]{1,48}?)(?=\s+on\b|\s+ref\b|,|\s+bal\b|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:info|desc(?:ription)?|remarks?)\s*:?\s*([A-Za-z0-9][A-Za-z0-9 .&/@_-]{1,48})',
        caseSensitive: false,
      ),
      RegExp(
        r'towards?\s+([A-Za-z0-9][A-Za-z0-9 .&_-]{1,48}?)(?=\.|,|\s+on\b|$)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match == null) continue;
      final raw = match.group(1)?.trim();
      if (raw == null || raw.isEmpty) continue;
      final cleaned = _cleanExtractedName(raw);
      if (cleaned != null) return cleaned;
    }

    return extractFromName(body);
  }

  static String? _cleanExtractedName(String raw) {
    var name = raw
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[:\-\s]+'), '')
        .replaceAll(RegExp(r'[.\s]+$'), '')
        .trim();

    // Drop trailing bank account fluff: "Kotak Bank AC"
    name = name
        .replaceAll(
          RegExp(r'\b(?:bank\s+)?a/?c(?:ct)?\b.*$', caseSensitive: false),
          '',
        )
        .trim();

    if (name.length < 2 || name.length > 60) return null;

    final lower = name.toLowerCase();
    const skip = {
      'inr',
      'rs',
      'avl',
      'bal',
      'balance',
      'account',
      'a/c',
      'ac',
      'upi',
      'ref',
      'no',
      'the',
      'your',
      'bank',
      'kotak',
      'sbi',
      'hdfc',
      'icici',
      'axis',
    };
    if (skip.contains(lower)) return null;
    if (RegExp(r'^\d+$').hasMatch(name)) return null;

    return name;
  }

  /// Resolves transaction description for SMS sync.
  static String resolveSyncDescription({
    required String smsBody,
    String? userDescription,
    String? transactionType,
  }) {
    final entered = userDescription?.trim();
    if (entered != null && entered.isNotEmpty) return entered;

    final suggested = suggestedSyncDescription(
      smsBody: smsBody,
      transactionType: transactionType,
    );
    if (suggested != null && suggested.isNotEmpty) return suggested;

    return transactionType == 'credit' ? 'SMS credit' : 'SMS debit';
  }

  /// Suggested description shown in the sync setup field.
  static String? suggestedSyncDescription({
    required String smsBody,
    String? transactionType,
  }) {
    final payee = extractPayeeName(smsBody);
    if (payee != null && payee.isNotEmpty) {
      if (transactionType == 'credit') return 'SMS from $payee';
      return 'SMS to $payee';
    }

    final fromName = extractFromName(smsBody);
    if (fromName != null && fromName.isNotEmpty) {
      return 'SMS from $fromName';
    }
    return null;
  }
}

class SmsDetectionResult {
  final bool isCreditDebit;
  final bool isCredit;
  final double amount;
  final String transactionType;

  SmsDetectionResult({
    required this.isCreditDebit,
    required this.isCredit,
    required this.amount,
    required this.transactionType,
  });
}
