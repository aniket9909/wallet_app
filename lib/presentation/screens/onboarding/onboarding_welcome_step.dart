import 'package:flutter/material.dart';
import '../../theme/brand_colors.dart';
import 'onboarding_info_card.dart';

class OnboardingWelcomeStep extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onSkip;

  const OnboardingWelcomeStep({
    super.key,
    required this.onGetStarted,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: BrandAppIcon(size: 96)),
                const SizedBox(height: 24),
                Text(
                  'Set up Arthigo',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: BrandColors.navy,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Two quick steps to track money smarter. Tap each card to see what happens.',
                  style: TextStyle(color: BrandColors.muted, height: 1.4),
                ),
                const SizedBox(height: 24),
                const OnboardingInfoCard(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: BrandColors.blue,
                  title: '1 · Add an account',
                  body:
                      'Link your bank, UPI, or cash wallet. Current balance is optional — you can leave it blank and update later.',
                  onTapHint:
                      'Tap Continue → saves your account and opens the budget step.',
                ),
                const OnboardingInfoCard(
                  icon: Icons.pie_chart_outline,
                  iconColor: BrandColors.cyan,
                  title: '2 · Monthly budget',
                  body:
                      'Plan where your income goes — essentials, savings, goals, and debt. Compare planned vs actual on Home.',
                  onTapHint:
                      'Tap Finish → unlocks dashboard charts and “where money goes” view.',
                ),
                const OnboardingInfoCard(
                  icon: Icons.home_outlined,
                  iconColor: BrandColors.green,
                  title: '3 · Home dashboard',
                  body:
                      'See balance, this month’s transactions, and budget progress in one place.',
                  onTapHint:
                      'Tap Skip for now → go straight to Home; finish setup later from Accounts or Planner.',
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: onGetStarted,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Get started',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onSkip,
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
