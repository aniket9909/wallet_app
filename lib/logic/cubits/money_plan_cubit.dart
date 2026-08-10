import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/money_plan_model.dart';
import '../../data/repositories/money_plan_repository.dart';
import '../../data/services/money_plan_engine.dart';
import '../../data/services/overlay_cache_service.dart';

abstract class MoneyPlanState extends Equatable {
  @override
  List<Object?> get props => [];
}

class MoneyPlanInitial extends MoneyPlanState {}

class MoneyPlanLoading extends MoneyPlanState {}

class MoneyPlanLoaded extends MoneyPlanState {
  final MoneyPlanModel plan;
  final MoneyPlanSnapshot snapshot;
  final ReallocationSuggestion? pendingSuggestion;

  MoneyPlanLoaded({
    required this.plan,
    required this.snapshot,
    this.pendingSuggestion,
  });

  MoneyPlanLoaded copyWith({
    MoneyPlanModel? plan,
    MoneyPlanSnapshot? snapshot,
    ReallocationSuggestion? pendingSuggestion,
    bool clearSuggestion = false,
  }) {
    return MoneyPlanLoaded(
      plan: plan ?? this.plan,
      snapshot: snapshot ?? this.snapshot,
      pendingSuggestion:
          clearSuggestion ? null : (pendingSuggestion ?? this.pendingSuggestion),
    );
  }

  @override
  List<Object?> get props => [plan, snapshot, pendingSuggestion];
}

class MoneyPlanError extends MoneyPlanState {
  final String message;

  MoneyPlanError(this.message);

  @override
  List<Object?> get props => [message];
}

class MoneyPlanCubit extends Cubit<MoneyPlanState> {
  final MoneyPlanRepository _repository;
  final MoneyPlanEngine _engine;
  StreamSubscription? _subscription;
  MoneyPlanModel? _lastPlan;

  MoneyPlanCubit(
    this._repository, {
    MoneyPlanEngine engine = const MoneyPlanEngine(),
  })  : _engine = engine,
        super(MoneyPlanInitial());

  void loadPlan() {
    emit(MoneyPlanLoading());
    _subscription?.cancel();
    _subscription = _repository.watchMoneyPlan().listen(
      (plan) {
        final resolved = plan ?? const MoneyPlanModel();
        _lastPlan = resolved;
        final refreshed = _engine.refreshDynamicTargets(resolved);
        emit(MoneyPlanLoaded(
          plan: refreshed,
          snapshot: _engine.analyze(refreshed),
        ));
        OverlayCacheService.syncFromState(moneyPlan: refreshed);
      },
      onError: (error) {
        emit(MoneyPlanError(error.toString()));
      },
    );
  }

  Future<void> savePlan(MoneyPlanModel plan) async {
    try {
      final refreshed = _engine.refreshDynamicTargets(plan);
      await _repository.saveMoneyPlan(refreshed);
    } catch (e) {
      emit(MoneyPlanError(e.toString()));
      _reloadAfterError();
    }
  }

  Future<void> completeSetup(MoneyPlanModel plan) async {
    await savePlan(plan.copyWith(setupComplete: true));
  }

  Future<void> updateIncome(PlanIncome income) async {
    final current = _currentPlan;
    if (current == null) return;
    final previous = current.income.availableMonthlyIncome;
    final next = current.copyWith(income: income);
    final delta = income.availableMonthlyIncome - previous;

    ReallocationSuggestion? suggestion;
    if (delta > 1) {
      suggestion = _engine.suggestIncomeIncrease(extra: delta, plan: next);
    } else if (delta < -1) {
      // Surface reduction tips via suggestion description.
      final tips = _engine.suggestIncomeReduction(
        shortfall: -delta,
        plan: next,
      );
      suggestion = ReallocationSuggestion(
        title: 'Your plan is ₹${(-delta).toStringAsFixed(0)} over budget',
        description: tips.join(' '),
        allocations: const {},
      );
    }
    await _saveAndEmit(next, suggestion: suggestion);
  }

  Future<void> updateExpenses(List<PlanExpense> expenses) async {
    final current = _currentPlan;
    if (current == null) return;
    await _saveAndEmit(current.copyWith(expenses: expenses));
  }

  Future<void> updateInvestments(List<PlanInvestment> investments) async {
    final current = _currentPlan;
    if (current == null) return;
    await _saveAndEmit(current.copyWith(investments: investments));
  }

  Future<void> updateEmergency(PlanEmergencyFund fund) async {
    final current = _currentPlan;
    if (current == null) return;
    await _saveAndEmit(current.copyWith(emergencyFund: fund));
  }

  Future<void> updatePersonalSpending(double amount) async {
    final current = _currentPlan;
    if (current == null) return;
    await _saveAndEmit(current.copyWith(personalSpending: amount));
  }

