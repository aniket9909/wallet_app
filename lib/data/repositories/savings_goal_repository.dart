import '../../core/database/local_app_database.dart';
import '../models/savings_goal_model.dart';
import '../services/firebase_realtime_service.dart';

class SavingsGoalRepository {
  final FirebaseRealtimeService _firebaseService;
  final LocalAppDatabase _db = LocalAppDatabase.instance;

  SavingsGoalRepository(this._firebaseService);

  Stream<List<SavingsGoalModel>> watchSavingsGoals() async* {
    yield _parse(await _db.getEntityList(LocalAppDatabase.entityGoals));
    try {
      await for (final remote in _firebaseService.watchSavingsGoals()) {
        await _save(remote, synced: true);
        yield remote;
      }
    } catch (_) {
      yield _parse(await _db.getEntityList(LocalAppDatabase.entityGoals));
    }
  }

  Future<void> addSavingsGoal(SavingsGoalModel goal) async {
    final local = goal.id.isEmpty ? goal.copyWith(id: _db.newId()) : goal;
    final items = _parse(await _db.getEntityList(LocalAppDatabase.entityGoals));
    items.insert(0, local);
    await _save(items);
    try {
      await _firebaseService.addSavingsGoal(local);
    } catch (_) {
      await _db.enqueue(
        entity: LocalAppDatabase.entityGoals,
        entityId: local.id,
        action: 'upsert',
        payload: {'id': local.id, ...local.toJson()},
      );
    }
  }

  Future<void> updateSavingsGoal(SavingsGoalModel goal) async {
    final items = _parse(await _db.getEntityList(LocalAppDatabase.entityGoals));
    final index = items.indexWhere((g) => g.id == goal.id);
    if (index >= 0) {
      items[index] = goal;
    } else {
      items.insert(0, goal);
    }
    await _save(items);
    try {
      await _firebaseService.updateSavingsGoal(goal);
    } catch (_) {
      await _db.enqueue(
        entity: LocalAppDatabase.entityGoals,
        entityId: goal.id,
        action: 'upsert',
        payload: {'id': goal.id, ...goal.toJson()},
      );
    }
  }

  Future<void> deleteSavingsGoal(String goalId) async {
    final items = _parse(await _db.getEntityList(LocalAppDatabase.entityGoals));
    items.removeWhere((g) => g.id == goalId);
    await _save(items);
    try {
      await _firebaseService.deleteSavingsGoal(goalId);
    } catch (_) {
      await _db.enqueue(
        entity: LocalAppDatabase.entityGoals,
        entityId: goalId,
        action: 'delete',
      );
    }
  }

  Future<void> updateProgress(
    String goalId,
    double amount,
    List<SavingsGoalModel> goals,
  ) async {
    final goal = goals.firstWhere((g) => g.id == goalId);
    final updatedGoal = goal.copyWith(savedSoFar: goal.savedSoFar + amount);
    await updateSavingsGoal(updatedGoal);
  }

  List<SavingsGoalModel> _parse(List<Map<String, dynamic>> items) {
    return items
        .map((e) => SavingsGoalModel.fromJson(e['id']?.toString() ?? '', e))
        .toList();
  }

  Future<void> _save(List<SavingsGoalModel> items, {bool synced = false}) {
    return _db.putEntityList(
      LocalAppDatabase.entityGoals,
      items.map((g) => {'id': g.id, ...g.toJson()}).toList(),
      synced: synced,
    );
  }
}
