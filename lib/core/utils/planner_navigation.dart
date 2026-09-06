import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/money_plan_model.dart';
import '../../data/models/transaction_model_new.dart';
import '../../logic/cubits/money_plan_cubit.dart';
import '../../presentation/screens/money_planner/money_plan_section_screen.dart';
import '../../presentation/screens/transaction_detail_screen.dart';
import '../../presentation/theme/brand_colors.dart';
import 'budget_month_day_editor.dart';

/// Canonical Money Planner section keys used across SMS sync + planner UI.
class PlannerSections {
  static const income = 'Income';
  static const essentials = 'Essentials';
  static const investment = 'Investment';
  static const emergency = 'Emergency Fund';
  static const goals = 'Goals';
  static const debt = 'Debt & EMI';
  static const personal = 'Personal';

  static const all = <String>[
    income,
    essentials,
    investment,
    emergency,
    goals,
    debt,
    personal,
  ];

  /// Order used in SMS sync / add-transaction pickers.
  static const pickerOrder = <String>[
    essentials,
    investment,
    emergency,
    goals,
    debt,
    personal,
    income,
  ];

  static String normalize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return essentials;
    final v = raw.trim().toLowerCase();
    if (v.startsWith('income')) return income;
    if (v.startsWith('essential')) return essentials;
    if (v.startsWith('invest')) return investment;
    if (v.startsWith('emergency')) return emergency;
    if (v.startsWith('goal')) return goals;
    if (v.contains('debt') || v.contains('emi')) return debt;
    if (v.startsWith('personal')) return personal;
    return raw.trim();
  }

  static IconData iconFor(String section) {
    switch (normalize(section)) {
      case income:
        return Icons.payments_outlined;
      case essentials:
        return Icons.home_outlined;
      case investment:
        return Icons.trending_up;
      case emergency:
        return Icons.health_and_safety_outlined;
      case goals:
        return Icons.flag_outlined;
      case debt:
        return Icons.account_balance;
      case personal:
        return Icons.person_outline;
      default:
        return Icons.pie_chart_outline;
    }
  }

  static Color colorFor(String section) {
    switch (normalize(section)) {
      case income:
        return const Color(0xFF6366F1);
      case essentials:
        return const Color(0xFF0EA5E9);
      case investment:
        return const Color(0xFF10B981);
      case emergency:
        return const Color(0xFFEF4444);
      case goals:
        return const Color(0xFFF59E0B);
      case debt:
        return const Color(0xFF8B5CF6);
      case personal:
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF6366F1);
    }
  }
}

/// Shared Money Planner subcategory lists for SMS sync + manual transactions.
class PlannerCategories {
  static const Map<String, List<String>> defaultSubtypes = {
    PlannerSections.essentials: [
      'Housing/Rent',
      'Electricity',
      'Internet/Phone',
      'Food & Groceries',
      'Transportation',
      'Healthcare',
      'Insurance',
      'Family responsibilities',
      'Other essential',
    ],
    PlannerSections.investment: [
      'SIP',
      'Stocks',
      'Mutual funds',
      'Retirement',
      'Other investment',
    ],
    PlannerSections.emergency: [
      'Monthly contribution',
      'Top-up',
      'Other emergency',
    ],
    PlannerSections.goals: [
      'Gold',
      'Furniture',
      'Vacation',
      'Laptop',
      'Bike',
      'House down payment',
      'Education',
      'Wedding',
      'Car',
      'Other goal',
    ],
    PlannerSections.debt: [
      'Loan EMI',
      'Credit card',
      'Personal debt',
      'Other debt',
    ],
    PlannerSections.personal: [
      'Entertainment',
      'Dining out',
      'Hobbies',
      'Shopping',
      'Lifestyle',
      'Other personal',
    ],
    PlannerSections.income: [
      'Salary',
      'Other income',
      'Refund',
      'Transfer in',
    ],
  };

  static String defaultSectionFor({required bool isCredit}) =>
      isCredit ? PlannerSections.income : PlannerSections.essentials;

  static List<String> subtypesFor(
    String section, {
    MoneyPlanModel? plan,
    String? extraSubtype,
  }) {
    final key = PlannerSections.normalize(section);
    final defaults =
        List<String>.from(defaultSubtypes[key] ?? const ['Other']);

    if (plan != null) {
      switch (key) {
        case PlannerSections.essentials:
          for (final e in plan.expenses) {
            if (e.name.isNotEmpty && !defaults.contains(e.name)) {
              defaults.insert(0, e.name);
            }
          }
          break;
        case PlannerSections.investment:
          for (final i in plan.investments) {
            if (i.name.isNotEmpty && !defaults.contains(i.name)) {
              defaults.insert(0, i.name);
            }
          }
          break;
        case PlannerSections.goals:
          for (final g in plan.goals) {
            if (g.name.isNotEmpty && !defaults.contains(g.name)) {
              defaults.insert(0, g.name);
            }
          }
          break;
        case PlannerSections.debt:
          for (final d in plan.debts) {
            if (d.name.isNotEmpty && !defaults.contains(d.name)) {
              defaults.insert(0, d.name);
            }
          }
          break;
        case PlannerSections.personal:
          for (final p in plan.personalCategories) {
            if (p.name.isNotEmpty && !defaults.contains(p.name)) {
              defaults.insert(0, p.name);
            }
          }
          break;
      }
    }

    if (extraSubtype != null &&
        extraSubtype.isNotEmpty &&
        !defaults.contains(extraSubtype)) {
      defaults.insert(0, extraSubtype);
    }

    return defaults;
  }

