import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/planner_navigation.dart';
import '../../../data/models/money_plan_model.dart';
import '../../../data/models/transaction_model_new.dart';
import '../../../logic/cubits/money_plan_cubit.dart';
import '../../../logic/cubits/transaction_cubit.dart';
import '../../widgets/sms_sync_sheet.dart';

/// Dedicated page for one Money Planner section.
/// Overview = subtypes + transactions. Edit = one place for all subcategory amounts.
class MoneyPlanSectionScreen extends StatefulWidget {
  final String section;
  final String? initialSubtype;

  const MoneyPlanSectionScreen({
    super.key,
    required this.section,
    this.initialSubtype,
  });

  @override
  State<MoneyPlanSectionScreen> createState() => _MoneyPlanSectionScreenState();
}

class _MoneyPlanSectionScreenState extends State<MoneyPlanSectionScreen>
    with SingleTickerProviderStateMixin {
  late String _selectedSubtype;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    final defaults = SmsSyncSheet.plannerSubtypes[widget.section] ??
        SmsSyncSheet.plannerSubtypes[PlannerSections.essentials]!;
    _selectedSubtype = widget.initialSubtype != null &&
            defaults.contains(widget.initialSubtype)
        ? widget.initialSubtype!
        : (widget.initialSubtype ?? defaults.first);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<String> _subtypes(MoneyPlanModel plan) {
    final list = List<String>.from(
      SmsSyncSheet.plannerSubtypes[widget.section] ?? const ['Other'],
    );
    switch (widget.section) {
      case PlannerSections.essentials:
        for (final e in plan.expenses) {
          if (e.name.isNotEmpty && !list.contains(e.name)) {
            list.insert(0, e.name);
          }
        }
        break;
      case PlannerSections.investment:
        for (final i in plan.investments) {
          if (i.name.isNotEmpty && !list.contains(i.name)) {
            list.insert(0, i.name);
          }
        }
        break;
      case PlannerSections.goals:
        for (final g in plan.goals) {
          if (g.name.isNotEmpty && !list.contains(g.name)) {
            list.insert(0, g.name);
          }
        }
        break;
      case PlannerSections.debt:
        for (final d in plan.debts) {
          if (d.name.isNotEmpty && !list.contains(d.name)) {
            list.insert(0, d.name);
          }
        }
        break;
      case PlannerSections.personal:
        for (final p in plan.personalCategories) {
          if (p.name.isNotEmpty && !list.contains(p.name)) {
            list.insert(0, p.name);
          }
        }
        break;
    }
    return list;
  }

  List<TransactionModelNew> _sectionTxns(List<TransactionModelNew> all) {
    return all.where((t) {
      final info = parsePlannerNote(t.note);
      if (info.section != null) {
        return PlannerSections.normalize(info.section) == widget.section;
      }
      final subs = SmsSyncSheet.plannerSubtypes[widget.section] ?? const [];
      return subs.contains(t.category);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  String _summary(MoneyPlanModel plan) {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    switch (widget.section) {
      case PlannerSections.income:
        return '${currency.format(plan.income.availableMonthlyIncome)} / month';
      case PlannerSections.essentials:
        final total =
            plan.expenses.fold<double>(0, (s, e) => s + e.monthlyAmount);
        return '${currency.format(total)} essentials';
      case PlannerSections.investment:
        final total =
            plan.investments.fold<double>(0, (s, e) => s + e.monthlyAmount);
        return '${currency.format(total)} / month';
      case PlannerSections.emergency:
        return '${currency.format(plan.emergencyFund.monthlyContribution)} / month';
      case PlannerSections.goals:
        final activeGoals = plan.goals.where(
          (g) => g.targetAmount > 0 || g.monthlyContribution > 0,
        );
        final total =
            activeGoals.fold<double>(0, (s, g) => s + g.monthlyContribution);
        return '${currency.format(total)} / month · ${activeGoals.length} goals';
      case PlannerSections.debt:
        final total = plan.debts
            .where((d) => d.isActive)
            .fold<double>(0, (s, d) => s + d.emi);
        return '${currency.format(total)} EMI / month';
      case PlannerSections.personal:
        return '${currency.format(plan.personalBudget)} personal';
      default:
        return widget.section;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = PlannerSections.colorFor(widget.section);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.section,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: color,
          indicatorColor: color,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Edit'),
          ],
        ),
      ),
      body: BlocBuilder<MoneyPlanCubit, MoneyPlanState>(
        builder: (context, planState) {
          final plan = planState is MoneyPlanLoaded
              ? planState.plan
              : const MoneyPlanModel();

          return TabBarView(
            controller: _tabs,
            children: [
              _OverviewTab(
                section: widget.section,
                plan: plan,
                color: color,
                summary: _summary(plan),
                subtypes: _subtypes(plan),
                selectedSubtype: _selectedSubtype,
                onSubtypeSelected: (sub) =>
                    setState(() => _selectedSubtype = sub),
                sectionTxns: (txns) => _sectionTxns(txns),
                onGoToEdit: () => _tabs.animateTo(1),
              ),
              _SectionEditTab(
                key: ValueKey(
                  '${widget.section}_${plan.hashCode}_${planState.runtimeType}',
                ),
                section: widget.section,
                plan: plan,
                color: color,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final String section;
  final MoneyPlanModel plan;
  final Color color;
  final String summary;
  final List<String> subtypes;
  final String selectedSubtype;
  final ValueChanged<String> onSubtypeSelected;
  final List<TransactionModelNew> Function(List<TransactionModelNew>)
      sectionTxns;
  final VoidCallback onGoToEdit;

  const _OverviewTab({
    required this.section,
    required this.plan,
    required this.color,
    required this.summary,
    required this.subtypes,
    required this.selectedSubtype,
    required this.onSubtypeSelected,
    required this.sectionTxns,
    required this.onGoToEdit,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM');
    final effectiveSubtype = subtypes.contains(selectedSubtype)
        ? selectedSubtype
        : (subtypes.isNotEmpty ? subtypes.first : selectedSubtype);
    final chipMaxWidth = MediaQuery.sizeOf(context).width - 48;

    return BlocBuilder<TransactionCubit, TransactionState>(
      builder: (context, txnState) {
        final allTxns = txnState is TransactionLoaded
            ? txnState.transactions
            : <TransactionModelNew>[];
        final allSection = sectionTxns(allTxns);
        final subtypeTxns = allSection.where((t) {
          final info = parsePlannerNote(t.note);
          if (info.subtype != null && info.subtype!.isNotEmpty) {
            return info.subtype == effectiveSubtype;
          }
          return t.category == effectiveSubtype;
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.75)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(PlannerSections.iconFor(section),
                          color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          section,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    summary,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${allSection.length} linked transaction'
                    '${allSection.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onGoToEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit all subcategory amounts'),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withOpacity(0.45)),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Subcategories',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Filter transactions only — edit amounts in the Edit tab.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subtypes.map((sub) {
                final selected = effectiveSubtype == sub;
                return ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: chipMaxWidth),
                  child: ChoiceChip(
                    label: Text(
                      sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                    selected: selected,
                    onSelected: (_) => onSubtypeSelected(sub),
                    selectedColor: color.withOpacity(0.18),
                    labelStyle: TextStyle(
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? color : Colors.grey[800],
                    ),
                    side: BorderSide(
                      color: selected ? color : Colors.grey.withOpacity(0.25),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _readOnlyAmountCard(
              context,
              plan,
              color,
              currency,
              effectiveSubtype,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Transactions · $effectiveSubtype',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text(
                  '${subtypeTxns.length}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (subtypeTxns.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'No transactions tagged to this subcategory yet.',
                  style: TextStyle(color: Colors.grey[700], height: 1.35),
                ),
              )
            else
              ...subtypeTxns.map((t) {
                final isCredit = t.type == TransactionType.credit;
                final txnColor = isCredit ? Colors.green : Colors.red;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: txnColor.withOpacity(0.12),
                      child: Icon(
                        isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                        color: txnColor,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      t.description.isEmpty ? t.category : t.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${dateFormat.format(t.date)} · ${t.account}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      '${isCredit ? '+' : '-'}${currency.format(t.amount)}',
                      style: TextStyle(
                        color: txnColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () => openTransactionDetail(context, t),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _readOnlyAmountCard(
    BuildContext context,
    MoneyPlanModel plan,
    Color color,
    NumberFormat currency,
    String selectedSubtype,
  ) {
    String detail = 'Open the Edit tab to change amounts';

    switch (section) {
      case PlannerSections.income:
        if (selectedSubtype == 'Salary') {
          detail = 'Salary ${currency.format(plan.income.monthlyIncome)} / month';
        } else if (selectedSubtype == 'Other income') {
          detail = 'Other income ${currency.format(plan.income.otherIncome)} / month';
        } else {
          detail =
              'Monthly ${currency.format(plan.income.monthlyIncome)}'
              '${plan.income.otherIncome > 0 ? ' + other ${currency.format(plan.income.otherIncome)}' : ''}';
        }
        break;
      case PlannerSections.essentials:
        final match = plan.expenses.where((e) => e.name == selectedSubtype);
        detail = match.isNotEmpty
            ? 'Budget ${currency.format(match.first.monthlyAmount)} / month'
            : 'Not set yet';
        break;
      case PlannerSections.investment:
        final match =
            plan.investments.where((i) => i.name == selectedSubtype);
        detail = match.isNotEmpty
            ? '${currency.format(match.first.monthlyAmount)} / month'
            : 'Not set yet';
        break;
      case PlannerSections.emergency:
        if (selectedSubtype == 'Monthly contribution') {
          detail =
              'Contribution ${currency.format(plan.emergencyFund.monthlyContribution)} / month';
        } else {
          detail =
              'Contribution ${currency.format(plan.emergencyFund.monthlyContribution)}'
              ' · ${plan.emergencyFund.targetMonths} months';
        }
        break;
      case PlannerSections.goals:
        final match = plan.goals.where((g) => g.name == selectedSubtype);
        detail = match.isNotEmpty
            ? '${currency.format(match.first.monthlyContribution)} / month'
            : 'Not set yet';
        break;
      case PlannerSections.debt:
        final match = plan.debts.where((d) => d.name == selectedSubtype);
        detail = match.isNotEmpty
            ? 'EMI ${currency.format(match.first.emi)} / month'
            : 'Not set yet';
        break;
      case PlannerSections.personal:
        final match =
            plan.personalCategories.where((e) => e.name == selectedSubtype);
        detail = match.isNotEmpty
            ? 'Budget ${currency.format(match.first.monthlyAmount)} / month'
            : 'Budget ${currency.format(plan.personalBudget)}';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedSubtype,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(detail, style: TextStyle(color: Colors.grey[800], height: 1.35)),
        ],
      ),
    );
  }
}

/// Single Edit tab: change all subcategory amounts for this section at once.
class _SectionEditTab extends StatefulWidget {
  final String section;
  final MoneyPlanModel plan;
  final Color color;

  const _SectionEditTab({
    super.key,
    required this.section,
    required this.plan,
    required this.color,
  });

  @override
  State<_SectionEditTab> createState() => _SectionEditTabState();
}

class _SectionEditTabState extends State<_SectionEditTab> {
  late final TextEditingController _incomeMonthly;
  late final TextEditingController _incomeOther;
  late final TextEditingController _emergencyCurrent;
  late final TextEditingController _emergencyMonths;
  late final TextEditingController _emergencyMonthly;
  final _newSubtypeController = TextEditingController();

  late List<PlanExpense> _personalItems;
  late List<TextEditingController> _personalAmounts;

  late List<PlanExpense> _expenses;
  late List<TextEditingController> _expenseAmounts;

  late List<PlanInvestment> _investments;
  late List<TextEditingController> _investAmounts;
  late List<TextEditingController> _investMins;

  late List<PlanGoal> _goals;
  late List<TextEditingController> _goalTargets;
  late List<TextEditingController> _goalSaved;
  late List<TextEditingController> _goalMonthly;

  late List<PlanDebt> _debts;
  late List<TextEditingController> _debtEmis;
  late List<TextEditingController> _debtMonths;
  late List<TextEditingController> _debtOutstanding;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;

    _incomeMonthly = TextEditingController(
      text: plan.income.monthlyIncome.toStringAsFixed(0),
    );
    _incomeOther = TextEditingController(
      text: plan.income.otherIncome.toStringAsFixed(0),
    );
    _emergencyCurrent = TextEditingController(
      text: plan.emergencyFund.currentSavings.toStringAsFixed(0),
    );
    _emergencyMonths = TextEditingController(
      text: plan.emergencyFund.targetMonths.toString(),
    );
    _emergencyMonthly = TextEditingController(
      text: plan.emergencyFund.monthlyContribution.toStringAsFixed(0),
    );

    _expenses = PlannerCategories.withDefaultSubtypes(
      section: PlannerSections.essentials,
      existing: plan.expenses,
      nameOf: (e) => e.name,
      createMissing: (name) => PlanExpense(
        id: const Uuid().v4(),
        name: name,
        monthlyAmount: 0,
      ),
    );
    _expenseAmounts = _expenses
        .map((e) => TextEditingController(
              text: e.monthlyAmount.toStringAsFixed(0),
            ))
        .toList();

    _investments = PlannerCategories.withDefaultSubtypes(
      section: PlannerSections.investment,
      existing: plan.investments,
      nameOf: (i) => i.name,
      createMissing: (name) => PlanInvestment(
        id: const Uuid().v4(),
        name: name,
        type: PlannerCategories.investmentTypeFor(name),
        monthlyAmount: 0,
        minimumAmount: 0,
      ),
    );
    _investAmounts = _investments
        .map((i) => TextEditingController(
              text: i.monthlyAmount.toStringAsFixed(0),
            ))
        .toList();
    _investMins = _investments
        .map((i) => TextEditingController(
              text: i.minimumAmount.toStringAsFixed(0),
            ))
        .toList();

    _goals = PlannerCategories.withDefaultSubtypes(
      section: PlannerSections.goals,
      existing: plan.goals,
      nameOf: (g) => g.name,
      createMissing: (name) => PlanGoal(
        id: const Uuid().v4(),
        name: name,
        goalType: PlannerCategories.goalTypeFor(name),
        targetAmount: 0,
        currentAmount: 0,
        monthlyContribution: 0,
      ),
    );
    _goalTargets = _goals
        .map((g) => TextEditingController(
              text: g.targetAmount.toStringAsFixed(0),
            ))
        .toList();
    _goalSaved = _goals
        .map((g) => TextEditingController(
              text: g.currentAmount.toStringAsFixed(0),
            ))
        .toList();
    _goalMonthly = _goals
        .map((g) => TextEditingController(
              text: g.monthlyContribution.toStringAsFixed(0),
            ))
        .toList();

    _debts = PlannerCategories.withDefaultSubtypes(
      section: PlannerSections.debt,
      existing: plan.debts,
      nameOf: (d) => d.name,
      createMissing: (name) => PlanDebt(
        id: const Uuid().v4(),
        name: name,
        emi: 0,
        outstanding: 0,
        remainingMonths: 0,
      ),
    );
    _debtEmis = _debts
        .map((d) => TextEditingController(text: d.emi.toStringAsFixed(0)))
        .toList();
    _debtMonths = _debts
        .map((d) => TextEditingController(text: d.remainingMonths.toString()))
        .toList();
    _debtOutstanding = _debts
        .map((d) =>
            TextEditingController(text: d.outstanding.toStringAsFixed(0)))
        .toList();

    _personalItems = PlannerCategories.withDefaultSubtypes(
      section: PlannerSections.personal,
      existing: plan.personalCategories,
      nameOf: (e) => e.name,
      createMissing: (name) => PlanExpense(
        id: const Uuid().v4(),
        name: name,
        monthlyAmount: 0,
        kind: ExpenseKind.optionalExpense,
        priority: PlanPriority.flexible,
      ),
    );
    if (plan.personalCategories.isEmpty && plan.personalSpending > 0) {
      final idx = _personalItems.indexWhere((e) => e.name == 'Lifestyle');
      final i = idx >= 0 ? idx : 0;
      if (_personalItems.isNotEmpty) {
        _personalItems[i] = _personalItems[i].copyWith(
          monthlyAmount: plan.personalSpending,
        );
      }
    }
    _personalAmounts = _personalItems
        .map((e) => TextEditingController(
              text: e.monthlyAmount.toStringAsFixed(0),
            ))
        .toList();
  }

  @override
  void dispose() {
    _incomeMonthly.dispose();
    _incomeOther.dispose();
    _emergencyCurrent.dispose();
    _emergencyMonths.dispose();
    _emergencyMonthly.dispose();
    _newSubtypeController.dispose();
    for (final c in [
      ..._expenseAmounts,
      ..._investAmounts,
      ..._investMins,
      ..._goalTargets,
      ..._goalSaved,
      ..._goalMonthly,
      ..._debtEmis,
      ..._debtMonths,
      ..._debtOutstanding,
      ..._personalAmounts,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double _parse(String text) => double.tryParse(text.trim()) ?? 0;

  Future<void> _addSubtype(String section) async {
    _newSubtypeController.clear();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add $section subcategory'),
        content: TextField(
          controller: _newSubtypeController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Subcategory name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) =>
              Navigator.of(ctx).pop(_newSubtypeController.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_newSubtypeController.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;

    switch (section) {
      case PlannerSections.essentials:
        if (_expenses.any((e) => e.name.toLowerCase() == trimmed.toLowerCase())) {
          _showDuplicateSubtype();
          return;
        }
        setState(() {
          _expenses.add(
            PlanExpense(
              id: const Uuid().v4(),
              name: trimmed,
              monthlyAmount: 0,
            ),
          );
          _expenseAmounts.add(TextEditingController(text: '0'));
        });
        break;
      case PlannerSections.investment:
        if (_investments
            .any((e) => e.name.toLowerCase() == trimmed.toLowerCase())) {
          _showDuplicateSubtype();
          return;
        }
        setState(() {
          _investments.add(
            PlanInvestment(
              id: const Uuid().v4(),
              name: trimmed,
              type: PlannerCategories.investmentTypeFor(trimmed),
              monthlyAmount: 0,
              minimumAmount: 0,
            ),
          );
          _investAmounts.add(TextEditingController(text: '0'));
          _investMins.add(TextEditingController(text: '0'));
        });
        break;
      case PlannerSections.goals:
        if (_goals.any((e) => e.name.toLowerCase() == trimmed.toLowerCase())) {
          _showDuplicateSubtype();
          return;
        }
        setState(() {
          _goals.add(
            PlanGoal(
              id: const Uuid().v4(),
              name: trimmed,
              goalType: PlannerCategories.goalTypeFor(trimmed),
              targetAmount: 0,
              currentAmount: 0,
              monthlyContribution: 0,
            ),
          );
          _goalTargets.add(TextEditingController(text: '0'));
          _goalSaved.add(TextEditingController(text: '0'));
          _goalMonthly.add(TextEditingController(text: '0'));
        });
        break;
      case PlannerSections.debt:
        if (_debts.any((e) => e.name.toLowerCase() == trimmed.toLowerCase())) {
          _showDuplicateSubtype();
          return;
        }
        setState(() {
          _debts.add(
            PlanDebt(
              id: const Uuid().v4(),
              name: trimmed,
              emi: 0,
              outstanding: 0,
              remainingMonths: 0,
            ),
          );
          _debtEmis.add(TextEditingController(text: '0'));
          _debtMonths.add(TextEditingController(text: '0'));
          _debtOutstanding.add(TextEditingController(text: '0'));
        });
        break;
      case PlannerSections.personal:
        if (_personalItems
            .any((e) => e.name.toLowerCase() == trimmed.toLowerCase())) {
          _showDuplicateSubtype();
          return;
        }
        setState(() {
          _personalItems.add(
            PlanExpense(
              id: const Uuid().v4(),
              name: trimmed,
              monthlyAmount: 0,
              kind: ExpenseKind.optionalExpense,
              priority: PlanPriority.flexible,
            ),
          );
          _personalAmounts.add(TextEditingController(text: '0'));
        });
        break;
    }
  }

  void _showDuplicateSubtype() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('That subcategory already exists')),
    );
  }

  Widget _addSubtypeButton(String section) {
    return OutlinedButton.icon(
      onPressed: () => _addSubtype(section),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Add new subcategory'),
    );
  }

  Widget _investmentSetupCard() {
    final active = _investments
        .where((i) => i.monthlyAmount > 0 || i.minimumAmount > 0)
        .toList();
    final total = active.fold<double>(0, (s, i) => s + i.monthlyAmount);
    final protected = active.fold<double>(0, (s, i) => s + i.minimumAmount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current investment setup',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: widget.color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            active.isEmpty
                ? 'No active holdings yet. Add your current investment buckets below.'
                : 'Holding ${active.length} bucket${active.length == 1 ? '' : 's'} · ₹${total.toStringAsFixed(0)} monthly · ₹${protected.toStringAsFixed(0)} protected minimum',
            style: TextStyle(color: Colors.grey[800], height: 1.35),
          ),
          if (active.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: active
                  .map(
                    (i) => Chip(
                      label: Text(
                        '${i.name} · ₹${i.monthlyAmount.toStringAsFixed(0)}',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final cubit = context.read<MoneyPlanCubit>();

    try {
      switch (PlannerSections.normalize(widget.section)) {
        case PlannerSections.income:
          await cubit.updateIncome(
            widget.plan.income.copyWith(
              monthlyIncome: _parse(_incomeMonthly.text),
              otherIncome: _parse(_incomeOther.text),
            ),
          );
          break;
        case PlannerSections.personal:
          await cubit.updatePersonalCategories([
            for (var i = 0; i < _personalItems.length; i++)
              _personalItems[i].copyWith(
                monthlyAmount: _parse(_personalAmounts[i].text),
              ),
          ]);
          break;
        case PlannerSections.emergency:
          await cubit.updateEmergency(
            widget.plan.emergencyFund.copyWith(
              currentSavings: _parse(_emergencyCurrent.text),
              targetMonths: int.tryParse(_emergencyMonths.text) ?? 6,
              monthlyContribution: _parse(_emergencyMonthly.text),
            ),
          );
          break;
        case PlannerSections.essentials:
          await cubit.updateExpenses([
            for (var i = 0; i < _expenses.length; i++)
              _expenses[i].copyWith(monthlyAmount: _parse(_expenseAmounts[i].text)),
          ]);
          break;
        case PlannerSections.investment:
          await cubit.updateInvestments([
            for (var i = 0; i < _investments.length; i++)
              _investments[i].copyWith(
                monthlyAmount: _parse(_investAmounts[i].text),
                minimumAmount: _parse(_investMins[i].text),
                isProtected: true,
              ),
          ]);
          break;
        case PlannerSections.goals:
          await cubit.updateGoals([
            for (var i = 0; i < _goals.length; i++)
              _goals[i].copyWith(
                targetAmount: _parse(_goalTargets[i].text),
                currentAmount: _parse(_goalSaved[i].text),
                monthlyContribution: _parse(_goalMonthly[i].text),
              ),
          ]);
          break;
        case PlannerSections.debt:
          await cubit.updateDebts([
            for (var i = 0; i < _debts.length; i++)
              _debts[i].copyWith(
                emi: _parse(_debtEmis[i].text),
                remainingMonths: int.tryParse(_debtMonths[i].text) ?? 0,
                outstanding: _parse(_debtOutstanding[i].text),
                principal: _parse(_debtOutstanding[i].text) > 0
                    ? _parse(_debtOutstanding[i].text)
                    : _debts[i].principal,
              ),
          ]);
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan amounts saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _amountDeco(String label) => InputDecoration(
        labelText: label,
        prefixText: '₹ ',
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    final section = PlannerSections.normalize(widget.section);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          'Edit all ${widget.section} amounts',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Change every subcategory here in one place, then Save.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 16),
        ..._fieldsFor(section),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: widget.color,
            minimumSize: const Size.fromHeight(48),
          ),
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save all changes'),
        ),
      ],
    );
  }

  List<Widget> _fieldsFor(String section) {
    switch (section) {
      case PlannerSections.income:
        return [
          TextField(
            controller: _incomeMonthly,
            keyboardType: TextInputType.number,
            decoration: _amountDeco('Salary'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _incomeOther,
            keyboardType: TextInputType.number,
            decoration: _amountDeco('Other income'),
          ),
        ];
      case PlannerSections.personal:
        return [
          _addSubtypeButton(section),
          const SizedBox(height: 12),
          for (var i = 0; i < _personalItems.length; i++) ...[
            TextField(
              controller: _personalAmounts[i],
              keyboardType: TextInputType.number,
              decoration: _amountDeco(_personalItems[i].name),
            ),
            const SizedBox(height: 12),
          ],
        ];
      case PlannerSections.emergency:
        return [
          TextField(
            controller: _emergencyCurrent,
            keyboardType: TextInputType.number,
            decoration: _amountDeco('Current savings'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emergencyMonths,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Target months',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emergencyMonthly,
            keyboardType: TextInputType.number,
            decoration: _amountDeco('Monthly contribution'),
          ),
        ];
      case PlannerSections.essentials:
        return [
          _addSubtypeButton(section),
          const SizedBox(height: 12),
          for (var i = 0; i < _expenses.length; i++) ...[
            TextField(
              controller: _expenseAmounts[i],
              keyboardType: TextInputType.number,
              decoration: _amountDeco(_expenses[i].name),
            ),
            const SizedBox(height: 12),
          ],
        ];
      case PlannerSections.investment:
        return [
          _investmentSetupCard(),
          const SizedBox(height: 12),
          _addSubtypeButton(section),
          const SizedBox(height: 12),
          for (var i = 0; i < _investments.length; i++) ...[
            Text(
              _investments[i].name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _investAmounts[i],
              keyboardType: TextInputType.number,
              decoration: _amountDeco('Monthly amount'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _investMins[i],
              keyboardType: TextInputType.number,
              decoration: _amountDeco('Protected minimum'),
            ),
            const SizedBox(height: 16),
          ],
        ];
      case PlannerSections.goals:
        return [
          _addSubtypeButton(section),
          const SizedBox(height: 12),
          for (var i = 0; i < _goals.length; i++) ...[
            Text(
              _goals[i].name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _goalTargets[i],
              keyboardType: TextInputType.number,
              decoration: _amountDeco('Target amount'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _goalSaved[i],
              keyboardType: TextInputType.number,
              decoration: _amountDeco('Already saved'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _goalMonthly[i],
              keyboardType: TextInputType.number,
              decoration: _amountDeco('Monthly contribution'),
            ),
            const SizedBox(height: 16),
          ],
        ];
      case PlannerSections.debt:
        return [
          _addSubtypeButton(section),
          const SizedBox(height: 12),
          for (var i = 0; i < _debts.length; i++) ...[
            Text(
              _debts[i].name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _debtEmis[i],
              keyboardType: TextInputType.number,
              decoration: _amountDeco('EMI'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _debtMonths[i],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Remaining months',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _debtOutstanding[i],
              keyboardType: TextInputType.number,
              decoration: _amountDeco('Outstanding'),
            ),
            const SizedBox(height: 16),
          ],
        ];
      default:
        return [const Text('Nothing to edit for this section.')];
    }
  }
}
