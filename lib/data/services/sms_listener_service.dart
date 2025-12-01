import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

class SmsListenerService {
  static const EventChannel _eventChannel = EventChannel('com.aniket.ewallet/sms_events');
  StreamSubscription<dynamic>? _subscription;
  Function(String body, String address, DateTime date)? onSmsReceived;

  void startListening(Function(String body, String address, DateTime date) onSms) {
    print('========== SMS LISTENER SERVICE: START LISTENING ==========');
    
    if (!Platform.isAndroid) {
      print('Not Android platform, returning...');
      return;
    }
    
    print('Platform is Android, setting up listener...');
    onSmsReceived = onSms;
    print('onSmsReceived callback set: ${onSmsReceived != null}');
    
    _subscription?.cancel();
    print('Previous subscription cancelled');
    
    print('Setting up EventChannel stream listener...');
    print('EventChannel name: com.aniket.ewallet/sms_events');
    
    try {
      _subscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          print('========== SMS EVENT RECEIVED IN FLUTTER ==========');
          print('Raw event type: ${event.runtimeType}');
          print('Raw event: $event');
          
          try {
            final eventString = event as String;
            print('Event as string: $eventString');
            
            final smsData = jsonDecode(eventString) as Map<String, dynamic>;
            print('Parsed SMS data: $smsData');
            
            final body = smsData['body'] as String? ?? '';
            final address = smsData['address'] as String? ?? '';
            final dateMillis = smsData['date'] as int? ?? DateTime.now().millisecondsSinceEpoch;
            final date = DateTime.fromMillisecondsSinceEpoch(dateMillis);
            
            print('Extracted data:');
            print('  Body: $body');
            print('  Address: $address');
            print('  Date: $date');
            print('  Body is empty: ${body.isEmpty}');
            print('  onSmsReceived is null: ${onSmsReceived == null}');
            
            if (body.isNotEmpty && onSmsReceived != null) {
              print('Calling onSmsReceived callback...');
              onSmsReceived!(body, address, date);
              print('Callback executed successfully');
            } else {
              if (body.isEmpty) {
                print('WARNING: Body is empty, not calling callback');
              }
              if (onSmsReceived == null) {
                print('WARNING: onSmsReceived is null, not calling callback');
              }
            }
          } catch (e, stackTrace) {
            print('ERROR parsing SMS event: $e');
            print('Stack trace: $stackTrace');
          }
          
          print('==================================================');
        },
        onError: (error) {
          print('========== SMS EVENT CHANNEL ERROR ==========');
          print('Error type: ${error.runtimeType}');
          print('Error: $error');
          print('==============================================');
        },
        onDone: () {
          print('========== SMS EVENT CHANNEL DONE ==========');
          print('Stream closed');
          print('===========================================');
        },
        cancelOnError: false,
      );
      
      print('EventChannel stream listener set up successfully');
      print('Subscription active: ${_subscription != null}');
    } catch (e, stackTrace) {
      print('ERROR setting up EventChannel listener: $e');
      print('Stack trace: $stackTrace');
    }
    
    print('==================================================');
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    onSmsReceived = null;
  }

  void dispose() {
    stopListening();
  }
}

