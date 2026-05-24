import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/utils/debt_helpers.dart';
import '../../data/models/debt_model.dart';
import '../../logic/cubits/debt_cubit.dart';
import 'debt_card.dart';

class PersonDebtHistorySheet extends StatelessWidget {
  final String personName;
  final List<DebtModel> allDebts;

  const PersonDebtHistorySheet({
    super.key,
    required this.personName,
    required this.allDebts,
  });

  static void show(
    BuildContext context, {
    required String personName,
    required List<DebtModel> allDebts,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PersonDebtHistorySheet(
        personName: personName,
        allDebts: allDebts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final personDebts = debtsForPerson(allDebts, personName);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    final activeBorrow = personDebts
        .where((d) => d.type == DebtType.borrow && !d.isPaid)
        .fold(0.0, (sum, d) => sum + d.remainingAmount);
    final activeLend = personDebts
        .where((d) => d.type == DebtType.lend && !d.isPaid)
        .fold(0.0, (sum, d) => sum + d.remainingAmount);
    final completed = personDebts.where((d) => d.isPaid).toList();
    final active = personDebts.where((d) => !d.isPaid).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: Text(
                        personName.isNotEmpty
                            ? personName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            personName,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${personDebts.length} transaction${personDebts.length == 1 ? '' : 's'}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (activeBorrow > 0)
                      Expanded(
                        child: _SummaryChip(
                          label: 'You owe',
                          amount: currencyFormat.format(activeBorrow),
                          color: Colors.red,
                        ),
                      ),
                    if (activeBorrow > 0 && activeLend > 0)
                      const SizedBox(width: 8),
                    if (activeLend > 0)
                      Expanded(
                        child: _SummaryChip(
                          label: "You're owed",
                          amount: currencyFormat.format(activeLend),
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (active.isNotEmpty) ...[
                      _sectionTitle(context, 'Active'),
                      ...active.asMap().entries.map(
                            (e) => DebtCard(
                              debt: e.value,
                              index: e.key,
                              onTap: () => _showDebtDetails(context, e.value),
                            ),
                          ),
                    ],
                    if (completed.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _sectionTitle(context, 'Completed'),
                      ...completed.asMap().entries.map(
                            (e) => DebtCard(
                              debt: e.value,
                              index: e.key,
                              onTap: () => _showDebtDetails(context, e.value),
                            ),
                          ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  void _showDebtDetails(BuildContext context, DebtModel debt) {
    showDialog(
      context: context,
      builder: (dialogContext) => _DebtPaymentDialog(debt: debt),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtPaymentDialog extends StatefulWidget {
  final DebtModel debt;

  const _DebtPaymentDialog({required this.debt});

  @override
  State<_DebtPaymentDialog> createState() => _DebtPaymentDialogState();
}

class _DebtPaymentDialogState extends State<_DebtPaymentDialog> {
  final _paymentController = TextEditingController();

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final debt = widget.debt;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              debt.description,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              debt.type == DebtType.borrow ? 'You owe' : "You're owed",
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            _infoRow('Total', currencyFormat.format(debt.amount)),
            _infoRow('Paid', currencyFormat.format(debt.paidAmount),
                valueColor: Colors.green),
            _infoRow('Remaining', currencyFormat.format(debt.remainingAmount),
                valueColor: Colors.orange),
            _infoRow('Date', dateFormat.format(debt.date)),
            if (debt.isPaid)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Chip(
                  label: const Text('Completed'),
                  backgroundColor: Colors.green[50],
                  labelStyle: const TextStyle(color: Colors.green),
                ),
              ),
            if (!debt.isPaid) ...[
              const SizedBox(height: 16),
              const Divider(),
              TextField(
                controller: _paymentController,
                decoration: InputDecoration(
                  labelText: 'Payment Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
                if (!debt.isPaid) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final amount = double.tryParse(_paymentController.text);
                        if (amount != null && amount > 0) {
                          Navigator.pop(context);
                          context
                              .read<DebtCubit>()
                              .updatePayment(debt.id, amount);
                        }
                      },
                      child: const Text('Pay'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
