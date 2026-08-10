import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/planner_navigation.dart';
import '../../../data/models/money_plan_model.dart';
import '../../../data/services/money_plan_engine.dart';
import '../../../logic/cubits/money_plan_cubit.dart';
import '../../widgets/money_planner/money_plan_widgets.dart';
import 'monthly_tracker_screen.dart';

class MoneyPlanDashboard extends StatelessWidget {
  const MoneyPlanDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MoneyPlanCubit, MoneyPlanState>(
      builder: (context, state) {
        if (state is MoneyPlanLoading || state is MoneyPlanInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is MoneyPlanError) {
          return Center(child: Text(state.message));
        }
        if (state is! MoneyPlanLoaded) {
          return const SizedBox.shrink();
        }

        final snap = state.snapshot;
        final plan = state.plan;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            if (state.pendingSuggestion != null)
              SuggestionBanner(
                suggestion: state.pendingSuggestion!,
                onApply: () {
                  context.read<MoneyPlanCubit>().applySuggestion(
                        state.pendingSuggestion!.allocations,
                      );
                },
                onDismiss: () =>
                    context.read<MoneyPlanCubit>().clearSuggestion(),
              ),
            if (snap.conflict != null && snap.conflict!.hasConflict) ...[
              BudgetConflictCard(conflict: snap.conflict!),
              const SizedBox(height: 12),
            ],
            _summaryStrip(context, snap),
            const SizedBox(height: 12),
            _monthlyTrackerEntry(context),
            const SizedBox(height: 16),
            _allocationCard(context, snap),
            const SizedBox(height: 16),
            _healthCard(context, snap.health),
            const SizedBox(height: 16),
            Text(
              'Sections',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.15,
              children: [
                PlanMetricCard(
                  label: 'Income',
                  value: moneyInr.format(snap.totalIncome),
                  subtitle: 'Open section',
                  icon: Icons.payments_outlined,
                  color: const Color(0xFF6366F1),
                  onTap: () => openPlannerSection(
                    context,
                    section: PlannerSections.income,
                  ),
                ),
                PlanMetricCard(
                  label: 'Essentials',
                  value: moneyInr.format(snap.essentialsTotal),
                  subtitle: _pct(snap.essentialsTotal, snap.totalIncome),
                  icon: Icons.home_outlined,
                  color: const Color(0xFF0EA5E9),
                  onTap: () => openPlannerSection(
                    context,
                    section: PlannerSections.essentials,
                  ),
                ),
                PlanMetricCard(
                  label: 'Investment',
                  value: moneyInr.format(snap.investmentsTotal),
                  subtitle:
                      'Protected ${moneyInr.format(snap.protectedInvestments)}',
                  icon: Icons.trending_up,
                  color: const Color(0xFF10B981),
                  onTap: () => openPlannerSection(
                    context,
                    section: PlannerSections.investment,
                  ),
                ),
                PlanMetricCard(
                  label: 'Emergency',
                  value: moneyInr.format(snap.emergencyMonthly),
                  subtitle:
                      '${plan.emergencyFund.progressPercentage.toStringAsFixed(0)}% funded',
                  icon: Icons.health_and_safety_outlined,
                  color: const Color(0xFFEF4444),
                  onTap: () => openPlannerSection(
                    context,
                    section: PlannerSections.emergency,
                  ),
                ),
                PlanMetricCard(
                  label: 'Goals',
                  value: moneyInr.format(snap.goalsTotal),
                  subtitle: '${plan.goals.length} active',
                  icon: Icons.flag_outlined,
                  color: const Color(0xFFF59E0B),
                  onTap: () => openPlannerSection(
                    context,
                    section: PlannerSections.goals,
                  ),
                ),
                PlanMetricCard(
                  label: 'Debt & EMI',
                  value: moneyInr.format(snap.debtTotal),
                  subtitle: '${plan.debts.where((d) => d.isActive).length} loans',
                  icon: Icons.account_balance,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => openPlannerSection(
                    context,
                    section: PlannerSections.debt,
                  ),
                ),
                PlanMetricCard(
                  label: 'Personal',
                  value: moneyInr.format(snap.personal),
                  subtitle: _pct(snap.personal, snap.totalIncome),
                  icon: Icons.person_outline,
                  color: const Color(0xFF64748B),
                  onTap: () => openPlannerSection(
                    context,
                    section: PlannerSections.personal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _forecastCard(context, snap.forecast12),
            const SizedBox(height: 16),
            _goalsPreview(context, plan),
            const SizedBox(height: 16),
            _rulesCard(context, plan),
          ],
        ).animate().fadeIn(duration: 350.ms);
      },
    );
  }

  String _pct(double amount, double income) {
    if (income <= 0) return '0%';
    return '${(amount / income * 100).toStringAsFixed(1)}% of income';
  }

  Widget _summaryStrip(BuildContext context, MoneyPlanSnapshot snap) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _miniStat('Income', moneyInr.format(snap.totalIncome)),
          _miniStat('Planned', moneyInr.format(snap.plannedTotal)),
          _miniStat(
            'Remaining',
            moneyInr.format(snap.remaining),
            emphasize: true,
          ),
        ],
      ),
    );
  }

  Widget _monthlyTrackerEntry(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MonthlyTrackerScreen()),
          );
        },
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
            color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_month_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Tracker',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'See which categories are fulfilled, remaining, or missed',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, {bool emphasize = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: emphasize ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _allocationCard(BuildContext context, MoneyPlanSnapshot snap) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Where your money goes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AllocationDonut(slices: snap.slices),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (var i = 0; i < snap.slices.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AllocationDonut.colorFor(i),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${snap.slices[i].label} · ${snap.slices[i].percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _healthCard(BuildContext context, FinancialHealth health) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Financial Health: ${health.score}/100',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                CircularProgressIndicator(
                  value: health.score / 100,
                  strokeWidth: 6,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...health.breakdown.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(b.label)),
                    Text(
                      b.status,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _forecastCard(BuildContext context, ForecastSummary f) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '12-month forecast',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            _forecastRow('Income', f.income),
            _forecastRow('Investments', f.investments),
            _forecastRow('Goals', f.goals),
            _forecastRow('Emergency', f.emergency),
            _forecastRow('Debt payments', f.debtPayments),
            _forecastRow('Essentials', f.essentials),
            _forecastRow('Personal', f.personal),
          ],
        ),
      ),
    );
  }

  Widget _forecastRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              moneyInr.format(amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalsPreview(BuildContext context, MoneyPlanModel plan) {
    if (plan.goals.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: const Text('No goals yet'),
          subtitle: const Text('Add gold, vacation, or other targets'),
          trailing: const Icon(Icons.add),
          onTap: () => openPlannerSection(
            context,
            section: PlannerSections.goals,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Goals',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ...plan.goals.map((g) => _goalCard(context, g)),
      ],
    );
  }

  Widget _goalCard(BuildContext context, PlanGoal goal) {
    final status = goal.computedStatus;
    final color = switch (status) {
      GoalStatus.onTrack => Colors.green,
      GoalStatus.atRisk => Colors.orange,
      GoalStatus.offTrack => Colors.red,
      GoalStatus.completed => Colors.blue,
      GoalStatus.paused => Colors.grey,
    };
    final dateFmt = DateFormat('MMM yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openPlannerSection(
          context,
          section: PlannerSections.goals,
          subtype: goal.name,
        ),
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  goal.goalType == GoalType.gold
                      ? Icons.monetization_on
                      : Icons.flag,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    goal.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (goal.goalType == GoalType.gold && goal.goldDetails != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${goal.goldDetails!.quantityTola} tola',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '${moneyInr.format(goal.currentAmount)} / ${moneyInr.format(goal.effectiveTarget)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: goal.progressPercentage / 100,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Text(
              'Required ${moneyInr.format(goal.requiredMonthlyContribution)}/mo'
              '${goal.targetDate != null ? ' · ${dateFmt.format(goal.targetDate!)}' : ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _rulesCard(BuildContext context, MoneyPlanModel plan) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rules & priorities',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (plan.rules.isEmpty)
              const Text('No custom rules yet')
            else
              ...plan.rules.map(
                (r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    r.isActive ? Icons.check_circle : Icons.pause_circle,
                    color: r.isActive ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  title: Text(r.name),
                  subtitle: Text(r.description),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openIncome(BuildContext context, MoneyPlanModel plan) async {
    final monthly = TextEditingController(
      text: plan.income.monthlyIncome.toStringAsFixed(0),
    );
    final other = TextEditingController(
      text: plan.income.otherIncome.toStringAsFixed(0),
    );
    final ok = await _showEditSheet(
      context,
      title: 'Income',
      children: [
        TextField(
          controller: monthly,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Monthly income'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: other,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Other income'),
        ),
      ],
    );
    if (ok == true && context.mounted) {
      await context.read<MoneyPlanCubit>().updateIncome(
            plan.income.copyWith(
              monthlyIncome: double.tryParse(monthly.text) ?? 0,
              otherIncome: double.tryParse(other.text) ?? 0,
            ),
          );
    }
  }

  Future<void> _openExpenses(BuildContext context, MoneyPlanModel plan) async {
    final controllers = plan.expenses
        .map((e) => TextEditingController(
              text: e.monthlyAmount.toStringAsFixed(0),
            ))
        .toList();
    final personal = TextEditingController(
      text: plan.personalSpending.toStringAsFixed(0),
    );

    final ok = await _showEditSheet(
      context,
      title: 'Essential expenses',
      children: [
        for (var i = 0; i < plan.expenses.length; i++) ...[
          TextField(
            controller: controllers[i],
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: plan.expenses[i].name,
              helperText: plan.expenses[i].kind.label,
            ),
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: personal,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Personal spending'),
        ),
      ],
    );

    if (ok == true && context.mounted) {
      final updated = [
        for (var i = 0; i < plan.expenses.length; i++)
          plan.expenses[i].copyWith(
            monthlyAmount: double.tryParse(controllers[i].text) ?? 0,
          ),
      ];
      await context.read<MoneyPlanCubit>().updateExpenses(updated);
      await context.read<MoneyPlanCubit>().updatePersonalSpending(
            double.tryParse(personal.text) ?? 0,
          );
    }
  }

  Future<void> _openInvestments(
    BuildContext context,
    MoneyPlanModel plan,
  ) async {
    final first = plan.investments.isNotEmpty
        ? plan.investments.first
        : const PlanInvestment(
            id: 'sip_main',
            name: 'SIP',
            monthlyAmount: 0,
            minimumAmount: 0,
          );
    final amount = TextEditingController(
      text: first.monthlyAmount.toStringAsFixed(0),
    );
    final minimum = TextEditingController(
      text: first.minimumAmount.toStringAsFixed(0),
    );

    final ok = await _showEditSheet(
      context,
      title: 'Protected investment',
      children: [
        TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Monthly SIP'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: minimum,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Protected minimum (do not compromise)',
          ),
        ),
      ],
    );

    if (ok == true && context.mounted) {
      final updated = first.copyWith(
        monthlyAmount: double.tryParse(amount.text) ?? 0,
        minimumAmount: double.tryParse(minimum.text) ?? 0,
        isProtected: true,
      );
      final list = plan.investments.isEmpty
          ? [updated]
          : [
              updated,
              ...plan.investments.skip(1),
            ];
      await context.read<MoneyPlanCubit>().updateInvestments(list);
    }
  }

  Future<void> _openEmergency(
    BuildContext context,
    MoneyPlanModel plan,
  ) async {
    final current = TextEditingController(
      text: plan.emergencyFund.currentSavings.toStringAsFixed(0),
    );
    final months = TextEditingController(
      text: plan.emergencyFund.targetMonths.toString(),
    );
    final monthly = TextEditingController(
      text: plan.emergencyFund.monthlyContribution.toStringAsFixed(0),
    );

    final ok = await _showEditSheet(
      context,
      title: 'Emergency fund',
      children: [
        Text(
          'Target: ${moneyInr.format(plan.emergencyFund.targetAmount)} '
          '(${plan.emergencyFund.targetMonths} × essentials)',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: current,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Current savings'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: months,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Target months'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: monthly,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Monthly contribution'),
        ),
      ],
    );

    if (ok == true && context.mounted) {
      await context.read<MoneyPlanCubit>().updateEmergency(
            plan.emergencyFund.copyWith(
              currentSavings: double.tryParse(current.text) ?? 0,
              targetMonths: int.tryParse(months.text) ?? 6,
              monthlyContribution: double.tryParse(monthly.text) ?? 0,
            ),
          );
    }
  }

  Future<void> _openGoals(BuildContext context, MoneyPlanModel plan) async {
    final name = TextEditingController();
    final target = TextEditingController();
    final saved = TextEditingController(text: '0');
    DateTime targetDate = DateTime.now().add(const Duration(days: 365));
    var isGold = false;
    final tola = TextEditingController(text: '1');
    final price = TextEditingController(text: '7000');
    var priority = PlanPriority.medium;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Add goal',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Gold goal'),
                      value: isGold,
                      onChanged: (v) => setModal(() => isGold = v),
                    ),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 10),
                    if (isGold) ...[
                      TextField(
                        controller: tola,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Quantity (tola)'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: price,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price per gram',
                        ),
                      ),
                    ] else
                      TextField(
                        controller: target,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Target amount'),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: saved,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Already saved'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Target date: ${DateFormat('dd MMM yyyy').format(targetDate)}',
                      ),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: targetDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          setModal(() => targetDate = picked);
                        }
                      },
                    ),
                    DropdownButtonFormField<PlanPriority>(
                      value: priority,
                      items: PlanPriority.values
                          .map((p) =>
                              DropdownMenuItem(value: p, child: Text(p.label)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModal(() => priority = v);
                      },
                      decoration: const InputDecoration(labelText: 'Priority'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Save goal'),
                    ),
                    if (plan.goals.isNotEmpty) ...[
                      const Divider(height: 28),
                      ...plan.goals.map(
                        (g) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(g.name),
                          subtitle: Text(
                            '${moneyInr.format(g.requiredMonthlyContribution)}/mo required',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              context.read<MoneyPlanCubit>().deleteGoal(g.id);
                              Navigator.pop(ctx, false);
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (ok == true && context.mounted && name.text.trim().isNotEmpty) {
      PlanGoldDetails? gold;
      double targetAmt = double.tryParse(target.text) ?? 0;
      if (isGold) {
        gold = PlanGoldDetails(
          quantityTola: double.tryParse(tola.text) ?? 1,
          pricePerGram: double.tryParse(price.text) ?? 0,
        );
        targetAmt = gold.estimatedCost;
      }
      final goal = PlanGoal(
        id: const Uuid().v4(),
        name: name.text.trim(),
        goalType: isGold ? GoalType.gold : GoalType.standard,
        targetAmount: targetAmt,
        currentAmount: double.tryParse(saved.text) ?? 0,
        targetDate: targetDate,
        priority: priority,
        goldDetails: gold,
      );
      await context.read<MoneyPlanCubit>().addOrUpdateGoal(
            goal.copyWith(
              monthlyContribution: goal.requiredMonthlyContribution,
            ),
          );
    }
  }

  Future<void> _openDebts(BuildContext context, MoneyPlanModel plan) async {
    final name = TextEditingController();
    final emi = TextEditingController();
    final months = TextEditingController();
    final outstanding = TextEditingController();

    final ok = await _showEditSheet(
      context,
      title: 'Add EMI / loan',
      children: [
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Loan name'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: emi,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'EMI'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: months,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Remaining months'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: outstanding,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Outstanding'),
        ),
        if (plan.debts.isNotEmpty) ...[
          const Divider(height: 24),
          ...plan.debts.map(
            (d) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(d.name),
              subtitle: Text('${moneyInr.format(d.emi)}/mo'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  context.read<MoneyPlanCubit>().deleteDebt(d.id);
                  Navigator.pop(context, false);
                },
              ),
            ),
          ),
        ],
      ],
    );

    if (ok == true &&
        context.mounted &&
        name.text.trim().isNotEmpty &&
        (double.tryParse(emi.text) ?? 0) > 0) {
      final m = int.tryParse(months.text) ?? 0;
      await context.read<MoneyPlanCubit>().addOrUpdateDebt(
            PlanDebt(
              id: const Uuid().v4(),
              name: name.text.trim(),
              emi: double.tryParse(emi.text) ?? 0,
              remainingMonths: m,
              outstanding: double.tryParse(outstanding.text) ?? 0,
              principal: double.tryParse(outstanding.text) ?? 0,
            ),
          );
    }
  }

  Future<bool?> _showEditSheet(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...children,
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
