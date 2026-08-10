import 'package:flutter/foundation.dart';

/// In-app + console SMS fetch diagnostics so you can see if SMS is arriving.
class SmsDebugLog {
  SmsDebugLog._();

  static final ValueNotifier<List<String>> lines =
      ValueNotifier<List<String>>(<String>[]);

  static const int _maxLines = 80;
  static const String _tag = 'SMS_FETCH';

  static void clear() {
    lines.value = <String>[];
  }

  static void info(String message) => _add('INFO', message);

  static void ok(String message) => _add('OK', message);

  static void warn(String message) => _add('WARN', message);

  static void error(String message) => _add('ERROR', message);

  static void smsReceived({
    required String address,
    required String body,
    required String kind,
    double? amount,
    String? txnType,
    required bool isTxn,
  }) {
    final preview = body.length > 100 ? '${body.substring(0, 100)}…' : body;
    ok(
      'SMS received [$kind] from "${address.isEmpty ? 'unknown' : address}"',
    );
    info('Body: $preview');
    if (isTxn) {
      ok(
        'Detected ${txnType ?? 'txn'}'
        '${amount != null ? ' ₹${amount.toStringAsFixed(2)}' : ''} → will save / show popup',
      );
    } else {
      warn('Not credit/debit+amount → skipped (no popup)');
    }
  }

  static void _add(String level, String message) {
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    final line = '[$time][$level] $message';
    // ignore: avoid_print
    print('========== $_tag ==========');
    // ignore: avoid_print
    print(line);
    // ignore: avoid_print
    print('===========================');

    final next = List<String>.from(lines.value)..insert(0, line);
    if (next.length > _maxLines) {
      next.removeRange(_maxLines, next.length);
    }
    lines.value = next;
  }
}