  Future<void> addOrUpdateGoal(PlanGoal goal) async {
    final current = _currentPlan;
    if (current == null) return;
    final exists = current.goals.any((g) => g.id == goal.id);
    final goals = exists
        ? current.goals.map((g) => g.id == goal.id ? goal : g).toList()
        : [...current.goals, goal];
    final next = current.copyWith(goals: goals);
    final conflict = _engine.checkAffordability(next);
    await _saveAndEmit(
      next,
      suggestion: conflict != null && conflict.hasConflict
          ? ReallocationSuggestion(
              title: 'Your goals exceed your available monthly budget',
              description:
                  'You need ₹${conflict.shortfall.toStringAsFixed(0)} more per month. Affected: ${conflict.affectedItems.join(', ')}. ${conflict.suggestions.take(3).join(' · ')}',
              allocations: const {},
            )
          : null,
    );
  }

  Future<void> deleteGoal(String goalId) async {
    final current = _currentPlan;
    if (current == null) return;
    final removed = current.goals.firstWhere(
      (g) => g.id == goalId,
      orElse: () => PlanGoal(id: goalId, name: '', targetAmount: 0),
    );
    final goals = current.goals.where((g) => g.id != goalId).toList();
    final next = current.copyWith(goals: goals);
    final freed = removed.monthlyContribution;
    await _saveAndEmit(
      next,
      suggestion: freed > 0
          ? _engine.suggestReallocation(available: freed, plan: next)
          : null,
    );
  }

  Future<void> addOrUpdateDebt(PlanDebt debt) async {
    final current = _currentPlan;
    if (current == null) return;
    final exists = current.debts.any((d) => d.id == debt.id);
    final debts = exists
        ? current.debts.map((d) => d.id == debt.id ? debt : d).toList()
        : [...current.debts, debt];
    await _saveAndEmit(current.copyWith(debts: debts));
  }

  Future<void> deleteDebt(String debtId) async {
    final current = _currentPlan;
    if (current == null) return;
    final removed = current.debts.firstWhere(
      (d) => d.id == debtId,
      orElse: () => PlanDebt(id: debtId, name: '', emi: 0),
    );
    final debts = current.debts.where((d) => d.id != debtId).toList();
    final next = current.copyWith(debts: debts);
    await _saveAndEmit(
      next,
      suggestion: removed.emi > 0
          ? _engine.suggestReallocation(available: removed.emi, plan: next)
          : null,
    );
  }

  Future<void> updateRules(List<PlanRule> rules) async {
    final current = _currentPlan;
    if (current == null) return;
    await _saveAndEmit(current.copyWith(rules: rules));
  }

  void clearSuggestion() {
    final state = this.state;
    if (state is MoneyPlanLoaded) {
      emit(state.copyWith(clearSuggestion: true));
    }
  }

  Future<void> applySuggestion(Map<String, double> allocations) async {
    final current = _currentPlan;
    if (current == null) return;

    var investments = [...current.investments];
    var goals = [...current.goals];
    var emergency = current.emergencyFund;
    var personal = current.personalSpending;

    allocations.forEach((key, amount) {
      switch (key) {
        case 'investment':
          if (investments.isEmpty) {
            investments = [
              PlanInvestment(
                id: 'sip_main',
                name: 'SIP',
                monthlyAmount: amount,
                minimumAmount: amount,
              ),
            ];
          } else {
            final first = investments.first;
            investments[0] = first.copyWith(
              monthlyAmount: first.monthlyAmount + amount,
            );
          }
          break;
        case 'goals':
          final flexible = goals.where((g) => !g.isPaused && !g.isCompleted);
          if (flexible.isNotEmpty) {
            final g = flexible.first;
            goals = goals
                .map((x) => x.id == g.id
                    ? x.copyWith(
                        monthlyContribution: x.monthlyContribution + amount,
                      )
                    : x)
                .toList();
          }
          break;
        case 'emergency':
          emergency = emergency.copyWith(
            monthlyContribution: emergency.monthlyContribution + amount,
          );
          break;
        case 'personal':
          personal += amount;
          break;
      }
    });

    await _saveAndEmit(
      current.copyWith(
        investments: investments,
        goals: goals,
        emergencyFund: emergency,
        personalSpending: personal,
      ),
      clearSuggestion: true,
    );
  }

  MoneyPlanModel? get _currentPlan {
    if (state is MoneyPlanLoaded) return (state as MoneyPlanLoaded).plan;
    return _lastPlan;
  }

  Future<void> _saveAndEmit(
    MoneyPlanModel plan, {
    ReallocationSuggestion? suggestion,
    bool clearSuggestion = false,
  }) async {
    final refreshed = _engine.refreshDynamicTargets(plan);
    _lastPlan = refreshed;
    final snapshot = _engine.analyze(refreshed);
    emit(MoneyPlanLoaded(
      plan: refreshed,
      snapshot: snapshot,
      pendingSuggestion: clearSuggestion ? null : suggestion,
    ));
    await _repository.saveMoneyPlan(refreshed);
  }

  void _reloadAfterError() {
    Future.delayed(const Duration(seconds: 2), () {
      if (state is MoneyPlanError) loadPlan();
    });
  }

  void reset() {
    _subscription?.cancel();
    _subscription = null;
    _lastPlan = null;
    emit(MoneyPlanInitial());
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
