import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/cubits/sms_cubit.dart';
import '../../data/models/sms_message_model.dart';
import '../screens/sms_messages_screen.dart';

class SmsSetupSection extends StatefulWidget {
  const SmsSetupSection({super.key});

  @override
  State<SmsSetupSection> createState() => _SmsSetupSectionState();
}

class _SmsSetupSectionState extends State<SmsSetupSection> {
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    context.read<SmsCubit>().loadAllSms();
  }

  Future<void> _scanInbox() async {
    setState(() => _isScanning = true);
    final result = await context.read<SmsCubit>().scanInbox();
    setState(() => _isScanning = false);

    if (!mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to scan SMS. Check permissions.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Scanned ${result.scanned} messages — ${result.imported} debit/credit saved',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _requestPermission() async {
    final granted = await context.read<SmsCubit>().requestPermission();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'SMS permission granted'
              : 'SMS permission denied. Enable in app settings.',
        ),
        backgroundColor: granted ? Colors.green : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SmsCubit, SmsState>(
      builder: (context, state) {
        final hasPermission =
            state is SmsLoaded && state.smsPermissionGranted;
        final messageCount = state is SmsLoaded ? state.messages.length : 0;
        final unreadCount = state is SmsLoaded ? state.unreadCount : 0;
        final pendingSync = state is SmsLoaded
            ? state.messages
                .where((m) => m.status == SmsStatus.pending && !m.isRead)
                .length
            : 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasPermission ? Colors.green.shade200 : Colors.orange.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.sms_outlined,
                        color: hasPermission ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SMS Transaction Reader',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasPermission
                                  ? 'Reads debit/credit bank SMS automatically'
                                  : 'Permission required to read bank SMS',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: hasPermission
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          hasPermission ? 'On' : 'Off',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: hasPermission ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!hasPermission)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _requestPermission,
                        icon: const Icon(Icons.security),
                        label: const Text('Enable SMS Permission'),
                      ),
                    ),
                  if (hasPermission) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isScanning ? null : _scanInbox,
                        icon: _isScanning
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync),
                        label: Text(
                          _isScanning ? 'Scanning inbox...' : 'Scan SMS Inbox',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Imports debit/credit SMS. Tap a message to sync amount to an account.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
            if (pendingSync > 0) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sync, color: Colors.blue, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$pendingSync SMS ready to sync to wallet',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: Colors.grey[50],
              leading: const CircleAvatar(
                child: Icon(Icons.list_alt),
              ),
              title: const Text('View stored SMS'),
              subtitle: Text(
                messageCount == 0
                    ? 'No debit/credit messages yet'
                    : '$messageCount message${messageCount == 1 ? '' : 's'}'
                        '${unreadCount > 0 ? ' · $unreadCount new' : ''}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (unreadCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SmsMessagesScreen(),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
