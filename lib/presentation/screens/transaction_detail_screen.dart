import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/utils/planner_navigation.dart';
import '../../data/models/transaction_model_new.dart';
import '../../logic/cubits/transaction_cubit.dart';

class TransactionDetailScreen extends StatelessWidget {
  final TransactionModelNew transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.type == TransactionType.credit;
    final accent = isCredit ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFormat = DateFormat('EEE, dd MMM yyyy · hh:mm a');
    final planner = parsePlannerNote(transaction.note);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: [
          if (planner.hasPlanner)
            TextButton.icon(
              onPressed: () => openPlannerSection(
                context,
                section: planner.section!,
                subtype: planner.subtype,
              ),
              icon: const Icon(Icons.pie_chart_outline, size: 18),
              label: const Text('Planner'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withOpacity(0.9),
                  Color.lerp(accent, primary, 0.35)!,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCredit ? 'Credit' : 'Debit',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${isCredit ? '+' : '-'}${currency.format(transaction.amount)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dateFormat.format(transaction.date),
                  style: TextStyle(color: Colors.white.withOpacity(0.85)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _tile(context, 'Description', transaction.description),
          _tile(context, 'Category / subtype', transaction.category),
          _tile(context, 'Account', transaction.account),
          if (planner.hasPlanner) ...[
            const SizedBox(height: 8),
            Text(
              'Money Planner',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      PlannerSections.colorFor(planner.section!).withOpacity(0.15),
                  child: Icon(
                    PlannerSections.iconFor(planner.section!),
                    color: PlannerSections.colorFor(planner.section!),
                  ),
                ),
                title: Text(
                  planner.section!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  planner.subtype == null
                      ? 'Open section setup'
                      : 'Subtype: ${planner.subtype}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openPlannerSection(
                  context,
                  section: planner.section!,
                  subtype: planner.subtype,
                ),
              ),
            ),
          ],
          if (planner.smsBody != null && planner.smsBody!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'SMS',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(planner.smsBody!, style: const TextStyle(height: 1.35)),
            ),
          ] else if (transaction.note != null &&
              transaction.note!.isNotEmpty &&
              !planner.hasPlanner) ...[
            const SizedBox(height: 12),
            _tile(context, 'Note', transaction.note!),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete transaction?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted && transaction.id.isNotEmpty) {
                await context
                    .read<TransactionCubit>()
                    .deleteTransaction(transaction.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Delete transaction',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
