import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../../core/utils/sms_detection_util.dart';
import 'sms_debug_log.dart';

class SmsListenerService {
  static const EventChannel _eventChannel =
      EventChannel('com.aniket.ewallet/sms_events');
  StreamSubscription<dynamic>? _subscription;
  Function(String body, String address, DateTime date)? onSmsReceived;

  void startListening(Function(String body, String address, DateTime date) onSms) {
    SmsDebugLog.info('Flutter SMS listener starting…');

    if (!Platform.isAndroid) {
      SmsDebugLog.warn('Not Android — listener not started');
      return;
    }

    onSmsReceived = onSms;
    _subscription?.cancel();

    try {
      _subscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          SmsDebugLog.info('EventChannel got SMS event from Android');
          try {
            final eventString = event as String;
            final smsData = jsonDecode(eventString) as Map<String, dynamic>;

            final body = smsData['body'] as String? ?? '';
            final address = smsData['address'] as String? ?? '';
            final kind = smsData['smsKind'] as String? ?? 'text';
            final dateMillis =
                smsData['date'] as int? ?? DateTime.now().millisecondsSinceEpoch;
            final date = DateTime.fromMillisecondsSinceEpoch(dateMillis);

            final detection = SmsDetectionUtil.detectCreditDebit(
              body,
              address: address,
            );
            SmsDebugLog.smsReceived(
              address: address,
              body: body,
              kind: kind,
              amount: detection?.amount,
              txnType: detection?.transactionType,
              isTxn: detection != null,
            );

            if (body.isNotEmpty && onSmsReceived != null) {
              SmsDebugLog.info('Forwarding SMS to coordinator…');
              onSmsReceived!(body, address, date);
            } else if (body.isEmpty) {
              SmsDebugLog.warn('Empty body — not forwarding');
            }
          } catch (e) {
            SmsDebugLog.error('Failed to parse SMS event: $e');
          }
        },
        onError: (error) {
          SmsDebugLog.error('EventChannel error: $error');
        },
        onDone: () {
          SmsDebugLog.warn('EventChannel stream closed');
        },
        cancelOnError: false,
      );
      SmsDebugLog.ok('Flutter SMS listener active (waiting for SMS)');
    } catch (e) {
      SmsDebugLog.error('Could not start listener: $e');
    }
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    onSmsReceived = null;
    SmsDebugLog.info('Flutter SMS listener stopped');
  }

  void dispose() {
    stopListening();
  }
}
