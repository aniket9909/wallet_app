import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/models/money_plan_model.dart';
import '../../data/models/partial_transaction_model.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkTodayUnseenPartials();
  }

  void _checkTodayUnseenPartials() {
    final partialCubit = context.read<PartialTransactionCubit>();
    final todayUnseen = partialCubit.getTodayUnseenPartials();

    if (todayUnseen.isNotEmpty && mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showSmsReviewSheet(todayUnseen);
        }
      });
    }
  }

  void _showSmsReviewSheet(List<PartialTransaction> partials) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SmsReviewSheet(partials: partials),
    );
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
                return const Center(child: CircularProgressIndicator());
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

                      final months =
                          MonthlyTrackerEngine.availableMonths(allTxns);
                      if (!months.any((m) =>
                          m.year == _selectedMonth.year &&
                          m.month == _selectedMonth.month)) {
                        months.insert(0, _selectedMonth);
                      }

                      final monthTxns =
                          transactionsForMonth(allTxns, _selectedMonth);
                      final cashFlow = MonthCashFlow.fromTransactions(monthTxns);
                      final tracker = MonthlyTrackerEngine.build(
                        plan: plan,
                        transactions: allTxns,
                        month: _selectedMonth,
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
                              selectedMonth: _selectedMonth,
                              months: months,
                              onChanged: (m) =>
                                  setState(() => _selectedMonth = m),
                            ).animate().fadeIn(duration: 350.ms),
                            const SizedBox(height: 14),
                            DashboardBalanceHero(
                              totalBalance: walletState.wallet.totalBalance,
                              cashFlow: cashFlow,
                              month: _selectedMonth,
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

class _SmsReviewSheet extends StatefulWidget {
  final List<PartialTransaction> partials;
  const _SmsReviewSheet({required this.partials});

  @override
  State<_SmsReviewSheet> createState() => _SmsReviewSheetState();
}

class _SmsReviewSheetState extends State<_SmsReviewSheet> {
  late List<PartialTransaction> _pending;

  @override
  void initState() {
    super.initState();
    _pending = List.of(widget.partials);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Detected SMS Transactions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_pending.length}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _pending.isEmpty
                    ? const Center(
                        child: Text('No pending SMS transactions'),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _pending.length,
                        itemBuilder: (context, index) {
                          final p = _pending[index];
                          return _SmsPartialTile(
                            partial: p,
                            onAccept: () => _onAccept(p),
                            onReject: () => _onReject(p),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onAccept(PartialTransaction p) {
    final transaction = TransactionModelNew(
      id: '',
      type: p.type,
      amount: p.amount,
      description: p.description,
      category: 'SMS Import',
      account: p.accountName,
      date: p.date,
      note: p.smsBody,
    );
    context.read<TransactionCubit>().addTransaction(transaction);

    if (p.id.isNotEmpty && !p.id.startsWith('test-')) {
      context.read<PartialTransactionCubit>().markAsSeen(p.id);
      context.read<PartialTransactionCubit>().deletePartialTransaction(p.id);
    }

    setState(() {
      _pending.removeWhere((e) => e.id == p.id);
    });
  }

  void _onReject(PartialTransaction p) {
    if (p.id.isNotEmpty && !p.id.startsWith('test-')) {
      context.read<PartialTransactionCubit>().markAsSeen(p.id);
    }

    setState(() {
      _pending.removeWhere((e) => e.id == p.id);
    });
  }
}

class _SmsPartialTile extends StatelessWidget {
  final PartialTransaction partial;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _SmsPartialTile({
    required this.partial,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isCredit = partial.type == TransactionType.credit;
    final color = isCredit ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(
                    isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    partial.accountName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${isCredit ? '+' : '-'}₹${partial.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              partial.smsBody,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onReject,
                  child: const Text('Incorrect'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onAccept,
                  child: const Text('Correct'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
