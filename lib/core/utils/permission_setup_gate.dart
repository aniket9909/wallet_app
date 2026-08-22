import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/database/local_app_database.dart';
import '../../data/models/settings_model.dart';
import '../../logic/cubits/settings_cubit.dart';
import '../../routes/app_routes.dart';
import 'onboarding_gate.dart';

class PermissionSetupGate {
  static Future<void> navigateAfterAuth(BuildContext context) async {
    if (await shouldShow(context)) {
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.permissions);
      return;
    }
    await OnboardingGate.navigateAfterAuth(context);
  }

  static Future<bool> shouldShow(BuildContext context) async {
    if (!Platform.isAndroid) return false;

    final settings = await LocalAppDatabase.instance.loadSettings();
    if (settings?.permissionsSetupComplete == true) return false;

    final sms = await Permission.sms.status;
    if (sms.isGranted) {
      await _markComplete(context, settings);
      return false;
    }

    return true;
  }

  static Future<void> completeAndContinue(BuildContext context) async {
    await _markComplete(
      context,
      await LocalAppDatabase.instance.loadSettings(),
    );
    if (!context.mounted) return;
    await OnboardingGate.navigateAfterAuth(context);
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

    if (base.permissionsSetupComplete) return;

    await context.read<SettingsCubit>().updateSettings(
          base.copyWith(permissionsSetupComplete: true),
        );
  }
}
