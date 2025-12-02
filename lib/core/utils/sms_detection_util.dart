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

