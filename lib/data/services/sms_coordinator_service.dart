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
    if (status.isGranted && !_isListening) {
      _startListener();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingSync();
    });
  }

  Future<void> onPermissionGranted() async {
    if (!Platform.isAndroid || _isListening) return;
    _startListener();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppForeground = state == AppLifecycleState.resumed;
    if (_isAppForeground) {
      _consumePendingSync();
    }
  }

  Future<dynamic> _onPlatformCall(MethodCall call) async {
    if (call.method == 'onSmsSyncRequest') {
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
        await _handleSyncRequest(pending);
      }
    } catch (_) {}
  }

  Future<void> _handleSyncRequest(Map<String, dynamic> payload) async {
    if (_handlingSyncRequest) return;
    _handlingSyncRequest = true;
    try {
      final body = payload['body'] as String? ?? '';
      if (body.isEmpty) return;

      final address = payload['address'] as String? ?? '';
      final dateMillis = payload['date'];
      final date = dateMillis is int
          ? DateTime.fromMillisecondsSinceEpoch(dateMillis)
          : dateMillis is num
              ? DateTime.fromMillisecondsSinceEpoch(dateMillis.toInt())
              : DateTime.now();

      final appContext = navigatorKey.currentContext;
      if (appContext == null) return;

      final importService = SmsImportService(appContext.read<SmsRepository>());
      final saved = await importService.saveIfTransactionSms(
        body: body,
        address: address,
        date: date,
      );
      if (saved == null) return;

      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;

      try {
        ctx.read<SmsCubit>().loadAllSms();
      } catch (_) {}

      _showSyncForm(saved);
    } catch (_) {
    } finally {
      _handlingSyncRequest = false;
    }
  }

  void _startListener() {
    _isListening = true;

    _listenerService.startListening((body, address, date) async {
      try {
        final appContext = navigatorKey.currentContext;
        if (appContext == null) return;

        final importService = SmsImportService(appContext.read<SmsRepository>());
        final saved = await importService.saveIfTransactionSms(
          body: body,
          address: address,
          date: date,
        );
        if (saved == null) return;

        final ctx = navigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) return;

        try {
          ctx.read<SmsCubit>().loadAllSms();
        } catch (_) {}

        // Overlay owns the UI when backgrounded; avoid a hidden in-app sheet.
        if (_isAppForeground) {
          _showSyncForm(saved);
        }
      } catch (_) {}
    });
  }

  void _showSyncForm(SmsMessageModel message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      SmsSyncSheet.show(ctx, message);
    });
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    _listenerService.dispose();
    _isListening = false;
  }
}
