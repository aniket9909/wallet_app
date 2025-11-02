import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../logic/cubits/transaction_cubit.dart';
import '../../data/models/transaction_model_new.dart';
import '../widgets/transaction_list_item.dart';
import '../widgets/category_chart.dart';

class ExpenseTrackerScreen extends StatefulWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'This Month', 'This Week', 'Today'];

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expense Tracker',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filters.map((filter) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: _selectedFilter == filter,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedFilter = filter;
                                });
                              },
                              selectedColor: Theme.of(context).colorScheme.primary,
                              labelStyle: TextStyle(
                                color: _selectedFilter == filter
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: _selectedFilter == filter
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms),
              ),

              // Content
              Expanded(
                child: BlocBuilder<TransactionCubit, TransactionState>(
                  builder: (context, state) {
                    if (state is TransactionLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state is TransactionError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 64, color: Colors.red[300]),
                            const SizedBox(height: 16),
                            const Text('Error loading transactions'),
                            const SizedBox(height: 8),
                            Text(state.message),
                          ],
                        ),
                      );
                    }

                    if (state is TransactionLoaded) {
                      final filteredTransactions =
                          _filterTransactions(state.transactions);

                      if (filteredTransactions.isEmpty) {
                        return _buildEmptyState(context);
                      }

                      final categoryExpenses = _calculateCategoryExpenses(
                          filteredTransactions);

                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            // Category Chart
                            if (categoryExpenses.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: CategoryChart(
                                  categoryExpenses: categoryExpenses,
                                ).animate(delay: 200.ms).fadeIn(duration: 600.ms),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Transactions List
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Recent Transactions',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: filteredTransactions.length,
                                    itemBuilder: (context, index) {
                                      return TransactionListItem(
                                        transaction: filteredTransactions[index],
                                        index: index,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
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
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start tracking your expenses',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  List<TransactionModelNew> _filterTransactions(
      List<TransactionModelNew> transactions) {
    final now = DateTime.now();
    
    switch (_selectedFilter) {
      case 'Today':
        return transactions.where((t) {
          return t.date.year == now.year &&
              t.date.month == now.month &&
              t.date.day == now.day;
        }).toList();
      case 'This Week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return transactions.where((t) {
          return t.date.isAfter(startOfWeek) && t.date.isBefore(now);
        }).toList();
      case 'This Month':
        return transactions.where((t) {
          return t.date.year == now.year && t.date.month == now.month;
        }).toList();
      default:
        return transactions;
    }
  }

  Map<String, double> _calculateCategoryExpenses(
      List<TransactionModelNew> transactions) {
    final Map<String, double> categoryExpenses = {};

    for (var transaction in transactions) {
      if (transaction.type == TransactionType.debit) {
        categoryExpenses[transaction.category] =
            (categoryExpenses[transaction.category] ?? 0) + transaction.amount;
      }
    }

    return categoryExpenses;
  }
}

