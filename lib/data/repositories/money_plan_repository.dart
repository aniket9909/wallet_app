import '../../core/database/local_app_database.dart';
import '../models/money_plan_model.dart';
import '../services/firebase_realtime_service.dart';
import '../services/offline_sync_service.dart';

class MoneyPlanRepository {
  final FirebaseRealtimeService _firebaseService;
  final LocalAppDatabase _db = LocalAppDatabase.instance;
  final OfflineSyncService _sync = OfflineSyncService.instance;

  MoneyPlanRepository(this._firebaseService);

  Stream<MoneyPlanModel?> watchMoneyPlan() async* {
    yield await _db.loadMoneyPlan();
    try {
      await for (final remote in _firebaseService.watchMoneyPlan()) {
        if (remote != null) {
          await _db.saveMoneyPlan(remote, synced: true);
        }
        yield remote ?? await _db.loadMoneyPlan();
      }
    } catch (_) {
      yield await _db.loadMoneyPlan();
    }
  }

  Future<void> saveMoneyPlan(MoneyPlanModel plan) async {
    final updated = plan.copyWith(updatedAt: DateTime.now());
    await _db.saveMoneyPlan(updated, synced: false);
    await _sync.enqueueAndMaybeFlush(
      firebase: _firebaseService,
      entity: LocalAppDatabase.entityMoneyPlan,
      entityId: LocalAppDatabase.entityMoneyPlan,
      action: 'upsert',
      payload: Map<String, dynamic>.from(updated.toJson()),
      onlineWrite: () async {
        await _firebaseService.saveMoneyPlan(updated);
        await _db.saveMoneyPlan(updated, synced: true);
      },
    );
  }
}
