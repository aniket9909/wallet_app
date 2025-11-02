import '../models/settings_model.dart';
import '../services/firebase_realtime_service.dart';

class SettingsRepository {
  final FirebaseRealtimeService _firebaseService;

  SettingsRepository(this._firebaseService);

  Stream<SettingsModel> watchSettings() {
    return _firebaseService.watchSettings();
  }

  Future<void> updateSettings(SettingsModel settings) async {
    await _firebaseService.updateSettings(settings);
  }

  Future<void> toggleNotifications(SettingsModel currentSettings) async {
    await updateSettings(
      currentSettings.copyWith(
        notificationsEnabled: !currentSettings.notificationsEnabled,
      ),
    );
  }

  Future<void> toggleDarkMode(SettingsModel currentSettings) async {
    await updateSettings(
      currentSettings.copyWith(darkMode: !currentSettings.darkMode),
    );
  }

  Future<void> addExpenseType(String type, SettingsModel currentSettings) async {
    if (!currentSettings.expenseTypes.contains(type)) {
      final updatedTypes = [...currentSettings.expenseTypes, type];
      await updateSettings(
        currentSettings.copyWith(expenseTypes: updatedTypes),
      );
    }
  }

  Future<void> removeExpenseType(String type, SettingsModel currentSettings) async {
    final updatedTypes = currentSettings.expenseTypes.where((t) => t != type).toList();
    await updateSettings(
      currentSettings.copyWith(expenseTypes: updatedTypes),
    );
  }
}

