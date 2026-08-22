import '../../core/database/local_app_database.dart';
import '../models/account_model.dart';
import '../services/firebase_realtime_service.dart';
import '../services/offline_sync_service.dart';

class AccountRepository {
  final FirebaseRealtimeService _firebaseService;
  final LocalAppDatabase _db = LocalAppDatabase.instance;
  final OfflineSyncService _sync = OfflineSyncService.instance;

  AccountRepository(this._firebaseService);

  Stream<List<AccountModel>> watchAccounts() async* {
    yield await _db.getAccounts();
    try {
      await for (final remote in _firebaseService.watchAccounts()) {
        if (remote.isNotEmpty || _firebaseService.isAuthenticated) {
          await _db.replaceAccounts(remote, synced: true);
        }
        yield await _db.getAccounts();
      }
    } catch (_) {
      yield await _db.getAccounts();
    }
  }

  Future<void> addAccount(AccountModel account) async {
    final local = account.id.isEmpty
        ? account.copyWith(id: _db.newId())
        : account;
    await _db.upsertAccount(local, synced: false);
    await _sync.enqueueAndMaybeFlush(
      firebase: _firebaseService,
      entity: LocalAppDatabase.accountsTable,
      entityId: local.id,
      action: 'upsert',
      payload: {'id': local.id, ...local.toJson()},
      onlineWrite: () async {
        await _firebaseService.upsertAccount(local);
        await _db.upsertAccount(local, synced: true);
      },
    );
  }

  Future<void> updateAccount(AccountModel account) async {
    await _db.upsertAccount(account, synced: false);
    await _sync.enqueueAndMaybeFlush(
      firebase: _firebaseService,
      entity: LocalAppDatabase.accountsTable,
      entityId: account.id,
      action: 'upsert',
      payload: {'id': account.id, ...account.toJson()},
      onlineWrite: () async {
        await _firebaseService.updateAccount(account);
        await _db.upsertAccount(account, synced: true);
      },
    );
  }

  Future<void> deleteAccount(String accountId) async {
    await _db.markAccountDeleted(accountId);
    await _sync.enqueueAndMaybeFlush(
      firebase: _firebaseService,
      entity: LocalAppDatabase.accountsTable,
      entityId: accountId,
      action: 'delete',
      onlineWrite: () async {
        await _firebaseService.deleteAccount(accountId);
      },
    );
  }
}
