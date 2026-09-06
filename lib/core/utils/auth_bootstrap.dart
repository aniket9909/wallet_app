import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/services/firebase_realtime_service.dart';
import '../../data/services/sms_coordinator_service.dart';
import '../../data/services/overlay_cache_service.dart';
import '../../data/services/offline_sync_service.dart';
import '../../core/database/local_app_database.dart';
import '../../logic/cubits/account_cubit.dart';
import '../../logic/cubits/debt_cubit.dart';
import '../../logic/cubits/investment_cubit.dart';
import '../../logic/cubits/money_plan_cubit.dart';
import '../../logic/cubits/partial_transaction_cubit.dart';
import '../../logic/cubits/savings_goal_cubit.dart';
import '../../logic/cubits/settings_cubit.dart';
import '../../logic/cubits/sms_cubit.dart';
import '../../logic/cubits/transaction_cubit.dart';
import '../../logic/cubits/wallet_cubit.dart';

/// Fast essential bootstrap for Home, then one background pass for the rest.
class AuthBootstrap {
  static bool _didEssential = false;
  static bool _didBackground = false;
  static String? _bootstrappedUid;

  static bool get isEssentialReady => _didEssential;

  static Future<bool> setup(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('AuthBootstrap: no signed-in user');
      return false;
    }

    if (_didEssential && _bootstrappedUid == user.uid) {
      debugPrint('AuthBootstrap: already ready for uid=${user.uid}');
      _scheduleBackground(context);
      return true;
    }

    try {
      await user.getIdToken();
      final firebase = context.read<FirebaseRealtimeService>();

      await Future.wait([
        LocalAppDatabase.instance.database,
        firebase.initializeUserData(),
      ]);

      // Dashboard-critical streams only.
      context.read<WalletCubit>().loadWallet();
      context.read<AccountCubit>().loadAccounts();
      context.read<TransactionCubit>().loadTransactions();
      context.read<SettingsCubit>().loadSettings();
      context.read<MoneyPlanCubit>().loadPlan();

      _didEssential = true;
      _bootstrappedUid = user.uid;
      debugPrint('AuthBootstrap: essential ready for uid=${user.uid}');

      _scheduleBackground(context);
      return true;
    } catch (e, st) {
      debugPrint('AuthBootstrap failed: $e\n$st');
      return false;
    }
  }

  static void _scheduleBackground(BuildContext context) {
    if (_didBackground) return;
    _didBackground = true;

    final firebase = context.read<FirebaseRealtimeService>();
    final smsCoordinator = context.read<SmsCoordinatorService>();
    final savings = context.read<SavingsGoalCubit>();
    final debt = context.read<DebtCubit>();
    final investment = context.read<InvestmentCubit>();
    final partials = context.read<PartialTransactionCubit>();

    // Wait until Home has painted and SQLite is quiet.
    Future<void>.delayed(const Duration(seconds: 2), () async {
      try {
        savings.loadGoals();
        debt.loadDebts();
        investment.loadInvestments();
        partials.loadPartialTransactions();
        await OfflineSyncService.instance.flush(firebase);
        await smsCoordinator.startListenerIfPermitted();
      } catch (e) {
        debugPrint('AuthBootstrap background sync skipped: $e');
      }
    });

    // Overlay prefs sync much later — never fight Flutter DB on first launch.
    Future<void>.delayed(const Duration(seconds: 5), () async {
      try {
        await OverlayCacheService.syncFromLocalDatabase(force: false);
      } catch (e) {
        debugPrint('AuthBootstrap overlay cache skipped: $e');
      }
    });
  }

  static void reset(BuildContext context) {
    _didEssential = false;
    _didBackground = false;
    _bootstrappedUid = null;
    context.read<WalletCubit>().reset();
    context.read<AccountCubit>().reset();
    context.read<TransactionCubit>().reset();
    context.read<SavingsGoalCubit>().reset();
    context.read<SettingsCubit>().reset();
    context.read<DebtCubit>().reset();
    context.read<InvestmentCubit>().reset();
    context.read<PartialTransactionCubit>().reset();
    context.read<SmsCubit>().reset();
    context.read<MoneyPlanCubit>().reset();
    context.read<SmsCoordinatorService>().stopListener();
  }
}
