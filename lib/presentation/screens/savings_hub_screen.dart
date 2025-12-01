import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'savings_screen.dart';
import 'investment_screen.dart';
import 'debt_screen.dart';

class SavingsHubScreen extends StatelessWidget {
  const SavingsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
                // Header + Tabs
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'Savings',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TabBar(
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor: Colors.grey[600],
                      indicator: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tabs: const [
                        Tab(icon: Icon(Icons.savings), text: 'Savings'),
                        Tab(icon: Icon(Icons.trending_up), text: 'Investment'),
                        Tab(icon: Icon(Icons.account_balance), text: 'Debt'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Content
                const Expanded(
                  child: TabBarView(
                    children: [
                      SavingsScreen(),
                      InvestmentScreen(),
                      DebtScreen(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


