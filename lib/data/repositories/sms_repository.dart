import '../../core/database/sms_database_helper.dart';
import '../models/sms_message_model.dart';
import '../services/firebase_realtime_service.dart';

class SmsRepository {
  final SmsDatabaseHelper _dbHelper = SmsDatabaseHelper.instance;
  final FirebaseRealtimeService? _firebaseService;

  SmsRepository({FirebaseRealtimeService? firebaseService})
      : _firebaseService = firebaseService;

  Future<int> saveSms(SmsMessageModel sms) async {
    try {
      print('Saving SMS to database: ${sms.body.substring(0, sms.body.length > 50 ? 50 : sms.body.length)}...');
      final id = await _dbHelper.insertSms(sms);
      print('SMS saved with ID: $id');
      return id;
    } catch (e) {
      print('Error saving SMS: $e');
      rethrow;
    }
  }

  Future<List<SmsMessageModel>> getAllSms() async {
    try {
      return await _dbHelper.getAllSms();
    } catch (e) {
      print('Error getting all SMS: $e');
      return [];
    }
  }

  Future<List<SmsMessageModel>> getUnreadSms() async {
    try {
      return await _dbHelper.getUnreadSms();
    } catch (e) {
      print('Error getting unread SMS: $e');
      return [];
    }
  }

  Future<SmsMessageModel?> getSmsById(int id) async {
    try {
      return await _dbHelper.getSmsById(id);
    } catch (e) {
      print('Error getting SMS by ID: $e');
      return null;
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      await _dbHelper.markAsRead(id);
    } catch (e) {
      print('Error marking SMS as read: $e');
    }
  }

  Future<void> deleteSms(int id) async {
    try {
      await _dbHelper.deleteSms(id);
    } catch (e) {
      print('Error deleting SMS: $e');
    }
  }

  Future<void> deleteAllSms() async {
    try {
      await _dbHelper.deleteAllSms();
    } catch (e) {
      print('Error deleting all SMS: $e');
    }
  }

  Future<int> getSmsCount() async {
    try {
      return await _dbHelper.getSmsCount();
    } catch (e) {
      print('Error getting SMS count: $e');
      return 0;
    }
  }

  Future<int> getUnreadCount() async {
    try {
      return await _dbHelper.getUnreadCount();
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  Future<bool> existsByBodyAndDate(String body, DateTime date) async {
    try {
      return await _dbHelper.existsByBodyAndDate(body, date);
    } catch (e) {
      return false;
    }
  }

  Future<SmsMessageModel?> findByBodyAndDate(String body, DateTime date) async {
    try {
      return await _dbHelper.findByBodyAndDate(body, date);
    } catch (e) {
      return null;
    }
  }

  Future<List<SmsMessageModel>> getCreditDebitSms() async {
    try {
      return await _dbHelper.getCreditDebitSms();
    } catch (e) {
      return [];
    }
  }

  Future<List<SmsMessageModel>> getPendingUnsyncedSince(
    DateTime since, {
    int? limit,
  }) async {
    try {
      return await _dbHelper.getPendingUnsyncedSince(since, limit: limit);
    } catch (e) {
      return [];
    }
  }

  Future<void> updateSmsStatus(int id, SmsStatus status) async {
    try {
      final sms = await _dbHelper.getSmsById(id);
      if (sms != null) {
        final updated = sms.copyWith(status: status);
        await _dbHelper.updateSms(updated);
      }
    } catch (e) {
      print('Error updating SMS status: $e');
    }
  }

  Future<void> syncToFirebase(SmsMessageModel sms) async {
    final service = _firebaseService;
    if (service == null) {
      print('Firebase service not available, skipping sync');
      return;
    }
    try {
      await service.addSmsMessage(sms);
      print('SMS synced to Firebase');
    } catch (e) {
      print('Error syncing SMS to Firebase: $e');
    }
  }

  Future<void> syncAllToFirebase(List<SmsMessageModel> smsList) async {
    final service = _firebaseService;
    if (service == null) {
      print('Firebase service not available, skipping sync');
      return;
    }
    try {
      await service.syncSmsMessages(smsList);
      print('All SMS messages synced to Firebase');
    } catch (e) {
      print('Error syncing all SMS to Firebase: $e');
    }
  }

  Future<void> updateSmsInFirebase(SmsMessageModel sms) async {
    final service = _firebaseService;
    if (service == null) {
      print('Firebase service not available, skipping update');
      return;
    }
    try {
      await service.updateSmsMessage(sms);
      print('SMS updated in Firebase');
    } catch (e) {
      print('Error updating SMS in Firebase: $e');
    }
  }

  Future<void> deleteSmsFromFirebase(String smsId) async {
    final service = _firebaseService;
    if (service == null) {
      print('Firebase service not available, skipping delete');
      return;
    }
    try {
      await service.deleteSmsMessage(smsId);
      print('SMS deleted from Firebase');
    } catch (e) {
      print('Error deleting SMS from Firebase: $e');
    }
  }
}

