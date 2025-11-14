import '../models/debt_model.dart';
import '../services/firebase_realtime_service.dart';

class DebtRepository {
  final FirebaseRealtimeService _firebaseService;

  DebtRepository(this._firebaseService);

  Stream<List<DebtModel>> watchDebts() {
    return _firebaseService.watchDebts();
  }

  Future<String> addDebt(DebtModel debt) async {
    return await _firebaseService.addDebt(debt);
  }

  Future<void> updateDebt(DebtModel debt) async {
    await _firebaseService.updateDebt(debt);
  }

  Future<void> deleteDebt(String debtId) async {
    await _firebaseService.deleteDebt(debtId);
  }

  Future<void> updatePayment(String debtId, double amount, List<DebtModel> debts) async {
    final debt = debts.firstWhere((d) => d.id == debtId);
    final newPaidAmount = (debt.paidAmount + amount).clamp(0, debt.amount);
    final isPaid = newPaidAmount >= debt.amount;
    
    await updateDebt(debt.copyWith(
      paidAmount: newPaidAmount.toDouble(),
      isPaid: isPaid,
    ));

  double getTotalBorrowed(List<DebtModel> debts) {
    return debts
        .where((d) => d.type == DebtType.borrow && !d.isPaid)
        .fold(0.0, (sum, debt) => sum + debt.remainingAmount);
  }

  double getTotalLent(List<DebtModel> debts) {
    return debts
        .where((d) => d.type == DebtType.lend && !d.isPaid)
        .fold(0.0, (sum, debt) => sum + debt.remainingAmount);
  }
}

}