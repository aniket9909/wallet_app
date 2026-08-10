import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';

import '../models/account_model.dart';
import '../models/money_plan_model.dart';
import '../models/settings_model.dart';
import '../../presentation/widgets/sms_sync_sheet.dart';

/// Pushes Firebase accounts + planner subtypes to native SharedPreferences so the
/// SMS overlay can sync directly without opening the app.
class OverlayCacheService {
  static const MethodChannel _channel = MethodChannel('com.aniket.ewallet/sms');

  static Future<void> syncFromState({
    List<AccountModel>? accounts,
    SettingsModel? settings,
    MoneyPlanModel? moneyPlan,
  }) async {
    if (!Platform.isAndroid) return;

    final categories = <String>{};
    if (settings != null) {
      categories.addAll(settings.expenseTypes);
    }

    final subtypesMap = _buildSubtypesMap(moneyPlan);
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

  static Map<String, List<String>> _buildSubtypesMap(MoneyPlanModel? plan) {
    final map = <String, List<String>>{};
    for (final entry in SmsSyncSheet.plannerSubtypes.entries) {
      map[entry.key] = List<String>.from(entry.value);
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
    return map;
  }
}
