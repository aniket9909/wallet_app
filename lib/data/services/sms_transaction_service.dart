import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/account_model.dart';
import '../models/partial_transaction_model.dart';
import '../models/transaction_model_new.dart';

class SmsTransactionService {
  static const MethodChannel _channel = MethodChannel('com.aniket.ewallet/sms');

  Future<bool> _hasPermission() async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.sms.status;
    if (!status.isGranted) return false;
    return await _channel.invokeMethod<bool>('checkPermission') ?? false;
  }

  Future<List<PartialTransaction>> readPartialTransactionsFromSms(
    List<AccountModel> accounts,
  ) async {
    print('readPartialTransactionsFromSms called');
    if (!Platform.isAndroid) return [];
    
    final hasPerm = await _hasPermission();
    if (!hasPerm) return [];

    try {
      final smsJsonString = await _channel.invokeMethod<String>('readSms');
      if (smsJsonString == null) return [];

      final smsList = jsonDecode(smsJsonString) as List;
      final result = <PartialTransaction>[];

      for (final smsData in smsList) {
        final sms = smsData as Map<String, dynamic>;
        final body = sms['body'] as String? ?? '';
        if (body.isEmpty) continue;

        for (final account in accounts) {
          final digits = account.lastDigits;
          if (digits == null || digits.isEmpty) continue;
          if (!body.contains(digits)) continue;

          final parsed = _parseSms(body, digits);
          if (parsed == null) continue;

          final dateMillis = sms['date'] as int? ?? DateTime.now().millisecondsSinceEpoch;
          final smsId = sms['id'] as int? ?? 0;

          result.add(
            PartialTransaction(
              id: smsId.toString(),
              accountName: account.name,
              amount: parsed.amount,
              type: parsed.type,
              description: parsed.description,
              date: DateTime.fromMillisecondsSinceEpoch(dateMillis),
              smsBody: body,
              matchedDigits: digits,
            ),
          );
        }
      }

      return result;
    } catch (e) {
      print('Error reading SMS: $e');
      return [];
    }
  }

  _ParsedSms? _parseSms(String body, String digits) {
    final lower = body.toLowerCase();
    final isCredit = lower.contains('credited') ||
        lower.contains('cr.') ||
        lower.contains('cr ') ||
        lower.contains('received');
    final isDebit = lower.contains('debited') ||
        lower.contains('dr.') ||
        lower.contains('dr ') ||
        lower.contains('spent') ||
        lower.contains('withdrawn');

    if (!isCredit && !isDebit) return null;

    final amountRegex = RegExp(r'(inr|rs\.?|₹)\s*([0-9,]+\.?[0-9]*)',
        caseSensitive: false);
    final match = amountRegex.firstMatch(body);
    if (match == null) return null;

    final raw = match.group(2) ?? '';
    final normalized = raw.replaceAll(',', '');
    final amount = double.tryParse(normalized);
    if (amount == null) return null;

    final type =
        isCredit ? TransactionType.credit : TransactionType.debit;

    final description = 'SMS ${isCredit ? 'credit' : 'debit'} $digits';

    return _ParsedSms(
      amount: amount,
      type: type,
      description: description,
    );
  }
}

class _ParsedSms {
  final double amount;
  final TransactionType type;
  final String description;

  _ParsedSms({
    required this.amount,
    required this.type,
    required this.description,
  });
}


