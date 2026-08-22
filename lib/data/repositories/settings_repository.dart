import '../../core/database/local_app_database.dart';
import '../models/settings_model.dart';
import '../services/firebase_realtime_service.dart';
import '../services/offline_sync_service.dart';

class SettingsRepository {
  final FirebaseRealtimeService _firebaseService;
  final LocalAppDatabase _db = LocalAppDatabase.instance;
  final OfflineSyncService _sync = OfflineSyncService.instance;

  SettingsRepository(this._firebaseService);

  Stream<SettingsModel> watchSettings() async* {
    final local = await _db.loadSettings();
    if (local != null) yield local;
    try {
      await for (final remote in _firebaseService.watchSettings()) {
        await _db.saveSettings(remote, synced: true);
        yield remote;
      }
    } catch (_) {
      final fallback = await _db.loadSettings();
      if (fallback != null) yield fallback;
    }
  }

  Future<void> updateSettings(SettingsModel settings) async {
    await _db.saveSettings(settings, synced: false);
    await _sync.enqueueAndMaybeFlush(
      firebase: _firebaseService,
      entity: LocalAppDatabase.entitySettings,
      entityId: LocalAppDatabase.entitySettings,
      action: 'upsert',
      payload: Map<String, dynamic>.from(settings.toJson()),
      onlineWrite: () async {
        await _firebaseService.updateSettings(settings);
        await _db.saveSettings(settings, synced: true);
      },
    );
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
    final updatedTypes =
        currentSettings.expenseTypes.where((t) => t != type).toList();
    await updateSettings(
      currentSettings.copyWith(expenseTypes: updatedTypes),
    );
  }
}
