import '../models/investment_model.dart';
import '../services/firebase_realtime_service.dart';

class InvestmentRepository {
  final FirebaseRealtimeService _firebaseService;

  InvestmentRepository(this._firebaseService);

  Stream<List<InvestmentModel>> watchInvestments() {
    return _firebaseService.watchInvestments();
  }

  Future<String> addInvestment(InvestmentModel investment) async {
    return await _firebaseService.addInvestment(investment);
  }

  Future<void> updateInvestment(InvestmentModel investment) async {
    await _firebaseService.updateInvestment(investment);
  }

  Future<void> deleteInvestment(String investmentId) async {
    await _firebaseService.deleteInvestment(investmentId);
  }

  double getTotalInvested(List<InvestmentModel> investments) {
    return investments.fold(0.0, (sum, inv) => sum + inv.investedAmount);
  }

  double getTotalCurrentValue(List<InvestmentModel> investments) {
    return investments.fold(0.0, (sum, inv) => sum + inv.currentValue);
  }

  double getTotalProfit(List<InvestmentModel> investments) {
    return investments.fold(0.0, (sum, inv) => sum + inv.profit);
  }

  double getTotalProfitPercentage(List<InvestmentModel> investments) {
    final totalInvested = getTotalInvested(investments);
    if (totalInvested == 0) return 0;
    final totalCurrent = getTotalCurrentValue(investments);
    return ((totalCurrent - totalInvested) / totalInvested * 100);
  }
}

