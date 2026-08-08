import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../logic/cubits/sms_cubit.dart';
import '../../data/models/sms_message_model.dart';
import '../../data/repositories/sms_repository.dart';
import '../../data/services/sms_coordinator_service.dart';
import '../../data/services/sms_import_service.dart';
import '../../routes/app_routes.dart';

class SmsSetupSection extends StatefulWidget {
  const SmsSetupSection({super.key});

  @override
  State<SmsSetupSection> createState() => _SmsSetupSectionState();
}

class _SmsSetupSectionState extends State<SmsSetupSection> with WidgetsBindingObserver {
  bool _isScanning = false;
  bool _isPermanentlyDenied = false;
  bool _canDrawOverlays = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<SmsCubit>().loadAllSms();
    _refreshPermissionStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissionStatus();
    }
  }

  Future<void> _refreshPermissionStatus() async {
    if (!Platform.isAndroid) return;
    final status = await Permission.sms.status;
    final canOverlay = await _checkOverlay();
    if (!mounted) return;
    setState(() {
      _isPermanentlyDenied = status.isPermanentlyDenied;
      _canDrawOverlays = canOverlay;
    });
  }

  Future<bool> _checkOverlay() async {
    try {
      final repo = context.read<SmsRepository>();
      return await SmsImportService(repo).canDrawOverlays();
    } catch (_) {
      return false;
    }
  }

  Future<void> _requestOverlayPermission() async {
    try {
      final repo = context.read<SmsRepository>();
      await SmsImportService(repo).requestOverlayPermission();
    } catch (_) {}
  }

  Future<void> _scanInbox() async {
    setState(() => _isScanning = true);
    final result = await context.read<SmsCubit>().scanInbox();
    setState(() => _isScanning = false);

    if (!mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to scan SMS. Enable permission in Settings below.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (result.scanned == 0 && result.imported == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMS permission required. Enable it below to scan inbox.'),
          backgroundColor: Colors.orange,
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
    await _refreshPermissionStatus();
    if (!mounted) return;

    if (granted) {
      await context.read<SmsCoordinatorService>().onPermissionGranted();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMS permission granted'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    final status = await Permission.sms.status;
    if (!mounted) return;

    if (status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission blocked. Open system settings to enable SMS access.'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMS permission denied'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _openSystemSettings() async {
    await openAppSettings();
    await Future.delayed(const Duration(milliseconds: 500));
    await context.read<SmsCubit>().loadAllSms();
    await _refreshPermissionStatus();
    if (!mounted) return;

    final hasPermission = context.read<SmsCubit>().state is SmsLoaded &&
        (context.read<SmsCubit>().state as SmsLoaded).smsPermissionGranted;
    if (hasPermission) {
      await context.read<SmsCoordinatorService>().onPermissionGranted();
    }
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
                                  : _isPermanentlyDenied
                                      ? 'Enable SMS access in system settings'
                                      : 'Grant permission to read bank SMS',
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
                  if (!hasPermission) ...[
                    if (_isPermanentlyDenied)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openSystemSettings,
                          icon: const Icon(Icons.settings),
                          label: const Text('Open System Settings'),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _requestPermission,
                          icon: const Icon(Icons.security),
                          label: const Text('Enable SMS Permission'),
                        ),
                      ),
                  ],
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
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.picture_in_picture_alt_outlined,
                          color: _canDrawOverlays ? Colors.green : Colors.orange,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Popup over other apps',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _canDrawOverlays
                                    ? 'Truecaller-style popup when bank SMS arrives'
                                    : 'Required to show SMS popup on home screen',
                                style: TextStyle(
                                  fontSize: 11,
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
                            color: _canDrawOverlays
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _canDrawOverlays ? 'On' : 'Off',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color:
                                  _canDrawOverlays ? Colors.green : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!_canDrawOverlays) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _requestOverlayPermission,
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Enable Display Over Apps'),
                        ),
                      ),
                    ],
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
                Navigator.pushNamed(context, AppRoutes.smsMessages);
              },
            ),
          ],
        );
      },
    );
  }
}
