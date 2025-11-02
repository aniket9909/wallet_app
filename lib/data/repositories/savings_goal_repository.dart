import '../models/savings_goal_model.dart';
import '../services/firebase_realtime_service.dart';

class SavingsGoalRepository {
  final FirebaseRealtimeService _firebaseService;

  SavingsGoalRepository(this._firebaseService);

  Stream<List<SavingsGoalModel>> watchSavingsGoals() {
    return _firebaseService.watchSavingsGoals();
  }

  Future<void> addSavingsGoal(SavingsGoalModel goal) async {
    await _firebaseService.addSavingsGoal(goal);
  }

  Future<void> updateSavingsGoal(SavingsGoalModel goal) async {
    await _firebaseService.updateSavingsGoal(goal);
  }

  Future<void> deleteSavingsGoal(String goalId) async {
    await _firebaseService.deleteSavingsGoal(goalId);
  }

  Future<void> updateProgress(String goalId, double amount, List<SavingsGoalModel> goals) async {
    final goal = goals.firstWhere((g) => g.id == goalId);
    final updatedGoal = goal.copyWith(savedSoFar: goal.savedSoFar + amount);
    await updateSavingsGoal(updatedGoal);
  }
}

