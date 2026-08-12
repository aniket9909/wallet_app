import '../models/money_plan_model.dart';

class AllocationSlice {
  final String key;
  final String label;
  final double amount;
  final double percentage;

  const AllocationSlice({
    required this.key,
    required this.label,
    required this.amount,
    required this.percentage,
  });
}

class BudgetConflict {
  final double required;
  final double available;
  final double shortfall;
  final List<String> affectedItems;
  final List<String> suggestions;

  const BudgetConflict({
    required this.required,
    required this.available,
    required this.shortfall,
    required this.affectedItems,
    required this.suggestions,
  });

  bool get hasConflict => shortfall > 1;
}

class HealthBreakdown {
  final String label;
  final String status; // Strong | Building | Moderate | Weak | On track
  final int scoreContribution;

  const HealthBreakdown({
    required this.label,
    required this.status,
    required this.scoreContribution,
  });
}

class FinancialHealth {
  final int score;
  final List<HealthBreakdown> breakdown;

  const FinancialHealth({
    required this.score,
    required this.breakdown,
  });
}

class ForecastSummary {
  final double income;
  final double investments;
  final double goals;
  final double emergency;
  final double debtPayments;
  final double essentials;
  final double personal;

  const ForecastSummary({
    required this.income,
    required this.investments,
    required this.goals,
    required this.emergency,
    required this.debtPayments,
    required this.essentials,
    required this.personal,
  });
}

class ReallocationSuggestion {
  final String title;
  final String description;
  final Map<String, double> allocations;

  const ReallocationSuggestion({
    required this.title,
    required this.description,
    required this.allocations,
  });
}

class MoneyPlanSnapshot {
  final MoneyPlanModel plan;
  final double totalIncome;
  final double essentialsTotal;
  final double investmentsTotal;
  final double protectedInvestments;
  final double goalsTotal;
  final double goalsRequiredTotal;
  final double emergencyMonthly;
  final double debtTotal;
  final double personal;
  final double plannedTotal;
  final double remaining;
  final double flexibleMoney;
  final List<AllocationSlice> slices;
  final BudgetConflict? conflict;
  final FinancialHealth health;
  final ForecastSummary forecast12;

  const MoneyPlanSnapshot({
    required this.plan,
    required this.totalIncome,
    required this.essentialsTotal,
    required this.investmentsTotal,
    required this.protectedInvestments,
    required this.goalsTotal,
    required this.goalsRequiredTotal,
    required this.emergencyMonthly,
    required this.debtTotal,
    required this.personal,
    required this.plannedTotal,
    required this.remaining,
    required this.flexibleMoney,
    required this.slices,
    required this.conflict,
    required this.health,
    required this.forecast12,
  });
}

/// Central engine: Income → protected → required → dynamic goals → flexible.
class MoneyPlanEngine {
  const MoneyPlanEngine();

