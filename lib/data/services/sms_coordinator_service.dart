import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../logic/cubits/sms_cubit.dart';
import '../../presentation/widgets/sms_sync_sheet.dart';
import '../models/sms_message_model.dart';
import '../repositories/sms_repository.dart';
import 'sms_import_service.dart';
import 'sms_listener_service.dart';
import 'sms_debug_log.dart';

/// Manages SMS background listening. Permission requests belong in Settings only.
class SmsCoordinatorService with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('com.aniket.ewallet/sms');

  final GlobalKey<NavigatorState> navigatorKey;
  final SmsListenerService _listenerService = SmsListenerService();
  bool _isListening = false;
  bool _isAppForeground = true;
  bool _handlingSyncRequest = false;

  SmsCoordinatorService({required this.navigatorKey});

  Future<void> startListenerIfPermitted() async {
    if (!Platform.isAndroid) return;

    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler(_onPlatformCall);
    _isAppForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    final status = await Permission.sms.status;
    SmsDebugLog.info(
      'Coordinator start — SMS permission=${status.isGranted}, fg=$_isAppForeground',
    );
    if (status.isGranted && !_isListening) {
      _startListener();
    } else if (!status.isGranted) {
      SmsDebugLog.warn('SMS permission not granted — listener idle');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingSync();
    });
  }

  Future<void> onPermissionGranted() async {
    if (!Platform.isAndroid || _isListening) return;
    SmsDebugLog.ok('Permission granted — starting listener');
    _startListener();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppForeground = state == AppLifecycleState.resumed;
    SmsDebugLog.info(
      'App lifecycle=$state → foreground=$_isAppForeground',
    );
    if (_isAppForeground) {
      _consumePendingSync();
    }
  }

  Future<dynamic> _onPlatformCall(MethodCall call) async {
    if (call.method == 'onSmsSyncRequest') {
      SmsDebugLog.info('Platform sync request received (overlay Sync tapped)');
      final args = call.arguments;
      if (args is Map) {
        await _handleSyncRequest(Map<String, dynamic>.from(args));
      }
    }
  }

  Future<void> _consumePendingSync() async {
    try {
      final appContext = navigatorKey.currentContext;
      if (appContext == null) return;
      final pending =
          await SmsImportService(appContext.read<SmsRepository>()).getPendingSmsSync();
      if (pending != null) {
        SmsDebugLog.info('Found pending sync payload after resume');
        await _handleSyncRequest(pending);
      }
    } catch (e) {
      SmsDebugLog.error('consumePendingSync failed: $e');
    }
  }

  Future<void> _handleSyncRequest(Map<String, dynamic> payload) async {
    if (_handlingSyncRequest) return;
    _handlingSyncRequest = true;
    try {
      final body = payload['body'] as String? ?? '';
      if (body.isEmpty) {
        SmsDebugLog.warn('Sync request empty body');
        return;
      }

      final address = payload['address'] as String? ?? '';
      final dateMillis = payload['date'];
      final date = dateMillis is int
          ? DateTime.fromMillisecondsSinceEpoch(dateMillis)
          : dateMillis is num
              ? DateTime.fromMillisecondsSinceEpoch(dateMillis.toInt())
              : DateTime.now();
      final initialAccount = payload['account'] as String?;
      final initialCategory = payload['category'] as String?;
      final initialPlannerSection = payload['plannerSection'] as String?;

      final appContext = navigatorKey.currentContext;
      if (appContext == null) {
        SmsDebugLog.warn('No context for sync request');
        return;
      }

      final importService = SmsImportService(appContext.read<SmsRepository>());
      final saved = await importService.saveIfTransactionSms(
        body: body,
        address: address,
        date: date,
      );
      if (saved == null) {
        SmsDebugLog.warn('Sync request SMS not saved (not txn or duplicate fail)');
        return;
      }

      SmsDebugLog.ok(
        'Saved SMS id=${saved.id} ${saved.transactionType} ₹${saved.amount}'
        '${initialAccount != null ? ' · account=$initialAccount' : ''}'
        '${initialCategory != null ? ' · category=$initialCategory' : ''}',
      );

      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;

      try {
        ctx.read<SmsCubit>().loadAllSms();
      } catch (_) {}

      _showSyncForm(
        saved,
        initialAccount: initialAccount,
        initialCategory: initialCategory,
        initialPlannerSection: initialPlannerSection,
      );
    } catch (e) {
      SmsDebugLog.error('handleSyncRequest failed: $e');
    } finally {
      _handlingSyncRequest = false;
    }
  }

  void _startListener() {
    _isListening = true;
    SmsDebugLog.ok('Coordinator listening for live SMS');

    _listenerService.startListening((body, address, date) async {
      try {
        final appContext = navigatorKey.currentContext;
        if (appContext == null) {
          SmsDebugLog.warn('SMS arrived but no Flutter context yet');
          return;
        }

        final importService = SmsImportService(appContext.read<SmsRepository>());
        final saved = await importService.saveIfTransactionSms(
          body: body,
          address: address,
          date: date,
        );
        if (saved == null) {
          SmsDebugLog.warn('Live SMS not stored (not txn / duplicate)');
          return;
        }

        SmsDebugLog.ok(
          'Stored live SMS id=${saved.id} → '
          '${_isAppForeground ? 'show sync sheet' : 'native overlay handles UI'}',
        );

        final ctx = navigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) return;

        try {
          ctx.read<SmsCubit>().loadAllSms();
        } catch (_) {}

        if (_isAppForeground) {
          _showSyncForm(saved);
        }
      } catch (e) {
        SmsDebugLog.error('Live SMS handling failed: $e');
      }
    });
  }

  void _showSyncForm(
    SmsMessageModel message, {
    String? initialAccount,
    String? initialCategory,
    String? initialPlannerSection,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      SmsSyncSheet.show(
        ctx,
        message,
        initialAccount: initialAccount,
        initialCategory: initialCategory,
        initialPlannerSection: initialPlannerSection,
      );
    });
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    _listenerService.dispose();
    _isListening = false;
  }
}
