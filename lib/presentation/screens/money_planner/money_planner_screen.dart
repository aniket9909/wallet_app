import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/planner_navigation.dart';
import '../../../logic/cubits/money_plan_cubit.dart';
import 'money_plan_dashboard.dart';
import 'money_plan_setup_wizard.dart';
import 'monthly_tracker_screen.dart';

/// Replaces the old Smart Savings hub with the All-in-One Money Planner.
class MoneyPlannerScreen extends StatelessWidget {
  const MoneyPlannerScreen({super.key});

  Future<void> _confirmRerunSetup(
    BuildContext context,
    MoneyPlanLoaded loaded,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Re-run full setup?'),
        content: const Text(
          'Opens the setup wizard again. Prefer Edit for changing amounts on the current plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Re-run setup'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<MoneyPlanCubit>().savePlan(
            loaded.plan.copyWith(setupComplete: false),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primary.withOpacity(0.05),
              Theme.of(context).colorScheme.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: BlocBuilder<MoneyPlanCubit, MoneyPlanState>(
            builder: (context, state) {
              if (state is MoneyPlanLoading || state is MoneyPlanInitial) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is MoneyPlanError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.message, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () =>
                              context.read<MoneyPlanCubit>().loadPlan(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final loaded = state is MoneyPlanLoaded ? state : null;
              final needsSetup =
                  loaded == null || !loaded.plan.setupComplete;

              if (needsSetup) {
                return const MoneyPlanSetupWizard();
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Money Planner',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => showPlannerEditSheet(context),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit'),
                        ),
                        IconButton(
                          tooltip: 'Monthly Tracker',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MonthlyTrackerScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.calendar_month_outlined),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'More',
                          onSelected: (value) {
                            if (value == 'rerun') {
                              _confirmRerunSetup(context, loaded);
                            }
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(
                              value: 'rerun',
                              child: Text('Re-run full setup…'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                  const Expanded(child: MoneyPlanDashboard()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
