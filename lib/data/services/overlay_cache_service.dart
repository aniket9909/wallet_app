import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';

import '../../core/database/local_app_database.dart';
import '../models/account_model.dart';
import '../models/money_plan_model.dart';
import '../models/settings_model.dart';
import '../../presentation/widgets/sms_sync_sheet.dart';

/// Pushes local SQLite + state to native SharedPreferences/SQLite so the
/// SMS overlay works when the Flutter app is closed (online or offline).
class OverlayCacheService {
  static const MethodChannel _channel = MethodChannel('com.aniket.ewallet/sms');
  static DateTime? _lastSyncAt;
  static const _minInterval = Duration(seconds: 20);

  /// Reads from [LocalAppDatabase] and pushes to native overlay cache.
  /// Skips if a sync already ran recently unless [force] is true.
  static Future<void> syncFromLocalDatabase({bool force = false}) async {
    if (!Platform.isAndroid) return;

    final now = DateTime.now();
    if (!force &&
        _lastSyncAt != null &&
        now.difference(_lastSyncAt!) < _minInterval) {
      return;
    }
    _lastSyncAt = now;

    final db = LocalAppDatabase.instance;
    final accounts = await db.getAccounts();
    final settings = await db.loadSettings();
    final plan = await db.loadMoneyPlan();
    final subtypesFromDb = await db.getSubcategories();

    await syncFromState(
      accounts: accounts,
      settings: settings,
      moneyPlan: plan,
      extraSubtypes: subtypesFromDb,
    );
  }

  static Future<void> syncFromState({
    List<AccountModel>? accounts,
    SettingsModel? settings,
    MoneyPlanModel? moneyPlan,
    Map<String, List<String>>? extraSubtypes,
  }) async {
    if (!Platform.isAndroid) return;

    final categories = <String>{};
    if (settings != null) {
      categories.addAll(settings.expenseTypes);
    }

    final subtypesMap = _buildSubtypesMap(moneyPlan, extraSubtypes);
    if (settings != null) {
      for (final section in subtypesMap.keys) {
        categories.addAll(subtypesMap[section] ?? const []);
      }
    }

    final accountPayload = (accounts ?? const <AccountModel>[])
        .map(
          (a) => {
            'id': a.id,
            'name': a.name,
            'type': a.type,
            'last_digits': a.lastDigits,
            'balance': a.balance,
          },
        )
        .toList();

    String? uid;
    String? idToken;
    try {
      final user = FirebaseAuth.instance.currentUser;
      uid = user?.uid;
      idToken = await user?.getIdToken();
    } catch (_) {}

    String? dbUrl;
    try {
      dbUrl = FirebaseDatabase.instance.databaseURL;
    } catch (_) {}

    try {
      await _channel.invokeMethod<bool>('cacheOverlayData', {
        'accountsJson': jsonEncode(accountPayload),
        'categoriesJson': jsonEncode(categories.toList()),
        'plannerSubtypesJson': jsonEncode(subtypesMap),
        'uid': uid,
        'idToken': idToken,
        'dbUrl': dbUrl,
      });
    } catch (_) {}
  }

  static Map<String, List<String>> _buildSubtypesMap(
    MoneyPlanModel? plan,
    Map<String, List<String>>? extraSubtypes,
  ) {
    final map = <String, List<String>>{};
    for (final entry in SmsSyncSheet.plannerSubtypes.entries) {
      map[entry.key] = List<String>.from(entry.value);
    }
    if (extraSubtypes != null) {
      for (final entry in extraSubtypes.entries) {
        final list = map.putIfAbsent(entry.key, () => <String>[]);
        for (final name in entry.value) {
          if (name.isNotEmpty && !list.contains(name)) {
            list.insert(0, name);
          }
        }
      }
    }
    if (plan == null) return map;

    void merge(String section, Iterable<String> names) {
      final list = map.putIfAbsent(section, () => <String>[]);
      for (final name in names) {
        if (name.isNotEmpty && !list.contains(name)) {
          list.insert(0, name);
        }
      }
    }

    merge('Essentials', plan.expenses.map((e) => e.name));
    merge('Investment', plan.investments.map((i) => i.name));
    merge('Goals', plan.goals.map((g) => g.name));
    merge('Debt & EMI', plan.debts.map((d) => d.name));
    merge('Personal', plan.personalCategories.map((e) => e.name));
    return map;
  }
}
