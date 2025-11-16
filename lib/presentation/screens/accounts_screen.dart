import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../logic/cubits/account_cubit.dart';
import '../../data/models/account_model.dart';
import '../widgets/add_transaction_modal.dart';
import '../widgets/add_account_modal.dart';
import 'account_transactions_screen.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

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
                child: Row(
                  children: [
                    Text(
                      'Accounts',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        _showAddAccountModal(context);
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      iconSize: 28,
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms),
              ),

              // Accounts List
              Expanded(
                child: BlocBuilder<AccountCubit, AccountState>(
                  builder: (context, state) {
                    if (state is AccountLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state is AccountError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                            const SizedBox(height: 16),
                            Text('Error loading accounts'),
                            const SizedBox(height: 8),
                            Text(state.message),
                          ],
                        ),
                      );
                    }

                    if (state is AccountLoaded) {
                      if (state.accounts.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 80,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No accounts yet',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Colors.grey,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add your first account to get started',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: state.accounts.length,
                        itemBuilder: (context, index) {
                          final account = state.accounts[index];
                          return _buildAccountCard(context, account, index);
                        },
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddTransactionModal(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('Transaction'),
        elevation: 4,
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, AccountModel account, int index) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AccountTransactionsScreen(accountName: account.name),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Account Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _getGradientColors(account.type),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getAccountIcon(account.type),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Account Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        account.type,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Balance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(account.balance),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: account.balance >= 0
                            ? Colors.green[50]
                            : Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        account.balance >= 0 ? 'Active' : 'Low',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: account.balance >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 100 * index))
        .fadeIn(duration: 400.ms)
        .slideX(begin: -0.2, end: 0);
  }

  IconData _getAccountIcon(String type) {
    switch (type.toLowerCase()) {
      case 'bank':
        return Icons.account_balance;
      case 'cash':
        return Icons.money;
      case 'upi':
        return Icons.qr_code_2;
      case 'credit card':
        return Icons.credit_card;
      default:
        return Icons.account_balance_wallet;
    }
  }

  List<Color> _getGradientColors(String type) {
    switch (type.toLowerCase()) {
      case 'bank':
        return [Colors.blue, Colors.blue.shade700];
      case 'cash':
        return [Colors.green, Colors.green.shade700];
      case 'upi':
        return [Colors.purple, Colors.purple.shade700];
      case 'credit card':
        return [Colors.orange, Colors.orange.shade700];
      default:
        return [Colors.indigo, Colors.indigo.shade700];
    }
  }

  void _showAddTransactionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddTransactionModal(),
    );
  }

  void _showAddAccountModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddAccountModal(),
    );
  }
}

