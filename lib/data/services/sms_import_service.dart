import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/utils/sms_detection_util.dart';
import '../models/sms_message_model.dart';
import '../repositories/sms_repository.dart';

class SmsImportResult {
  final int scanned;
  final int imported;
  final int skipped;

  const SmsImportResult({
    required this.scanned,
    required this.imported,
    required this.skipped,
  });
}

class SmsImportService {
  static const MethodChannel _channel = MethodChannel('com.aniket.ewallet/sms');

  final SmsRepository _repository;

  SmsImportService(this._repository);

  Future<bool> hasSmsPermission() async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.sms.status;
    if (!status.isGranted) return false;
    return await _channel.invokeMethod<bool>('checkPermission') ?? false;
  }

  Future<bool> requestSmsPermission() async {
    if (!Platform.isAndroid) return false;
    final result = await Permission.sms.request();
    return result.isGranted;
  }

  /// Saves SMS if it contains debit/credit transaction keywords.
  Future<bool> saveIfTransactionSms({
    required String body,
    required String address,
    required DateTime date,
  }) async {
    final detection = SmsDetectionUtil.detectCreditDebit(body);
    if (detection == null) return false;

    final exists = await _repository.existsByBodyAndDate(body, date);
    if (exists) return false;

    final sms = SmsMessageModel(
      body: body,
      address: address,
      date: date,
      isRead: false,
      status: SmsStatus.pending,
      isCreditDebit: true,
      amount: detection.amount,
      transactionType: detection.transactionType,
    );

    await _repository.saveSms(sms);
    try {
      await _repository.syncToFirebase(sms);
    } catch (_) {}
    return true;
  }

  /// Reads inbox via platform channel and imports debit/credit SMS only.
  Future<SmsImportResult> importFromInbox() async {
    if (!Platform.isAndroid) {
      return const SmsImportResult(scanned: 0, imported: 0, skipped: 0);
    }

    final hasPerm = await hasSmsPermission();
    if (!hasPerm) {
      final granted = await requestSmsPermission();
      if (!granted) {
        return const SmsImportResult(scanned: 0, imported: 0, skipped: 0);
      }
    }

    final smsJsonString = await _channel.invokeMethod<String>('readSms');
    if (smsJsonString == null || smsJsonString.isEmpty) {
      return const SmsImportResult(scanned: 0, imported: 0, skipped: 0);
    }

    final smsList = jsonDecode(smsJsonString) as List;
    var imported = 0;
    var skipped = 0;

    for (final item in smsList) {
      final sms = item as Map<String, dynamic>;
      final body = sms['body'] as String? ?? '';
      if (body.isEmpty) continue;

      final detection = SmsDetectionUtil.detectCreditDebit(body);
      if (detection == null) {
        skipped++;
        continue;
      }

      final address = sms['address'] as String? ?? '';
      final dateMillis = sms['date'] as int? ?? DateTime.now().millisecondsSinceEpoch;
      final date = DateTime.fromMillisecondsSinceEpoch(dateMillis);

      final exists = await _repository.existsByBodyAndDate(body, date);
      if (exists) {
        skipped++;
        continue;
      }

      final model = SmsMessageModel(
        body: body,
        address: address,
        date: date,
        isRead: false,
        status: SmsStatus.pending,
        isCreditDebit: true,
        amount: detection.amount,
        transactionType: detection.transactionType,
      );

      await _repository.saveSms(model);
      imported++;
    }

    return SmsImportResult(
      scanned: smsList.length,
      imported: imported,
      skipped: skipped,
    );
  }
}
