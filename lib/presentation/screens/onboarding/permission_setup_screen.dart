import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/utils/permission_setup_gate.dart';
import '../../../data/repositories/sms_repository.dart';
import '../../../data/services/sms_coordinator_service.dart';
import '../../../data/services/sms_import_service.dart';
import '../../../logic/cubits/sms_cubit.dart';
import '../../theme/brand_colors.dart';

/// Shown once after login on Android to request SMS, notifications, and overlay.
class PermissionSetupScreen extends StatefulWidget {
  const PermissionSetupScreen({super.key});

  @override
  State<PermissionSetupScreen> createState() => _PermissionSetupScreenState();
}

class _PermissionSetupScreenState extends State<PermissionSetupScreen>
    with WidgetsBindingObserver {
  bool _smsGranted = false;
  bool _notificationGranted = false;
  bool _overlayGranted = false;
  bool _smsPermanentDeny = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (!Platform.isAndroid) {
      if (mounted) await PermissionSetupGate.completeAndContinue(context);
      return;
    }

    final sms = await Permission.sms.status;
    final notif = await Permission.notification.status;
    final repo = context.read<SmsRepository>();
    final overlay = await SmsImportService(repo).canDrawOverlays();

    if (!mounted) return;
    setState(() {
      _smsGranted = sms.isGranted;
      _smsPermanentDeny = sms.isPermanentlyDenied;
      _notificationGranted = notif.isGranted;
      _overlayGranted = overlay;
      _loading = false;
    });
  }

  Future<void> _requestSms() async {
    if (_smsPermanentDeny) {
      await openAppSettings();
      return;
    }
    final granted = await context.read<SmsCubit>().requestPermission();
    if (granted && mounted) {
      await context.read<SmsCoordinatorService>().onPermissionGranted();
      await context.read<SmsCubit>().scanInbox();
    }
    await _refresh();
  }

  Future<void> _requestNotification() async {
    final status = await Permission.notification.status;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    await Permission.notification.request();
    await _refresh();
  }

  Future<void> _requestOverlay() async {
    final repo = context.read<SmsRepository>();
    await SmsImportService(repo).requestOverlayPermission();
    await _refresh();
  }

  Future<void> _continue() async {
    await PermissionSetupGate.completeAndContinue(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: BrandColors.washGradient),
          child: SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Center(child: BrandAppIcon(size: 88)),
                              const SizedBox(height: 24),
                              Text(
                                'Allow permissions',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: BrandColors.navy,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Arthigo reads bank SMS to auto-track transactions and shows alerts when money moves.',
                                style: TextStyle(
                                  color: BrandColors.muted,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 28),
                              _PermissionTile(
                                icon: Icons.sms_outlined,
                                color: BrandColors.blue,
                                title: 'SMS access',
                                subtitle:
                                    'Detect debit/credit messages from banks and UPI.',
                                granted: _smsGranted,
                                required: true,
                                actionLabel: _smsPermanentDeny
                                    ? 'Open settings'
                                    : 'Allow SMS',
                                onAction: _requestSms,
                              ),
                              _PermissionTile(
                                icon: Icons.notifications_outlined,
                                color: BrandColors.cyan,
                                title: 'Notifications',
                                subtitle:
                                    'Get alerts for new transactions and SMS review.',
                                granted: _notificationGranted,
                                actionLabel: 'Allow notifications',
                                onAction: _requestNotification,
                              ),
                              _PermissionTile(
                                icon: Icons.layers_outlined,
                                color: BrandColors.green,
                                title: 'Display over other apps',
                                subtitle:
                                    'Quick-add overlay when an SMS arrives while the app is closed.',
                                granted: _overlayGranted,
                                actionLabel: 'Allow overlay',
                                onAction: _requestOverlay,
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: BrandColors.blue.withOpacity(0.15),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.info_outline,
                                        size: 18, color: BrandColors.blue),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'SMS is required for auto tracking. You can enable the rest later in Settings → SMS.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: BrandColors.muted,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: FilledButton(
                                onPressed: _continue,
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  _smsGranted ? 'Continue' : 'Continue anyway',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            if (!_smsGranted) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Without SMS, add transactions manually from the Expenses tab.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: BrandColors.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool granted;
  final bool required;
  final String actionLabel;
  final VoidCallback onAction;

  const _PermissionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.granted,
    this.required = false,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: granted ? Colors.green.withOpacity(0.35) : color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
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
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: BrandColors.navy,
                            ),
                          ),
                        ),
                        if (required)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: BrandColors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Required',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: BrandColors.blue,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: BrandColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                granted ? Icons.check_circle : Icons.radio_button_unchecked,
                color: granted ? Colors.green : Colors.grey.shade400,
              ),
            ],
          ),
          if (!granted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