  MoneyPlanSnapshot analyze(MoneyPlanModel plan) {
    final income = plan.income.availableMonthlyIncome;
    final essentials = plan.expenses.fold<double>(
      0,
      (s, e) => s + e.monthlyAmount,
    );
    final investments = plan.investments.fold<double>(
      0,
      (s, i) => s + i.monthlyAmount,
    );
    final protectedInvestments = plan.investments
        .where((i) => i.isProtected)
        .fold<double>(0, (s, i) => s + i.minimumAmount);

    final activeGoals = plan.goals.where((g) => !g.isPaused && !g.isCompleted);
    final goalsAssigned = activeGoals.fold<double>(
      0,
      (s, g) => s + g.monthlyContribution,
    );
    final goalsRequired = activeGoals.fold<double>(
      0,
      (s, g) => s + g.requiredMonthlyContribution,
    );

    final emergency = plan.emergencyFund.isComplete
        ? 0.0
        : (plan.emergencyFund.monthlyContribution > 0
            ? plan.emergencyFund.monthlyContribution
            : plan.emergencyFund.requiredMonthlyContribution);

    final debt = plan.debts
        .where((d) => d.isActive)
        .fold<double>(0, (s, d) => s + d.emi);

    final personal = plan.personalBudget;

    final planned = essentials +
        investments +
        goalsAssigned +
        emergency +
        debt +
        personal;

    final remaining = income - planned;
    final protectedEssentials = plan.expenses
        .where((e) => e.isProtected || e.kind == ExpenseKind.staticExpense)
        .fold<double>(0, (s, e) => s + e.monthlyAmount);

    final flexibleMoney = income -
        protectedEssentials -
        protectedInvestments -
        debt -
        goalsRequired -
        (plan.emergencyFund.isProtected && !plan.emergencyFund.isComplete
            ? emergency
            : 0);

    final conflict = _detectConflict(
      income: income,
      protectedEssentials: protectedEssentials,
      protectedInvestments: protectedInvestments,
      debt: debt,
      goalsRequired: goalsRequired,
      emergency: emergency,
      emergencyProtected: plan.emergencyFund.isProtected,
      goals: activeGoals.toList(),
    );

    final slices = _buildSlices(
      income: income,
      essentials: essentials,
      investments: investments,
      goals: goalsAssigned,
      emergency: emergency,
      personal: personal,
      debt: debt,
    );

    final health = _computeHealth(
      income: income,
      investments: investments,
      essentials: essentials,
      emergency: plan.emergencyFund,
      debt: debt,
      goals: plan.goals,
      remaining: remaining,
    );

    final forecast = ForecastSummary(
      income: income * 12,
      investments: investments * 12,
      goals: goalsAssigned * 12,
      emergency: emergency * 12,
      debtPayments: debt * 12,
      essentials: essentials * 12,
      personal: personal * 12,
    );

    return MoneyPlanSnapshot(
      plan: plan,
      totalIncome: income,
      essentialsTotal: essentials,
      investmentsTotal: investments,
      protectedInvestments: protectedInvestments,
      goalsTotal: goalsAssigned,
      goalsRequiredTotal: goalsRequired,
      emergencyMonthly: emergency,
      debtTotal: debt,
      personal: personal,
      plannedTotal: planned,
      remaining: remaining,
      flexibleMoney: flexibleMoney,
      slices: slices,
      conflict: conflict,
      health: health,
      forecast12: forecast,
    );
  }

  /// Sync gold target amounts and emergency essentials from expenses.
  MoneyPlanModel refreshDynamicTargets(MoneyPlanModel plan) {
    final essentials = plan.expenses.fold<double>(
      0,
      (s, e) => s + e.monthlyAmount,
    );

    final updatedGoals = plan.goals.map((g) {
      if (g.goalType == GoalType.gold && g.goldDetails != null) {
        final target = g.goldDetails!.estimatedCost;
        final refreshed = g.copyWith(targetAmount: target);
        return refreshed.copyWith(
          monthlyContribution: refreshed.isPaused || refreshed.isCompleted
              ? g.monthlyContribution
              : refreshed.requiredMonthlyContribution,
        );
      }
      if (!g.isPaused && !g.isCompleted && g.monthlyContribution <= 0) {
        return g.copyWith(
          monthlyContribution: g.requiredMonthlyContribution,
        );
      }
      return g;
    }).toList();

    var emergency = plan.emergencyFund.copyWith(
      monthlyEssentialExpenses: essentials > 0
          ? essentials
          : plan.emergencyFund.monthlyEssentialExpenses,
    );
    if (emergency.monthlyContribution <= 0 && !emergency.isComplete) {
      emergency = emergency.copyWith(
        monthlyContribution: emergency.requiredMonthlyContribution,
      );
    }

    return plan.copyWith(
      goals: updatedGoals,
      emergencyFund: emergency,
      updatedAt: DateTime.now(),
    );
  }

  BudgetConflict? checkAffordability(
    MoneyPlanModel plan, {
    PlanGoal? additionalGoal,
  }) {
    final withGoal = additionalGoal == null
        ? plan
        : plan.copyWith(goals: [...plan.goals, additionalGoal]);
    return analyze(withGoal).conflict;
  }

