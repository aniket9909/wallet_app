import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/utils/budget_cycle.dart';
import '../../data/models/money_plan_model.dart';
import '../../data/models/transaction_model_new.dart';
import '../../data/services/monthly_tracker_engine.dart';
import '../../logic/cubits/money_plan_cubit.dart';
import '../../logic/cubits/partial_transaction_cubit.dart';
import '../../logic/cubits/transaction_cubit.dart';
import '../../logic/cubits/wallet_cubit.dart';
import '../../routes/app_routes.dart';
import '../theme/brand_colors.dart';
import '../widgets/dashboard/home_dashboard_widgets.dart';
import 'expense_tracker_screen.dart';
import 'money_planner/money_planner_screen.dart';
import 'money_planner/monthly_tracker_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _openMonthlyBreakdown() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MonthlyTrackerScreen()),
    );
  }

  void _openPlanner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MoneyPlannerScreen()),
    );
  }

  void _openAllTransactions() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ExpenseTrackerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BrandColors.washGradient),
        child: SafeArea(
          child: BlocBuilder<WalletCubit, WalletState>(
            builder: (context, walletState) {
              if (walletState is WalletLoading || walletState is WalletInitial) {
                return _DashboardLoadingView(
                  message: walletState is WalletInitial
                      ? 'Opening your dashboard...'
                      : 'Syncing wallet data...',
                );
              }

              if (walletState is WalletError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Could not load wallet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(walletState.message, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              }

              if (walletState is! WalletLoaded) {
                return const SizedBox.shrink();
              }

              return BlocBuilder<TransactionCubit, TransactionState>(
                builder: (context, txnState) {
                  final allTxns = txnState is TransactionLoaded
                      ? txnState.transactions
                      : <TransactionModelNew>[];

                  return BlocBuilder<MoneyPlanCubit, MoneyPlanState>(
                    builder: (context, planState) {
                      final plan = planState is MoneyPlanLoaded
                          ? planState.plan
                          : const MoneyPlanModel();
                      final snapshot = planState is MoneyPlanLoaded
                          ? planState.snapshot
                          : null;
                      final planConfigured =
                          planState is MoneyPlanLoaded && plan.setupComplete;
                      final cycleDay = plan.cycleStartDay;
                      final currentCycle =
                          BudgetCycle.containing(DateTime.now(), cycleDay);
                      final months = MonthlyTrackerEngine.availableMonths(
                        allTxns,
                        cycleStartDay: cycleDay,
                      );
                      final aligned =
                          BudgetCycle.fromStart(_selectedMonth, cycleDay).start;
                      final selected = months.any((m) =>
                              m.year == aligned.year &&
                              m.month == aligned.month &&
                              m.day == aligned.day)
                          ? aligned
                          : currentCycle.start;
                      if (!months.any((m) =>
                          m.year == selected.year &&
                          m.month == selected.month &&
                          m.day == selected.day)) {
                        months.insert(0, selected);
                      }

                      final monthTxns = transactionsForMonth(
                        allTxns,
                        selected,
                        cycleStartDay: cycleDay,
                      );
                      final cashFlow = MonthCashFlow.fromTransactions(monthTxns);
                      final tracker = MonthlyTrackerEngine.build(
                        plan: plan,
                        transactions: allTxns,
                        month: selected,
                      );

                      return RefreshIndicator(
                        onRefresh: () async {
                          context.read<WalletCubit>().loadWallet();
                          context.read<TransactionCubit>().loadTransactions();
                          context.read<MoneyPlanCubit>().loadPlan();
                        },
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                          children: [
                            _buildHeader(context),
                            const SizedBox(height: 14),
                            _buildPartialTransactionsBanner(context),
                            DashboardMonthPicker(
                              selectedMonth: selected,
                              months: months,
                              cycleStartDay: cycleDay,
                              onChanged: (m) =>
                                  setState(() => _selectedMonth = m),
                            ).animate().fadeIn(duration: 350.ms),
                            const SizedBox(height: 14),
                            DashboardBalanceHero(
                              totalBalance: walletState.wallet.totalBalance,
                              cashFlow: cashFlow,
                              month: selected,
                              cycleStartDay: cycleDay,
                            ).animate().fadeIn(duration: 400.ms).slideY(
                                  begin: 0.08,
                                  end: 0,
                                  curve: Curves.easeOut,
                                ),
                            const SizedBox(height: 16),
                            if (!planConfigured)
                              DashboardBudgetNotConfiguredCard(
                                onOpenPlanner: _openPlanner,
                              )
                            else ...[
                              DashboardBudgetProgressCard(
                                tracker: tracker,
                                onViewDetails: _openMonthlyBreakdown,
                              ).animate(delay: 80.ms).fadeIn(duration: 400.ms),
                              const SizedBox(height: 16),
                              if (snapshot != null)
                                DashboardPlanAllocationCard(
                                  snapshot: snapshot,
                                  planConfigured: planConfigured,
                                ).animate(delay: 120.ms).fadeIn(duration: 400.ms),
                              const SizedBox(height: 16),
                              DashboardSectionProgressList(tracker: tracker)
                                  .animate(delay: 160.ms)
                                  .fadeIn(duration: 400.ms),
                            ],
                            const SizedBox(height: 20),
                            DashboardMonthTransactions(
                              transactions: monthTxns,
                              onViewAll: _openAllTransactions,
                            ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPartialTransactionsBanner(BuildContext context) {
    return BlocBuilder<PartialTransactionCubit, PartialTransactionState>(
      builder: (context, partialState) {
        if (partialState is! PartialTransactionLoaded) {
          return const SizedBox.shrink();
        }

        final todayUnseen = partialState.partials.where((p) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final pDate = DateTime(p.date.year, p.date.month, p.date.day);
          return pDate.isAtSameMomentAs(today) && !p.seen;
        }).length;

        if (todayUnseen == 0 && partialState.partials.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.partialTransactions);
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: BrandColors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.sms_outlined,
                          color: BrandColors.blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SMS transactions to review',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            todayUnseen > 0
                                ? '$todayUnseen new today · ${partialState.partials.length} pending'
                                : '${partialState.partials.length} pending',
                            style: TextStyle(
                              color: BrandColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Widget _buildHeader(BuildContext context) {
  return Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Arthigo',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BrandColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              'Home',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: BrandColors.navy,
                  ),
            ),
          ],
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_outlined),
          color: BrandColors.navy,
        ),
      ),
    ],
  ).animate().fadeIn(duration: 350.ms);
}

class _DashboardLoadingView extends StatelessWidget {
  final String message;

  const _DashboardLoadingView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const BrandAppIcon(size: 72),
            const SizedBox(height: 24),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                color: BrandColors.blue,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BrandColors.navy,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This only runs once after login. Your home screen opens as soon as wallet data is ready.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BrandColors.muted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
