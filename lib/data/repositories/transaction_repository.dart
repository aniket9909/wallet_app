import '../../core/database/local_app_database.dart';
import '../models/transaction_model_new.dart';
import '../services/firebase_realtime_service.dart';
import '../services/offline_sync_service.dart';

class TransactionRepository {
  final FirebaseRealtimeService _firebaseService;
  final LocalAppDatabase _db = LocalAppDatabase.instance;
  final OfflineSyncService _sync = OfflineSyncService.instance;

  TransactionRepository(this._firebaseService);

  Stream<List<TransactionModelNew>> watchTransactions() async* {
    yield await _db.loadTransactions();
    try {
      await for (final remote in _firebaseService.watchTransactions()) {
        if (remote.isNotEmpty || _firebaseService.isAuthenticated) {
          await _db.saveTransactions(remote, synced: true);
        }
        yield await _db.loadTransactions();
      }
    } catch (_) {
      yield await _db.loadTransactions();
    }
  }

  Future<String> addTransaction(TransactionModelNew transaction) async {
    final local = transaction.id.isEmpty
        ? transaction.copyWith(id: _db.newId())
        : transaction;
    final current = await _db.loadTransactions();
    current.insert(0, local);
    await _db.saveTransactions(current, synced: false);
    await _sync.enqueueAndMaybeFlush(
      firebase: _firebaseService,
      entity: LocalAppDatabase.entityTransactions,
      entityId: local.id,
      action: 'upsert',
      payload: {'id': local.id, ...local.toJson()},
      onlineWrite: () async {
        await _firebaseService.upsertTransaction(local);
      },
    );
    return local.id;
  }

  Future<void> updateTransaction(TransactionModelNew transaction) async {
    final current = await _db.loadTransactions();
    final index = current.indexWhere((t) => t.id == transaction.id);
    if (index >= 0) {
      current[index] = transaction;
    } else {
      current.insert(0, transaction);
    }
    await _db.saveTransactions(current, synced: false);
    await _sync.enqueueAndMaybeFlush(
      firebase: _firebaseService,
      entity: LocalAppDatabase.entityTransactions,
      entityId: transaction.id,
      action: 'upsert',
      payload: {'id': transaction.id, ...transaction.toJson()},
      onlineWrite: () async {
        await _firebaseService.updateTransaction(transaction);
      },
    );
  }

  Future<void> deleteTransaction(String transactionId) async {
    final current = await _db.loadTransactions();
    current.removeWhere((t) => t.id == transactionId);
    await _db.saveTransactions(current, synced: false);
    await _sync.enqueueAndMaybeFlush(
      firebase: _firebaseService,
      entity: LocalAppDatabase.entityTransactions,
      entityId: transactionId,
      action: 'delete',
      onlineWrite: () async {
        await _firebaseService.deleteTransaction(transactionId);
      },
    );
  }

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
