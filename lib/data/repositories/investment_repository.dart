import '../../core/database/local_app_database.dart';
import '../models/investment_model.dart';
import '../services/firebase_realtime_service.dart';

class InvestmentRepository {
  final FirebaseRealtimeService _firebaseService;
  final LocalAppDatabase _db = LocalAppDatabase.instance;

  InvestmentRepository(this._firebaseService);

  Stream<List<InvestmentModel>> watchInvestments() async* {
    yield _parse(await _db.getEntityList(LocalAppDatabase.entityInvestments));
    try {
      await for (final remote in _firebaseService.watchInvestments()) {
        await _save(remote, synced: true);
        yield remote;
      }
    } catch (_) {
      yield _parse(await _db.getEntityList(LocalAppDatabase.entityInvestments));
    }
  }

  Future<String> addInvestment(InvestmentModel investment) async {
    final local =
        investment.id.isEmpty ? investment.copyWith(id: _db.newId()) : investment;
    final items =
        _parse(await _db.getEntityList(LocalAppDatabase.entityInvestments));
    items.insert(0, local);
    await _save(items);
    try {
      await _firebaseService.addInvestment(local);
    } catch (_) {
      await _db.enqueue(
        entity: LocalAppDatabase.entityInvestments,
        entityId: local.id,
        action: 'upsert',
        payload: {'id': local.id, ...local.toJson()},
      );
    }
    return local.id;
  }

  Future<void> updateInvestment(InvestmentModel investment) async {
    final items =
        _parse(await _db.getEntityList(LocalAppDatabase.entityInvestments));
    final index = items.indexWhere((i) => i.id == investment.id);
    if (index >= 0) {
      items[index] = investment;
    } else {
      items.insert(0, investment);
    }
    await _save(items);
    try {
      await _firebaseService.updateInvestment(investment);
    } catch (_) {
      await _db.enqueue(
        entity: LocalAppDatabase.entityInvestments,
        entityId: investment.id,
        action: 'upsert',
        payload: {'id': investment.id, ...investment.toJson()},
      );
    }
  }

  Future<void> deleteInvestment(String investmentId) async {
    final items =
        _parse(await _db.getEntityList(LocalAppDatabase.entityInvestments));
    items.removeWhere((i) => i.id == investmentId);
    await _save(items);
    try {
      await _firebaseService.deleteInvestment(investmentId);
    } catch (_) {
      await _db.enqueue(
        entity: LocalAppDatabase.entityInvestments,
        entityId: investmentId,
        action: 'delete',
      );
    }
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

  List<InvestmentModel> _parse(List<Map<String, dynamic>> items) {
    return items
        .map((e) => InvestmentModel.fromJson(e['id']?.toString() ?? '', e))
        .toList();
  }

  Future<void> _save(List<InvestmentModel> items, {bool synced = false}) {
    return _db.putEntityList(
      LocalAppDatabase.entityInvestments,
      items.map((i) => {'id': i.id, ...i.toJson()}).toList(),
      synced: synced,
    );
  }
}
