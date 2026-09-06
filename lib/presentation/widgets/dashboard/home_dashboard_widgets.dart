import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/budget_cycle.dart';
import '../../../core/utils/budget_month_day_editor.dart';
import '../../../core/utils/planner_navigation.dart';
import '../../../data/models/transaction_model_new.dart';
import '../../../logic/cubits/money_plan_cubit.dart';
import '../../../data/services/money_plan_engine.dart';
import '../../../data/services/monthly_tracker_engine.dart';
import '../../theme/brand_colors.dart';
import '../money_planner/money_plan_widgets.dart';
import '../transaction_list_item.dart';

class MonthCashFlow {
  final double income;
  final double expense;
  final int txnCount;

  const MonthCashFlow({
    required this.income,
    required this.expense,
    required this.txnCount,
  });

  double get net => income - expense;

  static MonthCashFlow fromTransactions(List<TransactionModelNew> txns) {
    var income = 0.0;
    var expense = 0.0;
    for (final t in txns) {
      if (t.type == TransactionType.credit) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return MonthCashFlow(
      income: income,
      expense: expense,
      txnCount: txns.length,
    );
  }
}

List<TransactionModelNew> transactionsForMonth(
  List<TransactionModelNew> all,
  DateTime month, {
  int cycleStartDay = 1,
}) {
  final cycle = BudgetCycle.fromStart(month, cycleStartDay);
  return all.where((t) => cycle.contains(t.date)).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
}

class DashboardMonthPicker extends StatelessWidget {
  final DateTime selectedMonth;
  final List<DateTime> months;
  final ValueChanged<DateTime> onChanged;
  final int cycleStartDay;
  final bool showEditDay;

  const DashboardMonthPicker({
    super.key,
    required this.selectedMonth,
    required this.months,
    required this.onChanged,
    this.cycleStartDay = 1,
    this.showEditDay = true,
  });

