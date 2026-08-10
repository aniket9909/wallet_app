import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';

import '../models/account_model.dart';
import '../models/money_plan_model.dart';
import '../models/settings_model.dart';

/// Pushes Firebase accounts + categories to native SharedPreferences so the
/// SMS overlay (other apps) can show bank/category pickers offline-first.
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
    if (moneyPlan != null) {
      for (final e in moneyPlan.expenses) {
        if (e.name.isNotEmpty) categories.add(e.name);
      }
      for (final i in moneyPlan.investments) {
        if (i.name.isNotEmpty) categories.add(i.name);
      }
      for (final g in moneyPlan.goals) {
        if (g.name.isNotEmpty) categories.add(g.name);
      }
      for (final d in moneyPlan.debts) {
        if (d.name.isNotEmpty) categories.add(d.name);
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
        'uid': uid,
        'idToken': idToken,
        'dbUrl': dbUrl,
      });
    } catch (_) {}
  }
}
