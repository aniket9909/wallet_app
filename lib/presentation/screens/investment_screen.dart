import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../logic/cubits/investment_cubit.dart';
import '../../data/models/investment_model.dart';
import '../widgets/add_investment_modal.dart';
import '../widgets/investment_card.dart';

class InvestmentScreen extends StatelessWidget {
  const InvestmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddInvestmentModal(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Investment'),
        elevation: 4,
      ),
      body: BlocBuilder<InvestmentCubit, InvestmentState>(
        builder: (context, state) {
          if (state is InvestmentLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is InvestmentError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    const Text('Error loading investments'),
                    const SizedBox(height: 8),
                    Text(state.message, textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          if (state is InvestmentLoaded) {
            if (state.investments.isEmpty) {
              return _buildEmptyState(context);
            }

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildSummarySection(context, state),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final investment = state.investments[index];
                        return InvestmentCard(
                          investment: investment,
                          onTap: () =>
                              _showInvestmentDetails(context, investment),
                          index: index,
                        );
                      },
                      childCount: state.investments.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 88)),
              ],
            );
          }

          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context, InvestmentLoaded state) {
    final totalInvested =
        state.investments.fold(0.0, (sum, inv) => sum + inv.investedAmount);
    final totalCurrent =
        state.investments.fold(0.0, (sum, inv) => sum + inv.currentValue);
    final totalProfit = totalCurrent - totalInvested;
    final profitPercentage =
        totalInvested > 0 ? (totalProfit / totalInvested * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  context,
                  'Invested',
                  totalInvested,
                  Colors.blue,
                  Icons.trending_up,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  context,
                  'Current Value',
                  totalCurrent,
                  Colors.green,
                  Icons.account_balance_wallet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildProfitCard(context, totalProfit, profitPercentage),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn(duration: 600.ms);
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
      padding: const EdgeInsets.all(12),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              currencyFormat.format(amount),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitCard(BuildContext context, double profit, double percentage) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final isProfit = profit >= 0;
    final color = isProfit ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isProfit ? 'Total Profit' : 'Total Loss',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    currencyFormat.format(profit.abs()),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Return',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isProfit ? Icons.trending_up : Icons.trending_down,
                    color: color,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${percentage.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.trending_up,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 2000.ms),
                const SizedBox(height: 20),
                Text(
                  'No investments yet',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Start tracking your investments!',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _showAddInvestmentModal(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Investment'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddInvestmentModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddInvestmentModal(),
    );
  }

  void _showInvestmentDetails(BuildContext context, InvestmentModel investment) {
    showDialog(
      context: context,
      builder: (context) => _InvestmentDetailsDialog(investment: investment),
    );
  }
}

// Investment Details Dialog
class _InvestmentDetailsDialog extends StatefulWidget {
  final InvestmentModel investment;

  const _InvestmentDetailsDialog({required this.investment});

  @override
  State<_InvestmentDetailsDialog> createState() => _InvestmentDetailsDialogState();
}

class _InvestmentDetailsDialogState extends State<_InvestmentDetailsDialog> {
  final _currentValueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentValueController.text = widget.investment.currentValue.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _currentValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final profit = widget.investment.profit;
    final isProfit = profit >= 0;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isProfit ? Colors.green[50] : Colors.red[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.trending_up,
                  size: 48,
                  color: isProfit ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 16),

              // Investment Name
              Text(
                widget.investment.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _getInvestmentTypeName(widget.investment.type),
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Investment Info
              _buildInfoRow(
                'Invested Amount',
                currencyFormat.format(widget.investment.investedAmount),
              ),
              _buildInfoRow(
                'Current Value',
                currencyFormat.format(widget.investment.currentValue),
                valueColor: Colors.blue,
              ),
              _buildInfoRow(
                isProfit ? 'Profit' : 'Loss',
                currencyFormat.format(profit.abs()),
                valueColor: isProfit ? Colors.green : Colors.red,
              ),
              _buildInfoRow(
                'Return',
                '${widget.investment.profitPercentage.toStringAsFixed(2)}%',
                valueColor: isProfit ? Colors.green : Colors.red,
              ),
              if (widget.investment.interestRate != null)
                _buildInfoRow(
                  'Interest Rate',
                  '${widget.investment.interestRate!.toStringAsFixed(2)}%',
                ),
              _buildInfoRow(
                'Purchase Date',
                dateFormat.format(widget.investment.purchaseDate),
              ),
              if (widget.investment.maturityDate != null) ...[
                _buildInfoRow(
                  'Maturity Date',
                  dateFormat.format(widget.investment.maturityDate!),
                ),
                if (widget.investment.daysToMaturity != null)
                  _buildInfoRow(
                    'Days to Maturity',
                    '${widget.investment.daysToMaturity} days',
                    valueColor: widget.investment.daysToMaturity! < 30
                        ? Colors.orange
                        : null,
                  ),
              ],

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Update Current Value
              const Text(
                'Update Current Value',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _currentValueController,
                decoration: InputDecoration(
                  labelText: 'Current Value',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

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
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _updateInvestment,
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
              ),
            ],
          ),
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

  String _getInvestmentTypeName(InvestmentType type) {
    switch (type) {
      case InvestmentType.mutualFund:
        return 'Mutual Fund';
      case InvestmentType.fixedDeposit:
        return 'Fixed Deposit';
      case InvestmentType.stocks:
        return 'Stocks';
      case InvestmentType.gold:
        return 'Gold';
      case InvestmentType.bonds:
        return 'Bonds';
      case InvestmentType.other:
        return 'Other';
    }
  }

  void _updateInvestment() {
    final currentValue = double.tryParse(_currentValueController.text);
    if (currentValue != null && currentValue >= 0) {
      final updatedInvestment = widget.investment.copyWith(
        currentValue: currentValue,
      );

      // Close dialog first
      Navigator.pop(context);

      // Update investment (stream will update UI automatically)
      context.read<InvestmentCubit>().updateInvestment(updatedInvestment);

      // Show success message after a brief delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Investment updated successfully!'),
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

