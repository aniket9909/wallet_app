import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../logic/cubits/wallet_cubit.dart';
import '../widgets/balance_card.dart';
import '../widgets/income_expense_chart.dart';
import '../widgets/monthly_summary_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: BlocBuilder<WalletCubit, WalletState>(
            builder: (context, state) {
              if (state is WalletLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is WalletError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading wallet data',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(state.message),
                    ],
                  ),
                );
              }

              if (state is WalletLoaded) {
                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<WalletCubit>().loadWallet();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        _buildHeader(context),
                        const SizedBox(height: 24),

                        // Balance Card
                        BalanceCard(wallet: state.wallet)
                            .animate()
                            .fadeIn(duration: 600.ms)
                            .slideY(begin: -0.3, end: 0, curve: Curves.easeOut),
                        
                        const SizedBox(height: 24),

                        // Income vs Expense Chart
                        Text(
                          'Income vs Expense',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        IncomeExpenseChart(wallet: state.wallet)
                            .animate(delay: 200.ms)
                            .fadeIn(duration: 600.ms)
                            .slideX(begin: -0.3, end: 0),
                        
                        const SizedBox(height: 24),

                        // Monthly Summary
                        Text(
                          'This Month',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        MonthlySummaryCard(wallet: state.wallet)
                            .animate(delay: 400.ms)
                            .fadeIn(duration: 600.ms)
                            .slideY(begin: 0.3, end: 0),
                        
                        const SizedBox(height: 80), // Bottom padding for navigation
                      ],
                    ),
                  ),
                );
              }

              return const SizedBox();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back!',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Dashboard',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_outlined),
          iconSize: 28,
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}

