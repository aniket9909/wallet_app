import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/database/local_app_database.dart';
import '../../data/models/account_model.dart';
import '../../data/models/money_plan_model.dart';
import '../../data/models/settings_model.dart';
import '../../logic/cubits/settings_cubit.dart';
import '../../routes/app_routes.dart';

/// First-run flow: add account → monthly budget planner.
class OnboardingGate {
  static Future<void> navigateAfterAuth(BuildContext context) async {
    final showOnboarding = await shouldShowOnboarding(context);
    if (!context.mounted) return;

    if (showOnboarding) {
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  static Future<bool> shouldShowOnboarding(BuildContext context) async {
    final db = LocalAppDatabase.instance;
    final settings = await db.loadSettings();
    if (settings?.onboardingComplete == true) return false;

    final results = await Future.wait([
      db.getAccounts(),
      db.loadMoneyPlan(),
    ]);
    final accounts = results[0] as List<AccountModel>;
    final plan = results[1] as MoneyPlanModel?;

    final hasAccounts = accounts.isNotEmpty;
    final hasPlanner = plan?.setupComplete ?? false;

    if (hasAccounts && hasPlanner) {
      await _markComplete(context, settings);
      return false;
    }

    return true;
  }

  static Future<void> completeOnboarding(BuildContext context) async {
    await _markComplete(context, await LocalAppDatabase.instance.loadSettings());
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  static Future<void> _markComplete(
    BuildContext context,
    SettingsModel? settings,
  ) async {
    final base = settings ??
        const SettingsModel(
          notificationsEnabled: true,
          expenseTypes: [
            'Food',
            'Bills',
            'Shopping',
            'Travel',
            'Entertainment',
            'Health',
            'Other',
          ],
          profile: UserProfile(name: '', email: ''),
        );

    if (base.onboardingComplete) return;

    await context.read<SettingsCubit>().updateSettings(
          base.copyWith(onboardingComplete: true),
        );
  }
}
