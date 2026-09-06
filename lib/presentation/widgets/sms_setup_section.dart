import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../logic/cubits/sms_cubit.dart';
import '../../data/models/sms_message_model.dart';
import '../../data/repositories/sms_repository.dart';
import '../../data/services/sms_coordinator_service.dart';
import '../../data/services/sms_import_service.dart';
import '../../data/services/sms_debug_log.dart';
import '../../routes/app_routes.dart';
import 'sms_sync_sheet.dart';

class SmsSetupSection extends StatefulWidget {
  const SmsSetupSection({super.key});

  @override
  State<SmsSetupSection> createState() => _SmsSetupSectionState();
}

class _SmsSetupSectionState extends State<SmsSetupSection> with WidgetsBindingObserver {
  bool _isScanning = false;
  bool _isPermanentlyDenied = false;
  bool _canDrawOverlays = false;
  bool _quickAccessOn = false;

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
    var quickAccess = false;
    try {
      final repo = context.read<SmsRepository>();
      quickAccess = await SmsImportService(repo).isQuickAccessBubbleEnabled();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _isPermanentlyDenied = status.isPermanentlyDenied;
      _canDrawOverlays = canOverlay;
      _quickAccessOn = quickAccess;
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

  Future<void> _toggleQuickAccess(bool enabled) async {
    try {
      final repo = context.read<SmsRepository>();
      final service = SmsImportService(repo);
      if (enabled) {
        final started = await service.startQuickAccessBubble();
        if (!mounted) return;
        setState(() => _quickAccessOn = started);
        if (!started) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Enable Display over other apps first, then turn Quick add on.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        await service.stopQuickAccessBubble();
        if (!mounted) return;
        setState(() => _quickAccessOn = false);
      }
    } catch (_) {}
  }

  Future<void> _testOverlayPopup() async {
    final sample = SmsMessageModel(
      body:
          'Dear Customer, Your A/c XX1234 is debited for INR 1,250.00 on 09-08-2026. '
          'Info: UPI/merchant@okaxis. Avl Bal INR 24,380.50 - Axis Bank',
      address: 'AX-AIBK-S',
      date: DateTime.now(),
      isRead: false,
      status: SmsStatus.pending,
      isCreditDebit: true,
      amount: 1250,
      transactionType: 'debit',
    );
    if (!mounted) return;
    await SmsSyncSheet.show(context, sample);
  }

  Future<void> _scanInbox() async {
    if (!mounted) return;
    SmsDebugLog.info('Inbox scan started…');
    setState(() => _isScanning = true);
    try {
      final result = await context.read<SmsCubit>().scanInbox();
      if (!mounted) return;

      if (result == null) {
        SmsDebugLog.error('Inbox scan failed');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to scan SMS. Enable permission in Settings below.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      SmsDebugLog.ok(
        'Inbox scan done — scanned=${result.scanned}, imported=${result.imported}, skipped=${result.skipped}',
      );

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
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
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
    if (!mounted) return;
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
                                    ? 'Popup + full-screen alert when bank SMS arrives (app closed too)'
                                    : 'Enable overlay + notifications so popup works when app is closed',
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
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.ads_click_outlined,
                          color: _quickAccessOn ? Colors.green : Colors.orange,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Quick add floating button',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Keeps a ₹ button over other apps. Tap it to enter amount, account, section and subcategory when SMS is missed.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _quickAccessOn,
                          onChanged: _toggleQuickAccess,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _testOverlayPopup,
                        icon: const Icon(Icons.preview_outlined),
                        label: const Text('Test sync setup popup'),
                      ),
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
                Navigator.pushNamed(context, AppRoutes.smsMessages);
              },
            ),
            const SizedBox(height: 12),
            _SmsFetchLogPanel(),
          ],
        );
      },
    );
  }
}

class _SmsFetchLogPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: SmsDebugLog.lines,
      builder: (context, logs, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.terminal, color: Color(0xFF38BDF8), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'SMS fetch log',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: SmsDebugLog.clear,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF94A3B8),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Filter logcat by: SMS_FETCH',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 10),
              if (logs.isEmpty)
                Text(
                  'Waiting for SMS…\nSend a bank SMS or tap Scan inbox to see logs here.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    height: 1.4,
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 10,
                      color: Colors.white.withOpacity(0.08),
                    ),
                    itemBuilder: (context, index) {
                      final line = logs[index];
                      final color = line.contains('[ERROR]')
                          ? const Color(0xFFF87171)
                          : line.contains('[WARN]')
                              ? const Color(0xFFFBBF24)
                              : line.contains('[OK]')
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFFE2E8F0);
                      return Text(
                        line,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          height: 1.35,
                          fontFamily: 'monospace',
                        ),
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
}
