import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../data/models/investment_model.dart';

class InvestmentCard extends StatelessWidget {
  final InvestmentModel investment;
  final VoidCallback onTap;
  final int index;

  const InvestmentCard({
    super.key,
    required this.investment,
    required this.onTap,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final profit = investment.profit;
    final isProfit = profit >= 0;
    final profitColor = isProfit ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _getGradientColors(investment.type),
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _getInvestmentIcon(investment.type),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Investment Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            investment.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getInvestmentTypeName(investment.type),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: profitColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isProfit ? Icons.trending_up : Icons.trending_down,
                            size: 14,
                            color: profitColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${investment.profitPercentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: profitColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Amount Info
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invested',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currencyFormat.format(investment.investedAmount),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey[200],
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Current Value',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currencyFormat.format(investment.currentValue),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: profitColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey[200],
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            isProfit ? 'Profit' : 'Loss',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currencyFormat.format(profit.abs()),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: profitColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Additional Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Purchased: ${dateFormat.format(investment.purchaseDate)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      if (investment.maturityDate != null)
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 16,
                              color: investment.isMatured
                                  ? Colors.green
                                  : Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              investment.isMatured
                                  ? 'Matured'
                                  : '${investment.daysToMaturity} days left',
                              style: TextStyle(
                                fontSize: 12,
                                color: investment.isMatured
                                    ? Colors.green
                                    : Colors.grey[600],
                                fontWeight: investment.isMatured
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 100 * index))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.2, end: 0);
  }

  IconData _getInvestmentIcon(InvestmentType type) {
    switch (type) {
      case InvestmentType.mutualFund:
        return Icons.trending_up;
      case InvestmentType.fixedDeposit:
        return Icons.account_balance;
      case InvestmentType.stocks:
        return Icons.show_chart;
      case InvestmentType.gold:
        return Icons.diamond;
      case InvestmentType.bonds:
        return Icons.receipt;
      case InvestmentType.other:
        return Icons.savings;
    }
  }

  List<Color> _getGradientColors(InvestmentType type) {
    switch (type) {
      case InvestmentType.mutualFund:
        return [Colors.blue, Colors.blue.shade700];
      case InvestmentType.fixedDeposit:
        return [Colors.green, Colors.green.shade700];
      case InvestmentType.stocks:
        return [Colors.orange, Colors.orange.shade700];
      case InvestmentType.gold:
        return [Colors.amber, Colors.amber.shade700];
      case InvestmentType.bonds:
        return [Colors.purple, Colors.purple.shade700];
      case InvestmentType.other:
        return [Colors.indigo, Colors.indigo.shade700];
    }
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
}

