import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../logic/cubits/savings_goal_cubit.dart';
import '../../data/models/savings_goal_model.dart';
import '../widgets/add_goal_modal.dart';
import '../widgets/goal_progress_card.dart';

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          BlocBuilder<SavingsGoalCubit, SavingsGoalState>(
            builder: (context, state) {
              if (state is SavingsGoalLoaded && state.goals.isNotEmpty) {
                final activeGoals =
                    state.goals.where((g) => !g.isCompleted).toList();
                final totalSaved = activeGoals.fold(
                    0.0, (sum, g) => sum + g.savedSoFar);
                final totalPending = activeGoals.fold(
                    0.0, (sum, g) => sum + g.remainingAmount);

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          context,
                          'Total Saved',
                          totalSaved,
                          Colors.green,
                          Icons.savings,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          context,
                          'Total Pending',
                          totalPending,
                          Colors.orange,
                          Icons.pending_actions,
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 200.ms).fadeIn(duration: 600.ms);
              }
              return const SizedBox();
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: BlocBuilder<SavingsGoalCubit, SavingsGoalState>(
              builder: (context, state) {
                if (state is SavingsGoalLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is SavingsGoalError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        const Text('Error loading goals'),
                        const SizedBox(height: 8),
                        Text(state.message),
                      ],
                    ),
                  );
                }

                if (state is SavingsGoalLoaded) {
                  if (state.goals.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: state.goals.length,
                    itemBuilder: (context, index) {
                      final goal = state.goals[index];
                      return GoalProgressCard(
                        goal: goal,
                        onTap: () => _showGoalDetails(context, goal),
                        index: index,
                      );
                    },
                  );
                }

                return const SizedBox();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddGoalModal(context);
        },
        icon: const Icon(Icons.flag),
        label: const Text('New Goal'),
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
              Icons.savings_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 2000.ms),
          const SizedBox(height: 24),
          Text(
            'No savings goals yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first goal to start saving!',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddGoalModal(context),
            icon: const Icon(Icons.add),
            label: const Text('Create Goal'),
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

  void _showAddGoalModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddGoalModal(),
    );
  }

  void _showGoalDetails(BuildContext context, SavingsGoalModel goal) {
    showDialog(
      context: context,
      builder: (context) => _GoalDetailsDialog(goal: goal),
    );
  }
}

class _GoalDetailsDialog extends StatefulWidget {
  final SavingsGoalModel goal;

  const _GoalDetailsDialog({required this.goal});

  @override
  State<_GoalDetailsDialog> createState() => _GoalDetailsDialogState();
}

class _GoalDetailsDialogState extends State<_GoalDetailsDialog> {
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

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
                color: widget.goal.isCompleted ? Colors.green[50] : Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.goal.isCompleted ? Icons.check_circle : Icons.flag,
                size: 48,
                color: widget.goal.isCompleted ? Colors.green : Colors.blue,
              ),
            ),
            const SizedBox(height: 16),

            // Goal Name
            Text(
              widget.goal.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Progress Info
            _buildInfoRow(
              'Target Amount',
              currencyFormat.format(widget.goal.targetAmount),
            ),
            _buildInfoRow(
              'Saved So Far',
              currencyFormat.format(widget.goal.savedSoFar),
              valueColor: Colors.green,
            ),
            _buildInfoRow(
              'Remaining',
              currencyFormat.format(widget.goal.remainingAmount),
              valueColor: Colors.orange,
            ),
            _buildInfoRow(
              'Required per Month',
              currencyFormat.format(widget.goal.savingsPerMonth),
            ),
            _buildInfoRow(
              'Time Period',
              '${widget.goal.timePeriodMonths} months',
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Update Progress
            if (!widget.goal.isCompleted) ...[
              const Text(
                'Add Savings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount',
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
                if (!widget.goal.isCompleted) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _updateProgress,
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

  void _updateProgress() {
    final amount = double.tryParse(_amountController.text);
    if (amount != null && amount > 0) {
      // Close dialog first
      Navigator.pop(context);

      // Update progress (stream will update UI automatically)
      context.read<SavingsGoalCubit>().updateProgress(widget.goal.id, amount);

      // Show success message after a brief delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Progress updated successfully!'),
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

