import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../logic/cubits/wallet_cubit.dart';
import '../../logic/cubits/transaction_cubit.dart';
import '../../logic/cubits/partial_transaction_cubit.dart';
import '../../data/models/partial_transaction_model.dart';
import '../../data/models/transaction_model_new.dart';
import '../../routes/app_routes.dart';
import '../widgets/balance_card.dart';
import '../widgets/income_expense_chart.dart';
import '../widgets/monthly_summary_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkTodayUnseenPartials();
  }

  void _checkTodayUnseenPartials() {
    final partialCubit = context.read<PartialTransactionCubit>();
    final todayUnseen = partialCubit.getTodayUnseenPartials();
    
    if (todayUnseen.isNotEmpty && mounted) {
      // Show today's unseen partial transactions
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
              if (state is WalletLoading || state is WalletInitial) {
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
                        const SizedBox(height: 16),
                        
                        // Partial Transactions Link
                        BlocBuilder<PartialTransactionCubit, PartialTransactionState>(
                          builder: (context, partialState) {
                            if (partialState is PartialTransactionLoaded) {
                              final todayUnseen = partialState.partials.where((p) {
                                final now = DateTime.now();
                                final today = DateTime(now.year, now.month, now.day);
                                final pDate = DateTime(p.date.year, p.date.month, p.date.day);
                                return pDate.isAtSameMomentAs(today) && !p.seen;
                              }).length;
                              
                              if (todayUnseen > 0 || partialState.partials.isNotEmpty) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.pushNamed(context, AppRoutes.partialTransactions);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Icon(Icons.receipt_long, 
                                            color: Theme.of(context).colorScheme.primary),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Partial Transactions',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                Text(
                                                  todayUnseen > 0
                                                      ? '$todayUnseen new today • ${partialState.partials.length} total'
                                                      : '${partialState.partials.length} pending',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(Icons.chevron_right, 
                                            color: Colors.grey[400]),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }
                            return const SizedBox();
                          },
                        ),
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
    
    // Mark as seen and delete from partial transactions if it has an ID (saved in Firebase)
    if (p.id.isNotEmpty && !p.id.startsWith('test-')) {
      context.read<PartialTransactionCubit>().markAsSeen(p.id);
      context.read<PartialTransactionCubit>().deletePartialTransaction(p.id);
    }
    
    setState(() {
      _pending.removeWhere((e) => e.id == p.id);
    });
  }

  void _onReject(PartialTransaction p) {
    // Mark as seen if it has an ID (saved in Firebase)
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

