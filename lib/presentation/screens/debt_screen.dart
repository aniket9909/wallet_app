import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../logic/cubits/debt_cubit.dart';
import '../../data/models/debt_model.dart';
import '../widgets/add_debt_modal.dart';
import '../widgets/debt_card.dart';

class DebtScreen extends StatelessWidget {
  const DebtScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
              Theme.of(context).colorScheme.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'Debt Management',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        _showAddDebtModal(context);
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      iconSize: 28,
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms),
              ),

              // Summary Cards
              BlocBuilder<DebtCubit, DebtState>(
                builder: (context, state) {
                  if (state is DebtLoaded) {
                    final totalBorrowed = state.debts
                        .where((d) => d.type == DebtType.borrow && !d.isPaid)
                        .fold(0.0, (sum, debt) => sum + debt.remainingAmount);
                    final totalLent = state.debts
                        .where((d) => d.type == DebtType.lend && !d.isPaid)
                        .fold(0.0, (sum, debt) => sum + debt.remainingAmount);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              context,
                              'You Owe',
                              totalBorrowed,
                              Colors.red,
                              Icons.arrow_downward,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              context,
                              "You're Owed",
                              totalLent,
                              Colors.green,
                              Icons.arrow_upward,
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 200.ms).fadeIn(duration: 600.ms);
                  }
                  return const SizedBox();
                },
              ),

              const SizedBox(height: 16),

              // Debts List
              Expanded(
                child: BlocBuilder<DebtCubit, DebtState>(
                  builder: (context, state) {
                    if (state is DebtLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state is DebtError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                            const SizedBox(height: 16),
                            const Text('Error loading debts'),
                            const SizedBox(height: 8),
                            Text(state.message),
                          ],
                        ),
                      );
                    }

                    if (state is DebtLoaded) {
                      if (state.debts.isEmpty) {
                        return _buildEmptyState(context);
                      }

                      // Separate borrow and lend debts
                      final borrowDebts = state.debts
                          .where((d) => d.type == DebtType.borrow)
                          .toList();
                      final lendDebts = state.debts
                          .where((d) => d.type == DebtType.lend)
                          .toList();

                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (borrowDebts.isNotEmpty) ...[
                              Text(
                                'You Owe',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              ...borrowDebts.map((debt) => DebtCard(
                                    debt: debt,
                                    onTap: () => _showDebtDetails(context, debt),
                                    index: borrowDebts.indexOf(debt),
                                  )),
                              const SizedBox(height: 24),
                            ],
                            if (lendDebts.isNotEmpty) ...[
                              Text(
                                'You\'re Owed',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              ...lendDebts.map((debt) => DebtCard(
                                    debt: debt,
                                    onTap: () => _showDebtDetails(context, debt),
                                    index: lendDebts.indexOf(debt),
                                  )),
                            ],
                            const SizedBox(height: 80),
                          ],
                        ),
                      );
                    }

                    return const SizedBox();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddDebtModal(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Debt'),
        elevation: 4,
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    double amount,
    Color color,
    IconData icon,
  ) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  amount > 0 ? 'Active' : 'Clear',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currencyFormat.format(amount),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 2000.ms),
          const SizedBox(height: 24),
          Text(
            'No debts yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track money you owe or are owed!',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddDebtModal(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Debt'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDebtModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddDebtModal(),
    );
  }

  void _showDebtDetails(BuildContext context, DebtModel debt) {
    showDialog(
      context: context,
      builder: (context) => _DebtDetailsDialog(debt: debt),
    );
  }
}

// Debt Details Dialog
class _DebtDetailsDialog extends StatefulWidget {
  final DebtModel debt;

  const _DebtDetailsDialog({required this.debt});

  @override
  State<_DebtDetailsDialog> createState() => _DebtDetailsDialogState();
}

class _DebtDetailsDialogState extends State<_DebtDetailsDialog> {
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

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.debt.type == DebtType.borrow
                    ? Colors.red[50]
                    : Colors.green[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.debt.type == DebtType.borrow
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
                size: 48,
                color: widget.debt.type == DebtType.borrow
                    ? Colors.red
                    : Colors.green,
              ),
            ),
            const SizedBox(height: 16),

            // Debt Info
            Text(
              widget.debt.personName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.debt.description,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Amount Info
            _buildInfoRow(
              'Total Amount',
              currencyFormat.format(widget.debt.amount),
            ),
            _buildInfoRow(
              'Paid Amount',
              currencyFormat.format(widget.debt.paidAmount),
              valueColor: Colors.green,
            ),
            _buildInfoRow(
              'Remaining',
              currencyFormat.format(widget.debt.remainingAmount),
              valueColor: Colors.orange,
            ),
            _buildInfoRow(
              'Progress',
              '${widget.debt.progressPercentage.toStringAsFixed(1)}%',
            ),
            if (widget.debt.dueDate != null)
              _buildInfoRow(
                'Due Date',
                dateFormat.format(widget.debt.dueDate!),
                valueColor: widget.debt.isOverdue ? Colors.red : null,
              ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Update Payment
            if (!widget.debt.isPaid) ...[
              const Text(
                'Add Payment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 16),
            ],

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ),
                if (!widget.debt.isPaid) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _updatePayment,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Update'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ).animate().scale(duration: 300.ms, curve: Curves.easeOut);
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  void _updatePayment() {
    final amount = double.tryParse(_paymentController.text);
    if (amount != null && amount > 0) {
      // Close dialog first
      Navigator.pop(context);

      // Update payment (stream will update UI automatically)
      context.read<DebtCubit>().updatePayment(widget.debt.id, amount);

      // Show success message after a brief delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Payment updated successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      });
    }
  }
}

