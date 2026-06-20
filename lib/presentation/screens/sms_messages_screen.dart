import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../logic/cubits/sms_cubit.dart';
import '../../data/models/sms_message_model.dart';
import '../widgets/sms_sync_sheet.dart';

enum SmsListFilter { all, debit, credit }

class SmsMessagesScreen extends StatefulWidget {
  const SmsMessagesScreen({super.key});

  @override
  State<SmsMessagesScreen> createState() => _SmsMessagesScreenState();
}

class _SmsMessagesScreenState extends State<SmsMessagesScreen> {
  SmsListFilter _filter = SmsListFilter.all;

  @override
  void initState() {
    super.initState();
    context.read<SmsCubit>().loadAllSms();
  }

  List<SmsMessageModel> _filtered(List<SmsMessageModel> messages) {
    switch (_filter) {
      case SmsListFilter.all:
        return messages;
      case SmsListFilter.debit:
        return messages
            .where((m) => m.transactionType == 'debit')
            .toList();
      case SmsListFilter.credit:
        return messages
            .where((m) => m.transactionType == 'credit')
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank SMS Alerts'),
        actions: [
          BlocBuilder<SmsCubit, SmsState>(
            builder: (context, state) {
              if (state is SmsLoaded && state.unreadCount > 0) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text('${state.unreadCount} new'),
                      backgroundColor: Colors.blue,
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Scan inbox',
            onPressed: () => _scanInbox(context),
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete All'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'delete_all') {
                _showDeleteAllConfirmation(context);
              }
            },
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _FilterChipButton(
                    label: 'All',
                    selected: _filter == SmsListFilter.all,
                    onTap: () => setState(() => _filter = SmsListFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterChipButton(
                    label: 'Debit',
                    selected: _filter == SmsListFilter.debit,
                    color: Colors.red,
                    onTap: () => setState(() => _filter = SmsListFilter.debit),
                  ),
                  const SizedBox(width: 8),
                  _FilterChipButton(
                    label: 'Credit',
                    selected: _filter == SmsListFilter.credit,
                    color: Colors.green,
                    onTap: () => setState(() => _filter = SmsListFilter.credit),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<SmsCubit, SmsState>(
                builder: (context, state) {
                  if (state is SmsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is SmsError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 64, color: Colors.red[300]),
                          const SizedBox(height: 16),
                          Text('Error: ${state.message}'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () =>
                                context.read<SmsCubit>().loadAllSms(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (state is SmsLoaded) {
                    final messages = _filtered(state.messages);

                    if (messages.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.sms_outlined,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No ${_filter == SmsListFilter.all ? 'debit/credit' : _filter.name} SMS',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap sync or enable SMS in Settings, then scan inbox',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => _scanInbox(context),
                                icon: const Icon(Icons.sync),
                                label: const Text('Scan SMS Inbox'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        await context.read<SmsCubit>().scanInbox();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return _SmsMessageCard(
                            message: message,
                            onTap: () => _showMessageDetails(context, message),
                            onSync: message.status == SmsStatus.correct
                                ? null
                                : () => SmsSyncSheet.show(context, message),
                            onDelete: () =>
                                _showDeleteConfirmation(context, message),
                            onMarkRead: message.isRead
                                ? null
                                : () => context
                                    .read<SmsCubit>()
                                    .markAsRead(message.id!),
                          )
                              .animate()
                              .fadeIn(
                                  duration: 300.ms, delay: (index * 50).ms)
                              .slideX(begin: 0.1, end: 0);
                        },
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
    );
  }

  Future<void> _scanInbox(BuildContext context) async {
    final result = await context.read<SmsCubit>().scanInbox();
    if (!context.mounted) return;
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${result.imported} debit/credit SMS (${result.skipped} skipped)',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showMessageDetails(BuildContext context, SmsMessageModel message) {
    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');
    final isCredit = message.transactionType == 'credit';
    final typeColor = isCredit ? Colors.green : Colors.red;
    final isSynced = message.status == SmsStatus.correct;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.sms, color: typeColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isCredit ? 'Credit SMS' : 'Debit SMS',
                style: TextStyle(color: typeColor, fontSize: 18),
              ),
            ),
            if (isSynced)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Synced',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.amount != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${isCredit ? '+' : '-'}₹${message.amount!.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: typeColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              _DetailRow(
                icon: Icons.phone,
                label: 'From',
                value: message.address.isEmpty ? 'Unknown' : message.address,
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.access_time,
                label: 'Date',
                value: dateFormat.format(message.date),
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
          if (!isSynced)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                SmsSyncSheet.show(context, message);
              },
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Sync to Wallet'),
            ),
          if (!message.isRead && !isSynced)
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

  void _showDeleteConfirmation(BuildContext context, SmsMessageModel message) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete SMS'),
        content: const Text('Are you sure you want to delete this SMS?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<SmsCubit>().deleteSms(message.id!);
              Navigator.pop(dialogContext);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAllConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete All SMS'),
        content: const Text(
          'Delete all stored debit/credit SMS? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<SmsCubit>().deleteAllSms();
              Navigator.pop(dialogContext);
            },
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? c.withOpacity(0.15) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? c : Colors.grey[300]!,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? c : Colors.grey[700],
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmsMessageCard extends StatelessWidget {
  final SmsMessageModel message;
  final VoidCallback onTap;
  final VoidCallback? onSync;
  final VoidCallback onDelete;
  final VoidCallback? onMarkRead;

  const _SmsMessageCard({
    required this.message,
    required this.onTap,
    this.onSync,
    required this.onDelete,
    this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');
    final isUnread = !message.isRead;
    final isSynced = message.status == SmsStatus.correct;
    final isCredit = message.transactionType == 'credit';
    final typeColor = isCredit ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: isUnread ? 2 : 1,
      color: isUnread ? Colors.blue[50] : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: typeColor.withOpacity(0.12),
                    child: Icon(
                      isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                      color: typeColor,
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isCredit ? 'CREDIT' : 'DEBIT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: typeColor,
                                ),
                              ),
                            ),
                            if (isSynced) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Synced',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ] else if (isUnread) ...[
                              const SizedBox(width: 8),
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
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message.address.isEmpty ? 'Bank' : message.address,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isUnread ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
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
                  if (message.amount != null)
                    Text(
                      '${isCredit ? '+' : '-'}₹${message.amount!.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onSync != null)
                    ElevatedButton.icon(
                      onPressed: onSync,
                      icon: const Icon(Icons.sync, size: 16),
                      label: const Text('Sync'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  if (onMarkRead != null)
                    TextButton.icon(
                      onPressed: onMarkRead,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Mark Read'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 14)),
        ),
      ],
    );
  }
}