  /// Ensures every default subcategory exists as an editable plan item.
  static List<T> withDefaultSubtypes<T>({
    required String section,
    required List<T> existing,
    required String Function(T) nameOf,
    required T Function(String name) createMissing,
  }) {
    final result = List<T>.from(existing);
    final names = {for (final item in result) nameOf(item)};
    for (final name
        in defaultSubtypes[PlannerSections.normalize(section)] ??
            const <String>[]) {
      if (!names.contains(name)) {
        result.add(createMissing(name));
      }
    }
    return result;
  }

  static InvestmentType investmentTypeFor(String name) {
    final v = name.trim().toLowerCase();
    if (v.contains('stock')) return InvestmentType.stocks;
    if (v.contains('mutual')) return InvestmentType.mutualFunds;
    if (v.contains('retire')) return InvestmentType.retirement;
    if (v.contains('sip')) return InvestmentType.sip;
    return InvestmentType.other;
  }

  static GoalType goalTypeFor(String name) {
    final v = name.trim().toLowerCase();
    if (v.contains('gold')) return GoalType.gold;
    if (v.contains('emergency')) return GoalType.emergency;
    return GoalType.standard;
  }

  static String formatNote({
    required String section,
    required String subtype,
    String? extra,
  }) {
    final header =
        'Planner: ${PlannerSections.normalize(section)} · Subtype: $subtype';
    if (extra == null || extra.trim().isEmpty) return header;
    return '$header\n${extra.trim()}';
  }
}

class PlannerNoteInfo {
  final String? section;
  final String? subtype;
  final String? smsBody;

  const PlannerNoteInfo({this.section, this.subtype, this.smsBody});

  bool get hasPlanner => section != null && section!.isNotEmpty;
}

PlannerNoteInfo parsePlannerNote(String? note) {
  if (note == null || note.trim().isEmpty) {
    return const PlannerNoteInfo();
  }
  final lines = note.split('\n');
  final header = lines.first;
  final match = RegExp(
    r'Planner:\s*(.+?)\s*·\s*Subtype:\s*(.+)$',
    caseSensitive: false,
  ).firstMatch(header);

  if (match == null) {
    return PlannerNoteInfo(smsBody: note);
  }

  return PlannerNoteInfo(
    section: PlannerSections.normalize(match.group(1)),
    subtype: match.group(2)?.trim(),
    smsBody: lines.length > 1 ? lines.sublist(1).join('\n').trim() : null,
  );
}

Future<void> openTransactionDetail(
  BuildContext context,
  TransactionModelNew transaction,
) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TransactionDetailScreen(transaction: transaction),
    ),
  );
}

Future<void> openPlannerSection(
  BuildContext context, {
  required String section,
  String? subtype,
  bool openEdit = false,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => MoneyPlanSectionScreen(
        section: PlannerSections.normalize(section),
        initialSubtype: subtype,
        initialTabIndex: openEdit ? 1 : 0,
      ),
    ),
  );
}

/// Bottom sheet to pick a planner section and open its Edit tab.
Future<void> showPlannerEditSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final maxHeight = MediaQuery.sizeOf(ctx).height * 0.75;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                'Edit plan',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Change amounts or the budget month start day without re-running setup.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: BrandColors.blue.withOpacity(0.15),
                  child: const Icon(
                    Icons.edit_calendar_outlined,
                    color: BrandColors.blue,
                    size: 20,
                  ),
                ),
                title: const Text('Budget month start day'),
                subtitle: const Text('When each plan month begins'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.pop(ctx);
                  final planState = context.read<MoneyPlanCubit>().state;
                  final day = planState is MoneyPlanLoaded
                      ? planState.plan.cycleStartDay
                      : 1;
                  await editAndSaveBudgetMonthDay(context, currentDay: day);
                },
              ),
              const Divider(),
              for (final section in PlannerSections.all)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor:
                        PlannerSections.colorFor(section).withOpacity(0.15),
                    child: Icon(
                      PlannerSections.iconFor(section),
                      color: PlannerSections.colorFor(section),
                      size: 20,
                    ),
                  ),
                  title: Text(section),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () {
                    Navigator.pop(ctx);
                    openPlannerSection(
                      context,
                      section: section,
                      openEdit: true,
                    );
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}
