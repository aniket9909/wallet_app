import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/budget_cycle.dart';
import '../../../core/utils/budget_month_day_editor.dart';
import '../../../core/utils/planner_navigation.dart';
import '../../../data/models/money_plan_model.dart';
import '../../../data/models/transaction_model_new.dart';
import '../../../data/services/monthly_tracker_engine.dart';
import '../../../logic/cubits/money_plan_cubit.dart';
import '../../../logic/cubits/transaction_cubit.dart';
import '../../widgets/money_planner/money_plan_widgets.dart';

/// Month-wise view of planner categories: planned vs actual fulfillment.
class MonthlyTrackerScreen extends StatefulWidget {
  const MonthlyTrackerScreen({super.key});

  @override
  State<MonthlyTrackerScreen> createState() => _MonthlyTrackerScreenState();
}

class _MonthlyTrackerScreenState extends State<MonthlyTrackerScreen> {
  late DateTime _selectedMonth;
  TrackerItemStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Tracker'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primary.withOpacity(0.05),
              Theme.of(context).colorScheme.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: BlocBuilder<MoneyPlanCubit, MoneyPlanState>(
          builder: (context, planState) {
            if (planState is MoneyPlanLoading ||
                planState is MoneyPlanInitial) {
              return const Center(child: CircularProgressIndicator());
            }
            if (planState is MoneyPlanError) {
              return Center(child: Text(planState.message));
            }
            final plan = planState is MoneyPlanLoaded
                ? planState.plan
                : const MoneyPlanModel();
            final cycleDay = plan.cycleStartDay;
            final currentCycle =
                BudgetCycle.containing(DateTime.now(), cycleDay);

            return BlocBuilder<TransactionCubit, TransactionState>(
              builder: (context, txnState) {
                final txns = txnState is TransactionLoaded
                    ? txnState.transactions
                    : <TransactionModelNew>[];
                final months = MonthlyTrackerEngine.availableMonths(
                  txns,
                  cycleStartDay: cycleDay,
                );
                final aligned =
                    BudgetCycle.fromStart(_selectedMonth, cycleDay).start;
                final selected = months.any((m) =>
                        m.year == aligned.year &&
                        m.month == aligned.month &&
                        m.day == aligned.day)
                    ? aligned
                    : currentCycle.start;
                if (!months.any((m) =>
                    m.year == selected.year &&
                    m.month == selected.month &&
                    m.day == selected.day)) {
                  months.insert(0, selected);
                }

                final snap = MonthlyTrackerEngine.build(
                  plan: plan,
                  transactions: txns,
                  month: selected,
                );

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _monthPicker(context, months, cycleDay, selected),
                    const SizedBox(height: 14),
                    _summaryHero(context, snap, cycleDay),
                    const SizedBox(height: 14),
                    _statusChips(context, snap),
                    const SizedBox(height: 18),
                    Text(
                      'Categories',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Planned vs tagged for ${snap.cycle.labelForDay(cycleDay)}.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    for (final section in snap.sections)
                      if (section.items.isNotEmpty)
                        _sectionCard(context, section, snap.cycle),
                  ],
                ).animate().fadeIn(duration: 350.ms);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _monthPicker(
    BuildContext context,
    List<DateTime> months,
    int cycleStartDay,
    DateTime selected,
  ) {
    final day = BudgetCycle.normalizeDay(cycleStartDay);
    final selectedCycle = BudgetCycle.fromStart(selected, day);
    final currentCycle = BudgetCycle.containing(DateTime.now(), day);
    final canGoNext = selectedCycle.start.isBefore(currentCycle.start);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous period',
            onPressed: () {
              setState(() {
                _selectedMonth = selectedCycle.previous(day).start;
              });
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DateTime>(
                isExpanded: true,
                value: months.firstWhere(
                  (m) =>
                      m.year == selected.year &&
                      m.month == selected.month &&
                      m.day == selected.day,
                  orElse: () => selected,
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
                  if (m == null) return;
                  setState(() {
                    _selectedMonth = BudgetCycle.fromStart(m, day).start;
                  });
                },
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next period',
            onPressed: canGoNext
                ? () {
                    setState(() {
                      _selectedMonth = selectedCycle.next(day).start;
                    });
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: 'Edit month start day',
            onPressed: () async {
              final ok = await editAndSaveBudgetMonthDay(
                context,
                currentDay: day,
              );
              if (ok && mounted) {
                final planState = context.read<MoneyPlanCubit>().state;
                final nextDay = planState is MoneyPlanLoaded
                    ? planState.plan.cycleStartDay
                    : day;
                setState(() {
                  _selectedMonth =
                      BudgetCycle.containing(DateTime.now(), nextDay).start;
                });
              }
            },
            icon: const Icon(Icons.edit_calendar_outlined),
          ),
        ],
      ),
    );
  }

  Widget _summaryHero(
    BuildContext context,
    MonthlyTrackerSnapshot snap,
    int cycleStartDay,
  ) {
    final progress = snap.overallProgress.clamp(0.0, 1.0);
    final monthLabel = snap.cycle.labelForDay(cycleStartDay);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$monthLabel progress',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${moneyInr.format(snap.totalActual)} / ${moneyInr.format(snap.totalPlanned)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statPill('Done', snap.fulfilled, const Color(0xFF86EFAC)),
              _statPill('Left', snap.remaining, const Color(0xFFFDE68A)),
              _statPill('Missed', snap.missed, const Color(0xFFFCA5A5)),
              _statPill('Over', snap.over, const Color(0xFFC4B5FD)),
              _statPill('No setup', snap.notSetup, const Color(0xFFE2E8F0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(String label, int count, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label $count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _statusChips(BuildContext context, MonthlyTrackerSnapshot snap) {
    final chips = <(String, TrackerItemStatus?)>[
      ('All', null),
      ('Fulfilled', TrackerItemStatus.fulfilled),
      ('Remaining', TrackerItemStatus.remaining),
      ('Missed', TrackerItemStatus.missed),
      ('Over', TrackerItemStatus.over),
      ('Not set up', TrackerItemStatus.notSetup),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final chip in chips)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(chip.$1),
                selected: _statusFilter == chip.$2,
                onSelected: (_) {
                  setState(() => _statusFilter = chip.$2);
                },
                selectedColor: Theme.of(context).colorScheme.primary,
                labelStyle: TextStyle(
                  color: _statusFilter == chip.$2
                      ? Colors.white
                      : Colors.black87,
                  fontWeight: _statusFilter == chip.$2
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 12,
                ),
                checkmarkColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context,
    TrackerSectionSummary section,
    BudgetCycle cycle,
  ) {
    final color = PlannerSections.colorFor(section.section);
    final items = section.items.where((item) {
      if (_statusFilter == null) return true;
      return item.statusFor(cycle) == _statusFilter;
    }).toList();

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => openPlannerSection(context, section: section.section),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        PlannerSections.iconFor(section.section),
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.section,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '${moneyInr.format(section.actual)} of ${moneyInr.format(section.planned)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
                const SizedBox(height: 10),
                for (final item in items) _itemRow(context, item, cycle, color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _itemRow(
    BuildContext context,
    TrackerLineItem item,
    BudgetCycle cycle,
    Color color,
  ) {
    final status = item.statusFor(cycle);
    final statusMeta = _statusMeta(status);
    final barValue = item.planned <= 0
        ? (item.actual > 0 ? 1.0 : 0.0)
        : (item.actual / item.planned).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openPlannerSection(
          context,
          section: item.section,
          subtype: item.name,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusMeta.$2.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusMeta.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: statusMeta.$2,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: barValue,
                  minHeight: 6,
                  backgroundColor: color.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation(statusMeta.$2),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    item.isIncome
                        ? 'Received ${moneyInr.format(item.actual)}'
                        : 'Done ${moneyInr.format(item.actual)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                  const Spacer(),
                  Text(
                    item.planned <= 0
                        ? 'Not set up'
                        : status == TrackerItemStatus.over
                            ? 'Over by ${moneyInr.format(item.overAmount)}'
                            : status == TrackerItemStatus.fulfilled
                                ? 'Plan ${moneyInr.format(item.planned)}'
                                : 'Left ${moneyInr.format(item.remaining)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                ],
              ),
              if (item.txnCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${item.txnCount} transaction${item.txnCount == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  (String, Color) _statusMeta(TrackerItemStatus status) {
    switch (status) {
      case TrackerItemStatus.fulfilled:
        return ('Fulfilled', const Color(0xFF16A34A));
      case TrackerItemStatus.remaining:
        return ('Remaining', const Color(0xFFD97706));
      case TrackerItemStatus.missed:
        return ('Missed', const Color(0xFFDC2626));
      case TrackerItemStatus.over:
        return ('Over', const Color(0xFF7C3AED));
      case TrackerItemStatus.notSetup:
        return ('Not set up', const Color(0xFF64748B));
    }
  }
}
