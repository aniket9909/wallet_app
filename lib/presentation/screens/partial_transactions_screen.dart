import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../logic/cubits/partial_transaction_cubit.dart';
import '../../logic/cubits/account_cubit.dart';
import '../../logic/cubits/transaction_cubit.dart';
import '../../data/models/partial_transaction_model.dart';
import '../../data/models/transaction_model_new.dart';
import 'package:intl/intl.dart';

class PartialTransactionsScreen extends StatelessWidget {
  const PartialTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partial Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddPartialDialog(context),
          ),
        ],
      ),
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
        child: BlocBuilder<PartialTransactionCubit, PartialTransactionState>(
          builder: (context, state) {
            if (state is PartialTransactionLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is PartialTransactionError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text('Error: ${state.message}'),
                  ],
                ),
              );
            }

            if (state is PartialTransactionLoaded) {
              if (state.partials.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No partial transactions',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<PartialTransactionCubit>().loadPartialTransactions();
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.partials.length,
                  itemBuilder: (context, index) {
                    final partial = state.partials[index];
                    return _PartialTransactionCard(partial: partial)
                        .animate()
                        .fadeIn(duration: 300.ms, delay: (index * 50).ms)
                        .slideX(begin: 0.1, end: 0);
                  },
                ),
              );
            }

            return const SizedBox();
          },
        ),
      ),
    );
  }

  void _showAddPartialDialog(BuildContext context) {
    final accountState = context.read<AccountCubit>().state;
    if (accountState is! AccountLoaded || accountState.accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one account first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final smsBodyController = TextEditingController();
    final digitsController = TextEditingController();
    TransactionType selectedType = TransactionType.debit;
    String? selectedAccount;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Partial Transaction'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Account'),
                    items: accountState.accounts.map((acc) {
                      return DropdownMenuItem(
                        value: acc.name,
                        child: Text(acc.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedAccount = value;
                        final acc = accountState.accounts
                            .firstWhere((a) => a.name == value);
                        digitsController.text = acc.lastDigits ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TransactionType>(
                    decoration: const InputDecoration(labelText: 'Type'),
                    value: selectedType,
                    items: [
                      DropdownMenuItem(
                        value: TransactionType.credit,
                        child: const Text('Credit'),
                      ),
                      DropdownMenuItem(
                        value: TransactionType.debit,
                        child: const Text('Debit'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: digitsController,
                    decoration: const InputDecoration(labelText: 'Last Digits'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: smsBodyController,
                    decoration: const InputDecoration(labelText: 'SMS Body'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (selectedAccount == null ||
                      amountController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill all required fields'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final amount = double.tryParse(amountController.text);
                  if (amount == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid amount'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final partial = PartialTransaction(
                    id: '',
                    accountName: selectedAccount!,
                    amount: amount,
                    type: selectedType,
                    description: descriptionController.text.isEmpty
                        ? 'SMS ${selectedType == TransactionType.credit ? 'credit' : 'debit'} ${digitsController.text}'
                        : descriptionController.text,
                    date: DateTime.now(),
                    smsBody: smsBodyController.text.isEmpty
                        ? 'Test SMS transaction'
                        : smsBodyController.text,
                    matchedDigits: digitsController.text,
                  );

                  context.read<PartialTransactionCubit>().addPartialTransaction(partial);
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Partial transaction added'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PartialTransactionCard extends StatelessWidget {
  final PartialTransaction partial;

  const _PartialTransactionCard({required this.partial});

  @override
  Widget build(BuildContext context) {
    final isCredit = partial.type == TransactionType.credit;
    final color = isCredit ? Colors.green : Colors.red;
    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showEditDialog(context, partial),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partial.accountName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(partial.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isCredit ? '+' : '-'}₹${partial.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!partial.seen)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'New',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                partial.description,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  partial.smsBody,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _showDeleteConfirmation(context, partial),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _acceptTransaction(context, partial),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, PartialTransaction partial) {
    final accountState = context.read<AccountCubit>().state;
    if (accountState is! AccountLoaded) return;

    final amountController = TextEditingController(text: partial.amount.toString());
    final descriptionController = TextEditingController(text: partial.description);
    final smsBodyController = TextEditingController(text: partial.smsBody);
    final digitsController = TextEditingController(text: partial.matchedDigits);
    TransactionType selectedType = partial.type;
    String? selectedAccount = partial.accountName;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Partial Transaction'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Account'),
                    value: selectedAccount,
                    items: accountState.accounts.map((acc) {
                      return DropdownMenuItem(
                        value: acc.name,
                        child: Text(acc.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedAccount = value;
                        final acc = accountState.accounts
                            .firstWhere((a) => a.name == value);
                        digitsController.text = acc.lastDigits ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TransactionType>(
                    decoration: const InputDecoration(labelText: 'Type'),
                    value: selectedType,
                    items: [
                      DropdownMenuItem(
                        value: TransactionType.credit,
                        child: const Text('Credit'),
                      ),
                      DropdownMenuItem(
                        value: TransactionType.debit,
                        child: const Text('Debit'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: digitsController,
                    decoration: const InputDecoration(labelText: 'Last Digits'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: smsBodyController,
                    decoration: const InputDecoration(labelText: 'SMS Body'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || selectedAccount == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid input'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final updated = partial.copyWith(
                    accountName: selectedAccount,
                    amount: amount,
                    type: selectedType,
                    description: descriptionController.text,
                    smsBody: smsBodyController.text,
                    matchedDigits: digitsController.text,
                  );

                  context.read<PartialTransactionCubit>().updatePartialTransaction(updated);
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Partial transaction updated'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, PartialTransaction partial) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Partial Transaction'),
        content: const Text('Are you sure you want to delete this partial transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<PartialTransactionCubit>().deletePartialTransaction(partial.id);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Partial transaction deleted'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _acceptTransaction(BuildContext context, PartialTransaction partial) {
    final transaction = TransactionModelNew(
      id: '',
      type: partial.type,
      amount: partial.amount,
      description: partial.description,
      category: 'SMS Import',
      account: partial.accountName,
      date: partial.date,
      note: partial.smsBody,
    );
    context.read<TransactionCubit>().addTransaction(transaction);
    context.read<PartialTransactionCubit>().markAsSeen(partial.id);
    context.read<PartialTransactionCubit>().deletePartialTransaction(partial.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transaction saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

