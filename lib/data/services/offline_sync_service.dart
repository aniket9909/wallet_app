import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/database/local_app_database.dart';
import '../models/account_model.dart';
import '../models/debt_model.dart';
import '../models/investment_model.dart';
import '../models/money_plan_model.dart';
import '../models/partial_transaction_model.dart';
import '../models/savings_goal_model.dart';
import '../models/settings_model.dart';
import '../models/transaction_model_new.dart';
import '../models/wallet_data_model.dart';
import 'firebase_realtime_service.dart';

/// Writes to the shared SQLite DB first, then Firebase.
/// If the device is offline, the change stays in [sync_queue] until [flush].
class OfflineSyncService {
  OfflineSyncService._();
  static final OfflineSyncService instance = OfflineSyncService._();

  final LocalAppDatabase _db = LocalAppDatabase.instance;
  bool _flushing = false;

  Future<T> runOnline<T>(Future<T> Function() action) async {
    return action();
  }

  Future<bool> tryOnline(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (e) {
      debugPrint('OfflineSync: firebase write deferred: $e');
      return false;
    }
  }

  Future<void> enqueueAndMaybeFlush({
    required FirebaseRealtimeService firebase,
    required String entity,
    required String entityId,
    required String action,
    Map<String, dynamic>? payload,
    required Future<void> Function() onlineWrite,
  }) async {
    final ok = await tryOnline(onlineWrite);
    if (!ok) {
      await _db.enqueue(
        entity: entity,
        entityId: entityId,
        action: action,
        payload: payload,
      );
      return;
    }
    await flush(firebase);
  }

  Future<void> flush(FirebaseRealtimeService firebase) async {
    if (_flushing) return;
    if (!firebase.isAuthenticated) return;
    _flushing = true;
    try {
      final pending = await _db.pendingSync();
      for (final row in pending) {
        final id = row['id'] as int;
        try {
          await _replay(firebase, row);
          await _db.removeQueueItem(id);
        } catch (e) {
          debugPrint('OfflineSync: queue item $id still pending: $e');
          break;
        }
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> _replay(
    FirebaseRealtimeService firebase,
    Map<String, dynamic> row,
  ) async {
    final entity = row['entity'] as String;
    final entityId = row['entity_id'] as String;
    final action = row['action'] as String;
    final raw = row['payload'] as String?;
    Map<String, dynamic> payload = {};
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
    }

    switch (entity) {
      case LocalAppDatabase.accountsTable:
        if (action == 'delete') {
          await firebase.deleteAccount(entityId);
        } else {
          await firebase.upsertAccount(AccountModel.fromJson(entityId, payload));
        }
        break;
      case LocalAppDatabase.entitySettings:
        await firebase.updateSettings(SettingsModel.fromJson(payload));
        break;
      case LocalAppDatabase.entityWallet:
        await firebase.updateWalletData(WalletDataModel.fromJson(payload));
        break;
      case LocalAppDatabase.entityMoneyPlan:
        await firebase.saveMoneyPlan(MoneyPlanModel.fromJson(payload));
        break;
      case LocalAppDatabase.entityTransactions:
        if (action == 'delete') {
          await firebase.deleteTransaction(entityId);
        } else {
          await firebase.upsertTransaction(
            TransactionModelNew.fromJson(entityId, payload),
          );
        }
        break;
      case LocalAppDatabase.entityDebts:
        if (action == 'delete') {
          await firebase.deleteDebt(entityId);
        } else {
          await firebase.addDebt(DebtModel.fromJson(entityId, payload));
        }
        break;
      case LocalAppDatabase.entityInvestments:
        if (action == 'delete') {
          await firebase.deleteInvestment(entityId);
        } else {
          await firebase.addInvestment(
            InvestmentModel.fromJson(entityId, payload),
          );
        }
        break;
      case LocalAppDatabase.entityGoals:
        if (action == 'delete') {
          await firebase.deleteSavingsGoal(entityId);
        } else {
          await firebase.addSavingsGoal(
            SavingsGoalModel.fromJson(entityId, payload),
          );
        }
        break;
      case LocalAppDatabase.entityPartials:
        if (action == 'delete') {
          await firebase.deletePartialTransaction(entityId);
        } else {
          await firebase.addPartialTransaction(
            PartialTransaction.fromJson(entityId, payload),
          );
        }
        break;
      default:
        debugPrint('OfflineSync: unknown entity $entity');
    }
  }
}
