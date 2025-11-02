import '../models/transaction_model_new.dart';
import '../services/firebase_realtime_service.dart';

class TransactionRepository {
  final FirebaseRealtimeService _firebaseService;

  TransactionRepository(this._firebaseService);

  Stream<List<TransactionModelNew>> watchTransactions() {
    return _firebaseService.watchTransactions();
  }

  Future<String> addTransaction(TransactionModelNew transaction) async {
    return await _firebaseService.addTransaction(transaction);
  }

  Future<void> updateTransaction(TransactionModelNew transaction) async {
    await _firebaseService.updateTransaction(transaction);
  }

  Future<void> deleteTransaction(String transactionId) async {
    await _firebaseService.deleteTransaction(transactionId);
  }

  // Additional utility methods
  List<TransactionModelNew> filterByDateRange(
    List<TransactionModelNew> transactions,
    DateTime startDate,
    DateTime endDate,
  ) {
    return transactions
        .where((t) => t.date.isAfter(startDate) && t.date.isBefore(endDate))
        .toList();
  }

  List<TransactionModelNew> filterByCategory(
    List<TransactionModelNew> transactions,
    String category,
  ) {
    return transactions.where((t) => t.category == category).toList();
  }

  List<TransactionModelNew> filterByAccount(
    List<TransactionModelNew> transactions,
    String account,
  ) {
    return transactions.where((t) => t.account == account).toList();
  }

  Map<String, double> getCategoryExpenses(List<TransactionModelNew> transactions) {
    final Map<String, double> categoryExpenses = {};
    
    for (var transaction in transactions) {
      if (transaction.type == TransactionType.debit) {
        categoryExpenses[transaction.category] =
            (categoryExpenses[transaction.category] ?? 0) + transaction.amount;
      }
    }
    
    return categoryExpenses;
  }
}

