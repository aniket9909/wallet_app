class SmsDetectionUtil {
  /// Checks if SMS is a credit/debit transaction and extracts details
  static SmsDetectionResult? detectCreditDebit(String body) {
    final lower = body.toLowerCase();
    
    // Check for credit keywords
    final isCredit = lower.contains('credited') ||
        lower.contains('cr.') ||
        lower.contains('cr ') ||
        lower.contains('received') ||
        lower.contains('credit') ||
        lower.contains('deposited');
    
    // Check for debit keywords
    final isDebit = lower.contains('debited') ||
        lower.contains('dr.') ||
        lower.contains('dr ') ||
        lower.contains('spent') ||
        lower.contains('withdrawn') ||
        lower.contains('debit') ||
        lower.contains('paid');
    
    if (!isCredit && !isDebit) {
      return null; // Not a credit/debit SMS
    }
    
    // Extract amount
    final amountRegex = RegExp(r'(inr|rs\.?|₹|rupees?)\s*([0-9,]+\.?[0-9]*)',
        caseSensitive: false);
    final match = amountRegex.firstMatch(body);
    if (match == null) {
      return null; // No amount found
    }
    
    final raw = match.group(2) ?? '';
    final normalized = raw.replaceAll(',', '');
    final amount = double.tryParse(normalized);
    if (amount == null) {
      return null; // Invalid amount
    }
    
    return SmsDetectionResult(
      isCreditDebit: true,
      isCredit: isCredit,
      amount: amount,
      transactionType: isCredit ? 'credit' : 'debit',
    );
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
    final fromName = extractFromName(body);
    if (fromName != null) return fromName;

    final patterns = <RegExp>[
      RegExp(
        r'(?:paid|sent|transfer(?:red)?|trf|debited|credited)\s+to\s+'
        r'([A-Za-z0-9][A-Za-z0-9 .&/@_-]{1,48}?)(?:\s+on|\s+at|\s+ref|\s+avl|\.|,|\s+bal|\s+upi|$)',
        caseSensitive: false,
      ),
      RegExp(r'upi[/-](?:\d+/)*([^/\n]+)', caseSensitive: false),
      RegExp(
        r'\bat\s+([A-Za-z0-9][A-Za-z0-9 .&_-]{1,48}?)(?:\s+on|\s+ref|\.|,|\s+bal|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:info|desc(?:ription)?|remarks?)\s*:?\s*([A-Za-z0-9][A-Za-z0-9 .&/@_-]{1,48})',
        caseSensitive: false,
      ),
      RegExp(
        r'towards?\s+([A-Za-z0-9][A-Za-z0-9 .&_-]{1,48}?)(?:\.|,|\s+on|$)',
        caseSensitive: false,
      ),
      RegExp(r'\b([A-Za-z0-9._-]{2,30}@[A-Za-z0-9]+)\b'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match == null) continue;
      final raw = match.group(1)?.trim();
      if (raw == null || raw.isEmpty) continue;
      final cleaned = _cleanExtractedName(raw);
      if (cleaned != null) return cleaned;
    }

    return null;
  }

  static String? _cleanExtractedName(String raw) {
    var name = raw
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[:\-\s]+'), '')
        .replaceAll(RegExp(r'[.\s]+$'), '')
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

    final fromName = extractFromName(smsBody);
    if (fromName != null && fromName.isNotEmpty) {
      return 'SMS from $fromName';
    }

    return transactionType == 'credit' ? 'SMS credit' : 'SMS debit';
  }

  /// Suggested description shown in the sync setup field.
  static String? suggestedSyncDescription({
    required String smsBody,
    String? transactionType,
  }) {
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

