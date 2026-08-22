import 'package:flutter/material.dart';

import '../../../core/database/local_app_database.dart';
import '../../../core/utils/onboarding_gate.dart';
import '../../theme/brand_colors.dart';
import '../money_planner/money_plan_setup_wizard.dart';
import 'onboarding_account_step.dart';
import 'onboarding_info_card.dart';
import 'onboarding_welcome_step.dart';

/// Shown once after first sign-in: welcome → accounts → monthly budget.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _totalSteps = 3;

  int _step = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolveStartStep();
  }

  Future<void> _resolveStartStep() async {
    final accounts = await LocalAppDatabase.instance.getAccounts();
    if (!mounted) return;
    setState(() {
      _step = accounts.isEmpty ? 0 : 2;
      _loading = false;
    });
  }

  Future<void> _skipAll() async {
    final skip = await confirmSkipOnboarding(context);
    if (skip && mounted) {
      await OnboardingGate.completeOnboarding(context);
    }
  }

  void _goToAccountStep() => setState(() => _step = 1);

  void _goToPlannerStep() => setState(() => _step = 2);

  Future<void> _finishOnboarding() async {
    await OnboardingGate.completeOnboarding(context);
  }

  String get _stepLabel {
    switch (_step) {
      case 0:
        return 'Getting started';
      case 1:
        return 'Step 2 of $_totalSteps · Accounts';
      default:
        return 'Step $_totalSteps of $_totalSteps · Monthly budget';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: BrandColors.washGradient),
          child: SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _OnboardingProgress(
                                  step: _step + 1,
                                  total: _totalSteps,
                                  label: _stepLabel,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _skipAll,
                              child: const Text('Skip'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: IndexedStack(
                          index: _step,
                          children: [
                            OnboardingWelcomeStep(
                              onGetStarted: _goToAccountStep,
                              onSkip: _skipAll,
                            ),
                            OnboardingAccountStep(
                              onContinue: _goToPlannerStep,
                              onSkip: _goToPlannerStep,
                            ),
                            MoneyPlanSetupWizard(
                              isOnboarding: true,
                              onFinished: _finishOnboarding,
                              onSkipped: _skipAll,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingProgress extends StatelessWidget {
  final int step;
  final int total;
  final String label;

  const _OnboardingProgress({
    required this.step,
    required this.total,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to Arthigo',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: BrandColors.navy,
              ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: BrandColors.muted, fontSize: 13)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: step / total,
            minHeight: 6,
            backgroundColor: BrandColors.blue.withOpacity(0.12),
            valueColor: const AlwaysStoppedAnimation(BrandColors.blue),
          ),
        ),
      ],
    );
  }
}