  ReallocationSuggestion suggestReallocation({
    required double available,
    required MoneyPlanModel plan,
  }) {
    // Default priority: 50% investment, 30% goals, 20% emergency (or personal if EF done).
    final investmentsShare = available * 0.5;
    final goalsShare = available * 0.3;
    final rest = available * 0.2;

    final map = <String, double>{
      'investment': investmentsShare,
      'goals': goalsShare,
    };
    if (plan.emergencyFund.isComplete) {
      map['personal'] = rest;
    } else {
      map['emergency'] = rest;
    }

    return ReallocationSuggestion(
      title: 'Recommended adjustment',
      description:
          'You have ₹${available.toStringAsFixed(0)} available. Suggested split based on your priorities.',
      allocations: map,
    );
  }

  ReallocationSuggestion suggestIncomeIncrease({
    required double extra,
    required MoneyPlanModel plan,
  }) {
    return ReallocationSuggestion(
      title: 'You have ₹${extra.toStringAsFixed(0)} additional monthly capacity',
      description:
          'Avoid lifestyle inflation — improve security first, then goals and personal.',
      allocations: {
        'investment': extra * 0.4,
        'emergency': plan.emergencyFund.isComplete ? 0 : extra * 0.25,
        'goals': extra * 0.25,
        'personal': plan.emergencyFund.isComplete ? extra * 0.35 : extra * 0.1,
      },
    );
  }

  List<String> suggestIncomeReduction({
    required double shortfall,
    required MoneyPlanModel plan,
  }) {
    return [
      'Reduce personal spending first (₹${plan.personalBudget.toStringAsFixed(0)} available).',
      'Pause or extend lower-priority optional goals.',
      'Trim variable expenses (food, transport, shopping).',
      'Do not automatically reduce protected SIP (₹${plan.investments.where((i) => i.isProtected).fold<double>(0, (s, i) => s + i.minimumAmount).toStringAsFixed(0)}).',
      'Shortfall to cover: ₹${shortfall.toStringAsFixed(0)}/month.',
    ];
  }

  BudgetConflict? _detectConflict({
    required double income,
    required double protectedEssentials,
    required double protectedInvestments,
    required double debt,
    required double goalsRequired,
    required double emergency,
    required bool emergencyProtected,
    required List<PlanGoal> goals,
  }) {
    final required = protectedEssentials +
        protectedInvestments +
        debt +
        goalsRequired +
        (emergencyProtected ? emergency : 0);
    final shortfall = required - income;
    if (shortfall <= 1) return null;

    final affected = goals
        .where((g) => g.priority.rank >= PlanPriority.medium.rank)
        .map((g) => g.name)
        .toList();

    return BudgetConflict(
      required: required,
      available: income,
      shortfall: shortfall,
      affectedItems: affected.isEmpty
          ? goals.map((g) => g.name).toList()
          : affected,
      suggestions: const [
        'Extend a goal deadline',
        'Reduce a lower-priority goal',
        'Increase income',
        'Reduce flexible spending',
        'Reduce a goal amount',
        'Temporarily pause a lower-priority goal',
      ],
    );
  }

  List<AllocationSlice> _buildSlices({
    required double income,
    required double essentials,
    required double investments,
    required double goals,
    required double emergency,
    required double personal,
    required double debt,
  }) {
    double pct(double amount) =>
        income <= 0 ? 0 : (amount / income * 100);

    final items = <AllocationSlice>[
      AllocationSlice(
        key: 'needs',
        label: 'Needs',
        amount: essentials + debt,
        percentage: pct(essentials + debt),
      ),
      AllocationSlice(
        key: 'investments',
        label: 'Investments',
        amount: investments,
        percentage: pct(investments),
      ),
      AllocationSlice(
        key: 'goals',
        label: 'Goals',
        amount: goals,
        percentage: pct(goals),
      ),
      AllocationSlice(
        key: 'emergency',
        label: 'Emergency',
        amount: emergency,
        percentage: pct(emergency),
      ),
      AllocationSlice(
        key: 'personal',
        label: 'Personal',
        amount: personal,
        percentage: pct(personal),
      ),
    ];
    return items.where((s) => s.amount > 0 || income <= 0).toList();
  }

