import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/utils/debt_helpers.dart';
import '../../logic/cubits/debt_cubit.dart';
import '../../data/models/debt_model.dart';
import '../widgets/add_debt_modal.dart';
import '../widgets/debt_card.dart';
import '../widgets/latest_debt_banner.dart';
import '../widgets/person_debt_history_sheet.dart';

enum DebtFilter { youOwe, owed, completed }

class DebtScreen extends StatefulWidget {
  const DebtScreen({super.key});

  @override
  State<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends State<DebtScreen> {
  DebtFilter _filter = DebtFilter.youOwe;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          BlocBuilder<DebtCubit, DebtState>(
            builder: (context, state) {
              if (state is DebtLoaded) {
                final activeDebts =
                    state.debts.where((d) => !d.isPaid).toList();
                final totalBorrowed = activeDebts
                    .where((d) => d.type == DebtType.borrow)
                    .fold(0.0, (sum, debt) => sum + debt.remainingAmount);
                final totalLent = activeDebts
                    .where((d) => d.type == DebtType.lend)
                    .fold(0.0, (sum, debt) => sum + debt.remainingAmount);
                final totalOverdue = activeDebts
                    .where((d) => d.isOverdue)
                    .fold(0.0, (sum, debt) => sum + debt.remainingAmount);
                final totalActive = activeDebts.fold(
                    0.0, (sum, debt) => sum + debt.remainingAmount);

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: [
                      Row(
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              context,
                              'Total Overdue',
                              totalOverdue,
                              Colors.deepOrange,
                              Icons.warning_amber_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              context,
                              'Total Active',
                              totalActive,
                              Colors.blue,
                              Icons.pending_actions,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate(delay: 200.ms).fadeIn(duration: 600.ms);
              }
              return const SizedBox();
            },
          ),
          const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildFilterBar(),
              ),
              const SizedBox(height: 8),
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
                        Icon(Icons.error_outline,
                            size: 64, color: Colors.red[300]),
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
                  return _buildDebtsList(context, state.debts);
                }

                return const SizedBox();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDebtModal(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Debt'),
        elevation: 4,
      ),
    );
  }

  Widget _buildFilterBar() {
    return BlocBuilder<DebtCubit, DebtState>(
      builder: (context, state) {
        final debts = state is DebtLoaded ? state.debts : <DebtModel>[];
        final youOweCount =
            debts.where((d) => d.type == DebtType.borrow && !d.isPaid).length;
        final owedCount =
            debts.where((d) => d.type == DebtType.lend && !d.isPaid).length;
        final completedCount = debts.where((d) => d.isPaid).length;

        return Row(
          children: [
            Expanded(
              child: _FilterChip(
                label: 'You Owe',
                count: youOweCount,
                icon: Icons.arrow_downward,
                color: Colors.red,
                isSelected: _filter == DebtFilter.youOwe,
                onTap: () => setState(() => _filter = DebtFilter.youOwe),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FilterChip(
                label: 'Owed',
                count: owedCount,
                icon: Icons.arrow_upward,
                color: Colors.green,
                isSelected: _filter == DebtFilter.owed,
                onTap: () => setState(() => _filter = DebtFilter.owed),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FilterChip(
                label: 'Complete',
                count: completedCount,
                icon: Icons.check_circle_outline,
                color: Colors.blueGrey,
                isSelected: _filter == DebtFilter.completed,
                onTap: () => setState(() => _filter = DebtFilter.completed),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDebtsList(BuildContext context, List<DebtModel> debts) {
    final activeBorrow = sortDebtsByDateDesc(
      debts.where((d) => d.type == DebtType.borrow && !d.isPaid).toList(),
    );
    final activeLend = sortDebtsByDateDesc(
      debts.where((d) => d.type == DebtType.lend && !d.isPaid).toList(),
    );
    final completedDebts = sortDebtsByDateDesc(
      debts.where((d) => d.isPaid).toList(),
    );

    List<DebtModel> filtered;
    String sectionTitle;
    IconData sectionIcon;
    Color sectionColor;

    switch (_filter) {
      case DebtFilter.youOwe:
        filtered = activeBorrow;
        sectionTitle = 'You Owe';
        sectionIcon = Icons.arrow_downward;
        sectionColor = Colors.red;
      case DebtFilter.owed:
        filtered = activeLend;
        sectionTitle = "You're Owed";
        sectionIcon = Icons.arrow_upward;
        sectionColor = Colors.green;
      case DebtFilter.completed:
        filtered = completedDebts;
        sectionTitle = 'Completed';
        sectionIcon = Icons.check_circle_outline;
        sectionColor = Colors.blueGrey;
    }

    if (filtered.isEmpty) {
      return _buildEmptyFilterState(context);
    }

    final latest = latestDebt(filtered);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (latest != null) ...[
            Text(
              'Recently Added',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            LatestDebtBanner(
              debt: latest,
              onTap: () => _openPersonHistory(context, latest.personName, debts),
            ),
            const SizedBox(height: 24),
          ],
          _buildSectionHeader(
            context,
            sectionTitle,
            filtered.length,
            icon: sectionIcon,
            color: sectionColor,
          ),
          const SizedBox(height: 12),
          ...filtered.asMap().entries.map(
                (e) => DebtCard(
                  debt: e.value,
                  onTap: () => _openPersonHistory(
                    context,
                    e.value.personName,
                    debts,
                  ),
                  index: e.key,
                ),
              ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildEmptyFilterState(BuildContext context) {
    final (title, subtitle, icon) = switch (_filter) {
      DebtFilter.youOwe => (
          'Nothing you owe',
          'Active debts you owe will show here',
          Icons.arrow_downward,
        ),
      DebtFilter.owed => (
          'Nothing owed to you',
          'Active debts others owe you will show here',
          Icons.arrow_upward,
        ),
      DebtFilter.completed => (
          'No completed debts',
          'Fully paid transactions will show here',
          Icons.check_circle_outline,
        ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    int count, {
    IconData? icon,
    Color? color,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: color ?? Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  void _openPersonHistory(
    BuildContext context,
    String personName,
    List<DebtModel> allDebts,
  ) {
    PersonDebtHistorySheet.show(
      context,
      personName: personName,
      allDebts: allDebts,
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
    final state = context.read<DebtCubit>().state;
    final savedNames =
        state is DebtLoaded ? savedPersonNames(state.debts) : <String>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddDebtModal(savedPersonNames: savedNames),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? color : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? color : Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.2)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? color : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
