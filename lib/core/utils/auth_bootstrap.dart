import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/sms_repository.dart';
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

/// Runs Firebase user setup and reloads all data streams after sign-in / register.
class AuthBootstrap {
  static Future<bool> setup(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('AuthBootstrap: no signed-in user');
      return false;
    }

    try {
      // Ensure Firebase Auth token is ready before RTDB reads/writes.
      await user.getIdToken(true);

      final firebase = context.read<FirebaseRealtimeService>();
      await LocalAppDatabase.instance.database;
      await firebase.initializeUserData();
      await OfflineSyncService.instance.flush(firebase);

      context.read<WalletCubit>().loadWallet();
      context.read<AccountCubit>().loadAccounts();
      context.read<TransactionCubit>().loadTransactions();
      context.read<SavingsGoalCubit>().loadGoals();
      context.read<SettingsCubit>().loadSettings();
      context.read<DebtCubit>().loadDebts();
      context.read<InvestmentCubit>().loadInvestments();
      context.read<PartialTransactionCubit>().loadPartialTransactions();
      context.read<SmsCubit>().loadAllSms();
      context.read<MoneyPlanCubit>().loadPlan();

      await context.read<SmsCoordinatorService>().startListenerIfPermitted();
      await _syncLocalSmsIfAny(context);
      await OverlayCacheService.syncFromLocalDatabase();

      debugPrint('AuthBootstrap: setup complete for uid=${user.uid}');
      return true;
    } catch (e, st) {
      debugPrint('AuthBootstrap failed: $e\n$st');
      return false;
    }
  }

  static Future<void> _syncLocalSmsIfAny(BuildContext context) async {
    try {
      final smsRepo = context.read<SmsRepository>();
      final allSms = await smsRepo.getAllSms();
      if (allSms.isNotEmpty) {
        await smsRepo.syncAllToFirebase(allSms);
      }
    } catch (e) {
      debugPrint('AuthBootstrap SMS sync skipped: $e');
    }
  }

  static void reset(BuildContext context) {
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