  FinancialHealth _computeHealth({
    required double income,
    required double investments,
    required double essentials,
    required PlanEmergencyFund emergency,
    required double debt,
    required List<PlanGoal> goals,
    required double remaining,
  }) {
    final breakdown = <HealthBreakdown>[];
    var score = 0;

    // Investment rate (target ~15–20%)
    final invRate = income > 0 ? investments / income : 0.0;
    if (invRate >= 0.18) {
      score += 25;
      breakdown.add(const HealthBreakdown(
        label: 'Investment',
        status: 'Strong',
        scoreContribution: 25,
      ));
    } else if (invRate >= 0.10) {
      score += 18;
      breakdown.add(const HealthBreakdown(
        label: 'Investment',
        status: 'Building',
        scoreContribution: 18,
      ));
    } else {
      score += 8;
      breakdown.add(const HealthBreakdown(
        label: 'Investment',
        status: 'Weak',
        scoreContribution: 8,
      ));
    }

    // Emergency progress
    final efProgress = emergency.progressPercentage;
    if (efProgress >= 100) {
      score += 20;
      breakdown.add(const HealthBreakdown(
        label: 'Emergency fund',
        status: 'Strong',
        scoreContribution: 20,
      ));
    } else if (efProgress >= 40) {
      score += 14;
      breakdown.add(const HealthBreakdown(
        label: 'Emergency fund',
        status: 'Building',
        scoreContribution: 14,
      ));
    } else {
      score += 6;
      breakdown.add(const HealthBreakdown(
        label: 'Emergency fund',
        status: 'Weak',
        scoreContribution: 6,
      ));
    }

    // Debt burden
    final debtRatio = income > 0 ? debt / income : 0.0;
    if (debtRatio <= 0.1) {
      score += 15;
      breakdown.add(const HealthBreakdown(
        label: 'Debt',
        status: 'Strong',
        scoreContribution: 15,
      ));
    } else if (debtRatio <= 0.3) {
      score += 10;
      breakdown.add(const HealthBreakdown(
        label: 'Debt',
        status: 'Moderate',
        scoreContribution: 10,
      ));
    } else {
      score += 4;
      breakdown.add(const HealthBreakdown(
        label: 'Debt',
        status: 'High',
        scoreContribution: 4,
      ));
    }

    // Essential expense ratio (healthy under ~50%)
    final essRatio = income > 0 ? essentials / income : 0.0;
    if (essRatio <= 0.5) {
      score += 15;
      breakdown.add(const HealthBreakdown(
        label: 'Essentials',
        status: 'Strong',
        scoreContribution: 15,
      ));
    } else if (essRatio <= 0.7) {
      score += 10;
      breakdown.add(const HealthBreakdown(
        label: 'Essentials',
        status: 'Moderate',
        scoreContribution: 10,
      ));
    } else {
      score += 4;
      breakdown.add(const HealthBreakdown(
        label: 'Essentials',
        status: 'High',
        scoreContribution: 4,
      ));
    }

    // Goals on track
    final active = goals.where((g) => !g.isPaused && !g.isCompleted).toList();
    if (active.isEmpty) {
      score += 15;
      breakdown.add(const HealthBreakdown(
        label: 'Goals',
        status: 'On track',
        scoreContribution: 15,
      ));
    } else {
      final onTrack =
          active.where((g) => g.computedStatus == GoalStatus.onTrack).length;
      final ratio = onTrack / active.length;
      if (ratio >= 0.8) {
        score += 15;
        breakdown.add(const HealthBreakdown(
          label: 'Goals',
          status: 'On track',
          scoreContribution: 15,
        ));
      } else if (ratio >= 0.5) {
        score += 10;
        breakdown.add(const HealthBreakdown(
          label: 'Goals',
          status: 'At risk',
          scoreContribution: 10,
        ));
      } else {
        score += 5;
        breakdown.add(const HealthBreakdown(
          label: 'Goals',
          status: 'Off track',
          scoreContribution: 5,
        ));
      }
    }

    // Surplus / savings rate
    if (remaining >= 0) {
      score += 10;
      breakdown.add(const HealthBreakdown(
        label: 'Monthly surplus',
        status: 'Balanced',
        scoreContribution: 10,
      ));
    } else {
      score += 2;
      breakdown.add(const HealthBreakdown(
        label: 'Monthly surplus',
        status: 'Over budget',
        scoreContribution: 2,
      ));
    }

    return FinancialHealth(
      score: score.clamp(0, 100),
      breakdown: breakdown,
    );
  }
}
