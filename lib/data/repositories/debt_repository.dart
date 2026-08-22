import '../../core/database/local_app_database.dart';
import '../models/debt_model.dart';
import '../services/firebase_realtime_service.dart';

class DebtRepository {
  final FirebaseRealtimeService _firebaseService;
  final LocalAppDatabase _db = LocalAppDatabase.instance;

  DebtRepository(this._firebaseService);

  Stream<List<DebtModel>> watchDebts() async* {
    yield _parse(await _db.getEntityList(LocalAppDatabase.entityDebts));
    try {
      await for (final remote in _firebaseService.watchDebts()) {
        await _save(remote, synced: true);
        yield remote;
      }
    } catch (_) {
      yield _parse(await _db.getEntityList(LocalAppDatabase.entityDebts));
    }
  }

  Future<String> addDebt(DebtModel debt) async {
    final local = debt.id.isEmpty ? debt.copyWith(id: _db.newId()) : debt;
    final items = _parse(await _db.getEntityList(LocalAppDatabase.entityDebts));
    items.insert(0, local);
    await _save(items);
    try {
      await _firebaseService.addDebt(local);
    } catch (_) {
      await _db.enqueue(
        entity: LocalAppDatabase.entityDebts,
        entityId: local.id,
        action: 'upsert',
        payload: {'id': local.id, ...local.toJson()},
      );
    }
    return local.id;
  }

  Future<void> updateDebt(DebtModel debt) async {
    final items = _parse(await _db.getEntityList(LocalAppDatabase.entityDebts));
    final index = items.indexWhere((d) => d.id == debt.id);
    if (index >= 0) {
      items[index] = debt;
    } else {
      items.insert(0, debt);
    }
    await _save(items);
    try {
      await _firebaseService.updateDebt(debt);
    } catch (_) {
      await _db.enqueue(
        entity: LocalAppDatabase.entityDebts,
        entityId: debt.id,
        action: 'upsert',
        payload: {'id': debt.id, ...debt.toJson()},
      );
    }
  }

  Future<void> deleteDebt(String debtId) async {
    final items = _parse(await _db.getEntityList(LocalAppDatabase.entityDebts));
    items.removeWhere((d) => d.id == debtId);
    await _save(items);
    try {
      await _firebaseService.deleteDebt(debtId);
    } catch (_) {
      await _db.enqueue(
        entity: LocalAppDatabase.entityDebts,
        entityId: debtId,
        action: 'delete',
      );
    }
  }

  Future<void> updatePayment(String debtId, double amount, List<DebtModel> debts) async {
    final debt = debts.firstWhere((d) => d.id == debtId);
    final newPaidAmount = (debt.paidAmount + amount).clamp(0, debt.amount);
    final isPaid = newPaidAmount >= debt.amount;

    await updateDebt(debt.copyWith(
      paidAmount: newPaidAmount.toDouble(),
      isPaid: isPaid,
    ));
  }

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

  List<DebtModel> _parse(List<Map<String, dynamic>> items) {
    return items
        .map((e) => DebtModel.fromJson(e['id']?.toString() ?? '', e))
        .toList();
  }

  Future<void> _save(List<DebtModel> items, {bool synced = false}) {
    return _db.putEntityList(
      LocalAppDatabase.entityDebts,
      items.map((d) => {'id': d.id, ...d.toJson()}).toList(),
      synced: synced,
    );
  }
}
