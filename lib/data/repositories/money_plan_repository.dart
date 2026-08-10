import '../models/money_plan_model.dart';
import '../services/firebase_realtime_service.dart';

class MoneyPlanRepository {
  final FirebaseRealtimeService _firebaseService;

  MoneyPlanRepository(this._firebaseService);

  Stream<MoneyPlanModel?> watchMoneyPlan() {
    return _firebaseService.watchMoneyPlan();
  }

  Future<void> saveMoneyPlan(MoneyPlanModel plan) async {
    await _firebaseService.saveMoneyPlan(
      plan.copyWith(updatedAt: DateTime.now()),
    );
  }
}
