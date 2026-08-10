import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/planner_navigation.dart';
import '../../../data/models/money_plan_model.dart';
import '../../../data/models/transaction_model_new.dart';
import '../../../logic/cubits/money_plan_cubit.dart';
import '../../../logic/cubits/transaction_cubit.dart';
import '../../widgets/sms_sync_sheet.dart';

/// Dedicated page for one Money Planner section + its subtypes + linked txns.
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

class _MoneyPlanSectionScreenState extends State<MoneyPlanSectionScreen> {
  late String _selectedSubtype;

  @override
  void initState() {
    super.initState();
    final defaults = SmsSyncSheet.plannerSubtypes[widget.section] ??
        SmsSyncSheet.plannerSubtypes[PlannerSections.essentials]!;
    _selectedSubtype = widget.initialSubtype != null &&
            defaults.contains(widget.initialSubtype)
        ? widget.initialSubtype!
        : (widget.initialSubtype ?? defaults.first);
  }

  List<String> _subtypes(MoneyPlanModel plan) {
    final list = List<String>.from(
      SmsSyncSheet.plannerSubtypes[widget.section] ?? const ['Other'],
    );
    switch (widget.section) {
      case PlannerSections.essentials:
        for (final e in plan.expenses) {
          if (e.name.isNotEmpty && !list.contains(e.name)) list.insert(0, e.name);
        }
        break;
      case PlannerSections.investment:
        for (final i in plan.investments) {
          if (i.name.isNotEmpty && !list.contains(i.name)) list.insert(0, i.name);
        }
        break;
      case PlannerSections.goals:
        for (final g in plan.goals) {
          if (g.name.isNotEmpty && !list.contains(g.name)) list.insert(0, g.name);
        }
        break;
      case PlannerSections.debt:
        for (final d in plan.debts) {
          if (d.name.isNotEmpty && !list.contains(d.name)) list.insert(0, d.name);
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
      // Fallback: category matches a subtype of this section.
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
        final total =
            plan.goals.fold<double>(0, (s, g) => s + g.monthlyContribution);
        return '${currency.format(total)} / month · ${plan.goals.length} goals';
      case PlannerSections.debt:
        final total = plan.debts
            .where((d) => d.isActive)
            .fold<double>(0, (s, d) => s + d.emi);
        return '${currency.format(total)} EMI / month';
      case PlannerSections.personal:
        return '${currency.format(plan.personalSpending)} personal';
      default:
        return widget.section;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = PlannerSections.colorFor(widget.section);
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.section,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: BlocBuilder<MoneyPlanCubit, MoneyPlanState>(
        builder: (context, planState) {
          final plan = planState is MoneyPlanLoaded
              ? planState.plan
              : const MoneyPlanModel();
          final subtypes = _subtypes(plan);
          final effectiveSubtype = subtypes.contains(_selectedSubtype)
              ? _selectedSubtype
              : (subtypes.isNotEmpty ? subtypes.first : _selectedSubtype);
          final chipMaxWidth = MediaQuery.sizeOf(context).width - 48;

          return BlocBuilder<TransactionCubit, TransactionState>(
            builder: (context, txnState) {
              final allTxns = txnState is TransactionLoaded
                  ? txnState.transactions
                  : <TransactionModelNew>[];
              final sectionTxns = _sectionTxns(allTxns);
              final subtypeTxns = sectionTxns.where((t) {
                final info = parsePlannerNote(t.note);
                if (info.subtype != null && info.subtype!.isNotEmpty) {
                  return info.subtype == effectiveSubtype;
                }
                return t.category == effectiveSubtype;
              }).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
                            Icon(PlannerSections.iconFor(widget.section),
                                color: Colors.white),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.section,
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
                          _summary(plan),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${sectionTxns.length} linked transaction'
                          '${sectionTxns.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Subtypes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
                          onSelected: (_) =>
                              setState(() => _selectedSubtype = sub),
                          selectedColor: color.withOpacity(0.18),
                          labelStyle: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? color : Colors.grey[800],
                          ),
                          side: BorderSide(
                            color:
                                selected ? color : Colors.grey.withOpacity(0.25),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Setup · $effectiveSubtype',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _sectionSetupCard(context, plan, color, effectiveSubtype),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'Transactions · $effectiveSubtype',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                        'No transactions tagged to this subtype yet.\n'
                        'SMS sync with this planner section will appear here.',
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
                              isCredit
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
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
                          trailing: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 110),
                            child: Text(
                              '${isCredit ? '+' : '-'}${currency.format(t.amount)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: txnColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          onTap: () => openTransactionDetail(context, t),
                        ),
                      );
                    }),
                  if (sectionTxns.isNotEmpty &&
                      subtypeTxns.length != sectionTxns.length) ...[
                    const SizedBox(height: 16),
                    Text(
                      'All section transactions',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...sectionTxns.take(10).map((t) {
                      final info = parsePlannerNote(t.note);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          t.description.isEmpty ? t.category : t.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          info.subtype ?? t.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => openTransactionDetail(context, t),
                      );
                    }),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _sectionSetupCard(
    BuildContext context,
    MoneyPlanModel plan,
    Color color,
    String selectedSubtype,
  ) {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    String title = selectedSubtype;
    String detail = 'Planner subtype setup';

    switch (widget.section) {
      case PlannerSections.income:
        detail =
            'Monthly income ${currency.format(plan.income.monthlyIncome)}'
            '${plan.income.otherIncome > 0 ? ' + other ${currency.format(plan.income.otherIncome)}' : ''}';
        break;
      case PlannerSections.essentials:
        final match = plan.expenses.where((e) => e.name == selectedSubtype);
        if (match.isNotEmpty) {
          detail =
              'Budget ${currency.format(match.first.monthlyAmount)} / month'
              ' · ${match.first.kind.label}';
        } else {
          detail = 'Default subtype — add in planner setup if needed';
        }
        break;
      case PlannerSections.investment:
        final match =
            plan.investments.where((i) => i.name == selectedSubtype);
        if (match.isNotEmpty) {
          final i = match.first;
          detail = '${currency.format(i.monthlyAmount)} / month'
              '${i.isProtected ? ' · protected min ${currency.format(i.minimumAmount)}' : ''}';
        }
        break;
      case PlannerSections.emergency:
        detail =
            'Contribution ${currency.format(plan.emergencyFund.monthlyContribution)}'
            ' · target ${plan.emergencyFund.targetMonths} months'
            ' (${currency.format(plan.emergencyFund.targetAmount)})';
        break;
      case PlannerSections.goals:
        final match = plan.goals.where((g) => g.name == selectedSubtype);
        if (match.isNotEmpty) {
          final g = match.first;
          detail =
              '${currency.format(g.currentAmount)} / ${currency.format(g.effectiveTarget)}'
              ' · ${currency.format(g.requiredMonthlyContribution)}/mo required';
        }
        break;
      case PlannerSections.debt:
        final match = plan.debts.where((d) => d.name == selectedSubtype);
        if (match.isNotEmpty) {
          final d = match.first;
          detail =
              'EMI ${currency.format(d.emi)} · ${d.remainingMonths} months left';
        }
        break;
      case PlannerSections.personal:
        detail =
            'Personal spending budget ${currency.format(plan.personalSpending)}';
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
            title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            softWrap: true,
            style: TextStyle(color: Colors.grey[800], height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(
            'SMS sync with section "${widget.section}" and subtype "$selectedSubtype" will list below.',
            softWrap: true,
            style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.35),
          ),
        ],
      ),
    );
  }
}
