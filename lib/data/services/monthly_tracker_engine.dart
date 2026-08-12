import '../models/money_plan_model.dart';
import '../models/transaction_model_new.dart';
import '../../core/utils/planner_navigation.dart';

enum TrackerItemStatus {
  /// Planned amount set and actual >= planned.
  fulfilled,

  /// Still in the selected month and under plan.
  remaining,

  /// Past month and under plan.
  missed,

  /// Actual above planned.
  over,

  /// Category exists but planned amount is 0 / not configured.
  notSetup,
}

class TrackerLineItem {
  final String section;
  final String name;
  final String id;
  final double planned;
  final double actual;
  final int txnCount;
  final bool isIncome;

  const TrackerLineItem({
    required this.section,
    required this.name,
    required this.id,
    required this.planned,
    required this.actual,
    required this.txnCount,
    this.isIncome = false,
  });

  double get remaining =>
      planned <= 0 ? 0 : (planned - actual).clamp(0, double.infinity);

  double get overAmount =>
      planned <= 0 ? 0 : (actual - planned).clamp(0, double.infinity);

  double get progress {
    if (planned <= 0) return actual > 0 ? 1 : 0;
    return (actual / planned).clamp(0.0, 1.5);
  }

  TrackerItemStatus statusFor(DateTime month, {DateTime? now}) {
    final today = now ?? DateTime.now();
    if (planned <= 0) return TrackerItemStatus.notSetup;
    if (actual > planned) return TrackerItemStatus.over;
    if (actual >= planned) return TrackerItemStatus.fulfilled;

    final isPastMonth = month.year < today.year ||
        (month.year == today.year && month.month < today.month);
    if (isPastMonth) return TrackerItemStatus.missed;
    return TrackerItemStatus.remaining;
  }
}

class TrackerSectionSummary {
  final String section;
  final List<TrackerLineItem> items;

  const TrackerSectionSummary({
    required this.section,
    required this.items,
  });

  double get planned => items.fold(0, (s, e) => s + e.planned);
  double get actual => items.fold(0, (s, e) => s + e.actual);

  int countStatus(TrackerItemStatus status, DateTime month) =>
      items.where((i) => i.statusFor(month) == status).length;
}

class MonthlyTrackerSnapshot {
  final DateTime month;
  final List<TrackerSectionSummary> sections;
  final int fulfilled;
  final int remaining;
  final int missed;
  final int over;
  final int notSetup;
  final double totalPlanned;
  final double totalActual;

  const MonthlyTrackerSnapshot({
    required this.month,
    required this.sections,
    required this.fulfilled,
    required this.remaining,
    required this.missed,
    required this.over,
    required this.notSetup,
    required this.totalPlanned,
    required this.totalActual,
  });

  double get overallProgress {
    if (totalPlanned <= 0) return 0;
    return (totalActual / totalPlanned).clamp(0.0, 1.5);
  }
}

/// Compares Money Planner planned monthly amounts vs tagged transactions
/// for a selected calendar month.
class MonthlyTrackerEngine {
  static MonthlyTrackerSnapshot build({
    required MoneyPlanModel plan,
    required List<TransactionModelNew> transactions,
    required DateTime month,
    DateTime? now,
  }) {
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1);
    final monthTxns = transactions
        .where((t) =>
            !t.date.isBefore(monthStart) && t.date.isBefore(monthEnd))
        .toList();

    final sections = <TrackerSectionSummary>[
      _income(plan, monthTxns),
      _essentials(plan, monthTxns),
      _investments(plan, monthTxns),
      _emergency(plan, monthTxns),
      _goals(plan, monthTxns),
      _debts(plan, monthTxns),
      _personal(plan, monthTxns),
    ];

    var fulfilled = 0;
    var remaining = 0;
    var missed = 0;
    var over = 0;
    var notSetup = 0;
    var totalPlanned = 0.0;
    var totalActual = 0.0;

