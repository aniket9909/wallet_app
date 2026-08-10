import 'package:flutter/material.dart';
import '../../data/models/transaction_model_new.dart';
import '../../presentation/screens/money_planner/money_plan_section_screen.dart';
import '../../presentation/screens/transaction_detail_screen.dart';

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
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => MoneyPlanSectionScreen(
        section: PlannerSections.normalize(section),
        initialSubtype: subtype,
      ),
    ),
  );
}