  bool _sameStart(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _editMonthDay(BuildContext context, int day) async {
    final next = await showBudgetMonthDayEditor(
      context,
      currentDay: day,
    );
    if (next == null || !context.mounted) return;
    await context.read<MoneyPlanCubit>().updateCycleStartDay(next);
    if (!context.mounted) return;
    onChanged(BudgetCycle.containing(DateTime.now(), next).start);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          next == 1
              ? 'Budget month uses the calendar month'
              : 'Budget month now starts on day $next',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = BudgetCycle.normalizeDay(cycleStartDay);
    final selectedCycle = BudgetCycle.fromStart(selectedMonth, day);
    final currentCycle = BudgetCycle.containing(DateTime.now(), day);
    final canGoNext = selectedCycle.start.isBefore(currentCycle.start);

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous period',
                onPressed: () {
                  onChanged(selectedCycle.previous(day).start);
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<DateTime>(
                    isExpanded: true,
                    value: months.firstWhere(
                      (m) => _sameStart(m, selectedMonth),
                      orElse: () => selectedMonth,
                    ),
                    items: [
                      for (final m in months)
                        DropdownMenuItem(
                          value: m,
                          child: Text(
                            BudgetCycle.fromStart(m, day).labelForDay(day),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (m) {
                      if (m != null) {
                        onChanged(BudgetCycle.fromStart(m, day).start);
                      }
                    },
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next period',
                onPressed: canGoNext
                    ? () => onChanged(selectedCycle.next(day).start)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          if (showEditDay) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_outlined,
                    size: 16,
                    color: BrandColors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      day == 1
                          ? 'Month starts on the 1st (calendar)'
                          : 'Month starts on day $day',
                      style: const TextStyle(
                        fontSize: 12,
                        color: BrandColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _editMonthDay(context, day),
                    icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                    label: const Text('Edit date'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: BrandColors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DashboardBalanceHero extends StatelessWidget {
  final double totalBalance;
  final MonthCashFlow cashFlow;
  final DateTime month;
  final int cycleStartDay;

  const DashboardBalanceHero({
    super.key,
    required this.totalBalance,
    required this.cashFlow,
    required this.month,
    this.cycleStartDay = 1,
  });

  @override
  Widget build(BuildContext context) {
    final day = BudgetCycle.normalizeDay(cycleStartDay);
    final monthLabel = BudgetCycle.fromStart(month, day).labelForDay(day);
    final netPositive = cashFlow.net >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: BrandColors.logoGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: BrandColors.blue.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total balance',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            moneyInr.format(totalBalance),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$monthLabel activity',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  'Income',
                  moneyInr.format(cashFlow.income),
                  Icons.arrow_downward_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniStat(
                  'Spent',
                  moneyInr.format(cashFlow.expense),
                  Icons.arrow_upward_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniStat(
                  'Net',
                  moneyInr.format(cashFlow.net),
                  netPositive
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 10,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardBudgetProgressCard extends StatelessWidget {
  final MonthlyTrackerSnapshot tracker;
  final VoidCallback? onViewDetails;

  const DashboardBudgetProgressCard({
    super.key,
    required this.tracker,
    this.onViewDetails,
  });

  String get _statusLabel {
    if (tracker.totalPlanned <= 0) return 'Budget not configured';
    if (tracker.over > 0) return 'Over plan in ${tracker.over} categories';
    if (tracker.missed > 0) return '${tracker.missed} categories behind';
    if (tracker.remaining > 0) return 'On track — ${tracker.remaining} left';
    return 'All categories on plan';
  }

  @override
  Widget build(BuildContext context) {
    final progress = tracker.overallProgress.clamp(0.0, 1.0);
    final monthLabel = tracker.cycle.label;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BrandColors.cyan.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BrandColors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: BrandColors.blue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Where money goes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      _statusLabel,
                      style: TextStyle(color: BrandColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (onViewDetails != null)
                TextButton(
                  onPressed: onViewDetails,
                  child: const Text('Details'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$monthLabel — planned vs spent',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            '${moneyInr.format(tracker.totalActual)} / ${moneyInr.format(tracker.totalPlanned)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: BrandColors.blue.withOpacity(0.12),
              valueColor: const AlwaysStoppedAnimation(BrandColors.green),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip('Done', tracker.fulfilled, const Color(0xFF86EFAC)),
              _statusChip('Left', tracker.remaining, const Color(0xFFFDE68A)),
              _statusChip('Missed', tracker.missed, const Color(0xFFFCA5A5)),
              _statusChip('Over', tracker.over, const Color(0xFFC4B5FD)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, int count, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label $count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }
}

class DashboardSectionProgressList extends StatelessWidget {
  final MonthlyTrackerSnapshot tracker;

  const DashboardSectionProgressList({super.key, required this.tracker});

  @override
  Widget build(BuildContext context) {
    final sections = tracker.sections
        .where((s) =>
            s.section != PlannerSections.income &&
            (s.planned > 0 || s.actual > 0))
        .toList();

    if (sections.isEmpty) {
      return _emptyHint(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'By category',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Planned monthly amounts vs what you spent this month.',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 12),
        for (final section in sections)
          _SectionRow(section: section, month: tracker.month),
      ],
    );
  }

  Widget _emptyHint(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        'Tag transactions with planner categories to see where money goes vs your monthly plan.',
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  final TrackerSectionSummary section;
  final DateTime month;

  const _SectionRow({required this.section, required this.month});

  @override
  Widget build(BuildContext context) {
    final color = PlannerSections.colorFor(section.section);
    final progress = section.planned <= 0
        ? (section.actual > 0 ? 1.0 : 0.0)
        : (section.actual / section.planned).clamp(0.0, 1.0);
    final over = section.planned > 0 && section.actual > section.planned;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => openPlannerSection(context, section: section.section),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        PlannerSections.iconFor(section.section),
                        color: color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.section,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${moneyInr.format(section.actual)} of ${moneyInr.format(section.planned)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (over)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Over',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: color.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation(
                      over ? Colors.red.shade400 : color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardPlanAllocationCard extends StatelessWidget {
  final MoneyPlanSnapshot snapshot;
  final bool planConfigured;

  const DashboardPlanAllocationCard({
    super.key,
    required this.snapshot,
    required this.planConfigured,
  });

  @override
  Widget build(BuildContext context) {
    if (!planConfigured || snapshot.plannedTotal <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly allocation',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'How your income is split across essentials, savings, and goals.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AllocationDonut(slices: snapshot.slices, size: 140),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < snapshot.slices.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AllocationDonut.colorFor(i),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                snapshot.slices[i].label,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              moneyInr.format(snapshot.slices[i].amount),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (snapshot.remaining != 0) ...[
            const SizedBox(height: 10),
            Text(
              snapshot.remaining > 0
                  ? '${moneyInr.format(snapshot.remaining)} unallocated this month'
                  : '${moneyInr.format(snapshot.remaining.abs())} over-allocated',
              style: TextStyle(
                color: snapshot.remaining > 0
                    ? BrandColors.muted
                    : Colors.red.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DashboardMonthTransactions extends StatelessWidget {
  final List<TransactionModelNew> transactions;
  final VoidCallback? onViewAll;

  const DashboardMonthTransactions({
    super.key,
    required this.transactions,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Transactions this month',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            if (onViewAll != null)
              TextButton(onPressed: onViewAll, child: const Text('View all')),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${transactions.length} recorded',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (transactions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 36, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No transactions this month yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          )
        else
          for (var i = 0; i < transactions.length && i < 6; i++)
            TransactionListItem(
              transaction: transactions[i],
              index: i,
            ),
      ],
    );
  }
}

class DashboardBudgetNotConfiguredCard extends StatelessWidget {
  final VoidCallback onOpenPlanner;

  const DashboardBudgetNotConfiguredCard({
    super.key,
    required this.onOpenPlanner,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BrandColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BrandColors.cyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_month_outlined, color: BrandColors.blue),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Monthly budget not set yet',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Set your monthly income split in the Planner tab to compare planned vs actual spending here.',
            style: TextStyle(color: BrandColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onOpenPlanner,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Open monthly budget'),
          ),
        ],
      ),
    );
  }
}