    for (final section in sections) {
      for (final item in section.items) {
        // Income is tracked separately in UI; exclude from spend totals.
        if (!item.isIncome) {
          totalPlanned += item.planned;
          totalActual += item.actual;
        }
        switch (item.statusFor(monthStart, now: now)) {
          case TrackerItemStatus.fulfilled:
            fulfilled++;
          case TrackerItemStatus.remaining:
            remaining++;
          case TrackerItemStatus.missed:
            missed++;
          case TrackerItemStatus.over:
            over++;
          case TrackerItemStatus.notSetup:
            notSetup++;
        }
      }
    }

    return MonthlyTrackerSnapshot(
      month: monthStart,
      sections: sections,
      fulfilled: fulfilled,
      remaining: remaining,
      missed: missed,
      over: over,
      notSetup: notSetup,
      totalPlanned: totalPlanned,
      totalActual: totalActual,
    );
  }

  /// Months the user can filter — current month + last 11 + any txn months.
  static List<DateTime> availableMonths(
    List<TransactionModelNew> transactions, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final set = <String, DateTime>{};

    for (var i = 0; i < 12; i++) {
      final m = DateTime(today.year, today.month - i);
      set[_key(m)] = DateTime(m.year, m.month);
    }
    for (final t in transactions) {
      final m = DateTime(t.date.year, t.date.month);
      set[_key(m)] = m;
    }

    final list = set.values.toList()
      ..sort((a, b) => b.compareTo(a));
    return list;
  }

  static String _key(DateTime m) => '${m.year}-${m.month}';

  static TrackerSectionSummary _income(
    MoneyPlanModel plan,
    List<TransactionModelNew> txns,
  ) {
    final planned = plan.income.availableMonthlyIncome;
    final matched = _matchTxns(
      txns,
      section: PlannerSections.income,
      name: 'Monthly income',
      preferCredit: true,
    );
    return TrackerSectionSummary(
      section: PlannerSections.income,
      items: [
        TrackerLineItem(
          section: PlannerSections.income,
          name: 'Monthly income',
          id: 'income',
          planned: planned,
          actual: matched.$1,
          txnCount: matched.$2,
          isIncome: true,
        ),
      ],
    );
  }

  static TrackerSectionSummary _essentials(
    MoneyPlanModel plan,
    List<TransactionModelNew> txns,
  ) {
    final items = plan.expenses.map((e) {
      final matched = _matchTxns(
        txns,
        section: PlannerSections.essentials,
        name: e.name,
      );
      return TrackerLineItem(
        section: PlannerSections.essentials,
        name: e.name,
        id: e.id,
        planned: e.monthlyAmount,
        actual: matched.$1,
        txnCount: matched.$2,
      );
    }).toList();
    return TrackerSectionSummary(
      section: PlannerSections.essentials,
      items: items,
    );
  }

  static TrackerSectionSummary _investments(
    MoneyPlanModel plan,
    List<TransactionModelNew> txns,
  ) {
    final items = plan.investments.map((e) {
      final matched = _matchTxns(
        txns,
        section: PlannerSections.investment,
        name: e.name,
      );
      return TrackerLineItem(
        section: PlannerSections.investment,
        name: e.name,
        id: e.id,
        planned: e.monthlyAmount,
        actual: matched.$1,
        txnCount: matched.$2,
      );
    }).toList();
    return TrackerSectionSummary(
      section: PlannerSections.investment,
      items: items,
    );
  }

  static TrackerSectionSummary _emergency(
    MoneyPlanModel plan,
    List<TransactionModelNew> txns,
  ) {
    final matched = _matchTxns(
      txns,
      section: PlannerSections.emergency,
      name: 'Monthly contribution',
      alsoAcceptAnySubtypeInSection: true,
    );
    return TrackerSectionSummary(
      section: PlannerSections.emergency,
      items: [
        TrackerLineItem(
          section: PlannerSections.emergency,
          name: 'Monthly contribution',
          id: 'emergency',
          planned: plan.emergencyFund.monthlyContribution,
          actual: matched.$1,
          txnCount: matched.$2,
        ),
      ],
    );
  }

  static TrackerSectionSummary _goals(
    MoneyPlanModel plan,
    List<TransactionModelNew> txns,
  ) {
    final items = plan.goals.map((g) {
      final matched = _matchTxns(
        txns,
        section: PlannerSections.goals,
        name: g.name,
      );
      return TrackerLineItem(
        section: PlannerSections.goals,
        name: g.name,
        id: g.id,
        planned: g.monthlyContribution,
        actual: matched.$1,
        txnCount: matched.$2,
      );
    }).toList();
    return TrackerSectionSummary(
      section: PlannerSections.goals,
      items: items,
    );
  }

  static TrackerSectionSummary _debts(
    MoneyPlanModel plan,
    List<TransactionModelNew> txns,
  ) {
    final items = plan.debts.where((d) => d.isActive).map((d) {
      final matched = _matchTxns(
        txns,
        section: PlannerSections.debt,
        name: d.name,
      );
      return TrackerLineItem(
        section: PlannerSections.debt,
        name: d.name,
        id: d.id,
        planned: d.emi,
        actual: matched.$1,
        txnCount: matched.$2,
      );
    }).toList();
    return TrackerSectionSummary(
      section: PlannerSections.debt,
      items: items,
    );
  }

  static TrackerSectionSummary _personal(
    MoneyPlanModel plan,
    List<TransactionModelNew> txns,
  ) {
    if (plan.personalCategories.isNotEmpty) {
      final items = plan.personalCategories.map((e) {
        final matched = _matchTxns(
          txns,
          section: PlannerSections.personal,
          name: e.name,
        );
        return TrackerLineItem(
          section: PlannerSections.personal,
          name: e.name,
          id: e.id,
          planned: e.monthlyAmount,
          actual: matched.$1,
          txnCount: matched.$2,
        );
      }).toList();
      return TrackerSectionSummary(
        section: PlannerSections.personal,
        items: items,
      );
    }

    final matched = _matchTxns(
      txns,
      section: PlannerSections.personal,
      name: 'Personal spending',
      alsoAcceptAnySubtypeInSection: true,
    );
    return TrackerSectionSummary(
      section: PlannerSections.personal,
      items: [
        TrackerLineItem(
          section: PlannerSections.personal,
          name: 'Personal spending',
          id: 'personal',
          planned: plan.personalBudget,
          actual: matched.$1,
          txnCount: matched.$2,
        ),
      ],
    );
  }

  /// Returns (amount, count) for matching txns.
  static (double, int) _matchTxns(
    List<TransactionModelNew> txns, {
    required String section,
    required String name,
    bool preferCredit = false,
    bool alsoAcceptAnySubtypeInSection = false,
  }) {
    final nameLower = name.trim().toLowerCase();
    var total = 0.0;
    var count = 0;

    for (final t in txns) {
      final info = parsePlannerNote(t.note);
      final txnSection = info.section != null
          ? PlannerSections.normalize(info.section)
          : null;
      final subtype = (info.subtype ?? t.category).trim();
      final subtypeLower = subtype.toLowerCase();

      bool sectionOk = txnSection == section;
      if (!sectionOk && txnSection == null) {
        // Fallback: category equals category name without planner note.
        sectionOk = subtypeLower == nameLower;
      }
      if (!sectionOk) continue;

      final nameOk = alsoAcceptAnySubtypeInSection ||
          subtypeLower == nameLower ||
          subtypeLower.contains(nameLower) ||
          nameLower.contains(subtypeLower);

      if (!nameOk) continue;

      final isCredit = t.type == TransactionType.credit;
      if (preferCredit) {
        if (!isCredit) continue;
      } else {
        // Contributions / spend / EMI are debits from the bank account.
        if (isCredit) continue;
      }

      total += t.amount;
      count++;
    }

    return (total, count);
  }
}
