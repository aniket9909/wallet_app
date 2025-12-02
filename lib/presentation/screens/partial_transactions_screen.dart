import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../logic/cubits/partial_transaction_cubit.dart';
import '../../logic/cubits/account_cubit.dart';
import '../../logic/cubits/transaction_cubit.dart';
import '../../logic/cubits/sms_cubit.dart';
import '../../data/models/partial_transaction_model.dart';
import '../../data/models/transaction_model_new.dart';
import '../../data/models/sms_message_model.dart';
import '../../data/models/account_model.dart';
import 'package:intl/intl.dart';

class PartialTransactionsScreen extends StatelessWidget {
  const PartialTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partial Transactions & SMS'),
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
          builder: (context, partialState) {
            return BlocBuilder<SmsCubit, SmsState>(
              builder: (context, smsState) {
                    // Show loading if either is loading
                    if (partialState is PartialTransactionLoading || 
                        smsState is SmsLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Show error if partial transactions has error
                    if (partialState is PartialTransactionError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                            const SizedBox(height: 16),
                            Text('Error: ${partialState.message}'),
                          ],
                        ),
                      );
                    }

                    final partials = partialState is PartialTransactionLoaded 
                        ? partialState.partials 
                        : <PartialTransaction>[];
                    final smsMessages = smsState is SmsLoaded 
                        ? smsState.messages 
                        : <SmsMessageModel>[];

                    if (partials.isEmpty && smsMessages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No partial transactions or SMS messages',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    }

                    // Combine and sort by date
                    final allItems = <_CombinedItem>[];
                    
                    // Add partial transactions
                    for (final partial in partials) {
                      allItems.add(_CombinedItem(
                        type: _ItemType.partialTransaction,
                        partialTransaction: partial,
                      ));
                    }
                    
                    // Add SMS messages
                    for (final sms in smsMessages) {
                      allItems.add(_CombinedItem(
                        type: _ItemType.sms,
                        smsMessage: sms,
                      ));
                    }
                    
                    // Sort by date (newest first)
                    allItems.sort((a, b) {
                      final dateA = a.type == _ItemType.partialTransaction
                          ? a.partialTransaction!.date
                          : a.smsMessage!.date;
                      final dateB = b.type == _ItemType.partialTransaction
                          ? b.partialTransaction!.date
                          : b.smsMessage!.date;
                      return dateB.compareTo(dateA);
                    });

                    return RefreshIndicator(
                      onRefresh: () async {
                        context.read<PartialTransactionCubit>().loadPartialTransactions();
                        context.read<SmsCubit>().loadAllSms();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: allItems.length,
                        itemBuilder: (context, index) {
                          final item = allItems[index];
                          if (item.type == _ItemType.partialTransaction) {
                            return _PartialTransactionCard(partial: item.partialTransaction!)
                                .animate()
                                .fadeIn(duration: 300.ms, delay: (index * 50).ms)
                                .slideX(begin: 0.1, end: 0);
                          } else {
                            return _SmsMessageCard(message: item.smsMessage!)
                                .animate()
                                .fadeIn(duration: 300.ms, delay: (index * 50).ms)
                                .slideX(begin: 0.1, end: 0);
                          }
                        },
                      ),
                    );
              },
            );
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

// Helper class to combine partial transactions and SMS messages
enum _ItemType { partialTransaction, sms }

class _CombinedItem {
  final _ItemType type;
  final PartialTransaction? partialTransaction;
  final SmsMessageModel? smsMessage;

  _CombinedItem({
    required this.type,
    this.partialTransaction,
    this.smsMessage,
  });
}

// SMS Message Card Widget
class _SmsMessageCard extends StatelessWidget {
  final SmsMessageModel message;

  const _SmsMessageCard({required this.message});

  void _handleSmsCorrect(BuildContext context, SmsMessageModel message) async {
    if (!message.isCreditDebit || message.amount == null || message.transactionType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot process: SMS is not a valid transaction'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Get accounts to match with SMS
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

    // Find matching account by last digits in SMS body
    AccountModel? matchedAccount;
    for (final account in accountState.accounts) {
      if (account.lastDigits != null && 
          account.lastDigits!.isNotEmpty &&
          message.body.contains(account.lastDigits!)) {
        matchedAccount = account;
        break;
      }
    }

    if (matchedAccount == null) {
      // Use first account as default
      matchedAccount = accountState.accounts.first;
    }

    final transactionType = message.transactionType == 'credit'
        ? TransactionType.credit
        : TransactionType.debit;

    // Create partial transaction
    final partialTransaction = PartialTransaction(
      id: message.id.toString(),
      accountName: matchedAccount.name,
      amount: message.amount!,
      type: transactionType,
      description: 'SMS ${message.transactionType} ${matchedAccount.lastDigits ?? ''}',
      date: message.date,
      smsBody: message.body,
      matchedDigits: matchedAccount.lastDigits ?? '',
    );

    // Create transaction
    final transaction = TransactionModelNew(
      id: '',
      type: transactionType,
      amount: message.amount!,
      description: partialTransaction.description,
      category: 'SMS Import',
      account: matchedAccount.name,
      date: message.date,
      note: message.body,
    );

    try {
      // Add to partial transactions (Firebase)
      await context.read<PartialTransactionCubit>().addPartialTransaction(partialTransaction);
      
      // Add to transactions (Firebase)
      context.read<TransactionCubit>().addTransaction(transaction);
      
      // Mark SMS as correct and sync to Firebase
      await context.read<SmsCubit>().markAsCorrect(message.id!);
      
      // Delete from local storage
      await context.read<SmsCubit>().deleteSms(message.id!);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction created and synced to Firebase!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleSmsWrong(BuildContext context, SmsMessageModel message) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark as Wrong'),
        content: const Text('This SMS will be removed from storage. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<SmsCubit>().markAsWrong(message.id!);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('SMS marked as wrong and removed'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  void _handleSmsDecline(BuildContext context, SmsMessageModel message) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Decline SMS'),
        content: const Text('This SMS will be removed from storage. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<SmsCubit>().markAsDecline(message.id!);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('SMS declined and removed'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');
    final isUnread = !message.isRead;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: isUnread ? 2 : 1,
      color: isUnread ? Colors.blue[50] : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showSmsDetails(context, message),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.12),
                    child: const Icon(
                      Icons.sms,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                message.address.isEmpty ? 'Unknown' : message.address,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isUnread)
                              Container(
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
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(message.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                message.body,
                style: const TextStyle(fontSize: 14),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              if (message.status == SmsStatus.pending)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _handleSmsCorrect(context, message),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Correct'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _handleSmsWrong(context, message),
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Wrong'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _handleSmsDecline(context, message),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Decline'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Chip(
                      label: Text(
                        message.status == SmsStatus.correct
                            ? 'Correct'
                            : message.status == SmsStatus.wrong
                                ? 'Wrong'
                                : 'Declined',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: message.status == SmsStatus.correct
                          ? Colors.green[100]
                          : Colors.red[100],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSmsDetails(BuildContext context, SmsMessageModel message) {
    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.sms, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('SMS Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'From: ${message.address.isEmpty ? 'Unknown' : message.address}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Date: ${dateFormat.format(message.date)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Message:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  message.body,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (!message.isRead)
            TextButton(
              onPressed: () {
                context.read<SmsCubit>().markAsRead(message.id!);
                Navigator.pop(dialogContext);
              },
              child: const Text('Mark as Read'),
            ),
        ],
      ),
    );
  }

}

