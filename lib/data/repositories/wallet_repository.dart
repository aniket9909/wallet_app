import '../../core/database/local_app_database.dart';
import '../models/wallet_data_model.dart';
import '../services/firebase_realtime_service.dart';
import '../services/offline_sync_service.dart';

class WalletRepository {
  final FirebaseRealtimeService _firebaseService;
  final LocalAppDatabase _db = LocalAppDatabase.instance;
  final OfflineSyncService _sync = OfflineSyncService.instance;

  WalletRepository(this._firebaseService);

  Stream<WalletDataModel?> watchWalletData() async* {
    yield await _db.loadWallet();
    try {
      await for (final remote in _firebaseService.watchWalletData()) {
        if (remote != null) {
          await _db.saveWallet(remote, synced: true);
        }
        yield remote ?? await _db.loadWallet();
      }
    } catch (_) {
      yield await _db.loadWallet();
    }
  }

  Future<void> updateWalletData(WalletDataModel wallet) async {
    await _db.saveWallet(wallet, synced: false);
    await _sync.enqueueAndMaybeFlush(
      firebase: _firebaseService,
      entity: LocalAppDatabase.entityWallet,
      entityId: LocalAppDatabase.entityWallet,
      action: 'upsert',
      payload: Map<String, dynamic>.from(wallet.toJson()),
      onlineWrite: () async {
        await _firebaseService.updateWalletData(wallet);
        await _db.saveWallet(wallet, synced: true);
      },
    );
  }
}
