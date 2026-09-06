import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/cubits/money_plan_cubit.dart';
import '../../presentation/theme/brand_colors.dart';
import 'budget_cycle.dart';

/// Lets the user change which day the budget month starts (1–28).
Future<int?> showBudgetMonthDayEditor(
  BuildContext context, {
  required int currentDay,
}) async {
  var selected = BudgetCycle.normalizeDay(currentDay);

  final result = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final preview = BudgetCycle.containing(DateTime.now(), selected);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Budget month start day',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: BrandColors.navy,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pick the day each money-plan month begins. '
                    'Example: day 7 runs from the 7th to the next 7th.',
                    style: TextStyle(
                      color: BrandColors.muted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selected,
                    decoration: InputDecoration(
                      labelText: 'Starts on day',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      for (var d = 1; d <= 28; d++)
                        DropdownMenuItem(
                          value: d,
                          child: Text(
                            d == 1
                                ? '1 · Calendar month (1st–end)'
                                : '$d · $d${_suffix(d)} → next month $d${_suffix(d)}',
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setModalState(() => selected = v);
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: BrandColors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: BrandColors.blue.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current period preview',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: BrandColors.navy,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preview.labelForDay(selected),
                          style: const TextStyle(
                            color: BrandColors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, selected),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Save month start day',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  return result;
}

String _suffix(int day) {
  if (day >= 11 && day <= 13) return 'th';
  switch (day % 10) {
    case 1:
      return 'st';
    case 2:
      return 'nd';
    case 3:
      return 'rd';
    default:
      return 'th';
  }
}

/// Opens the editor and persists via [MoneyPlanCubit] when confirmed.
Future<bool> editAndSaveBudgetMonthDay(
  BuildContext context, {
  required int currentDay,
}) async {
  final next = await showBudgetMonthDayEditor(
    context,
    currentDay: currentDay,
  );
  if (next == null || !context.mounted) return false;
  await context.read<MoneyPlanCubit>().updateCycleStartDay(next);
  if (!context.mounted) return true;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        next == 1
            ? 'Budget month uses the calendar month'
            : 'Budget month now starts on day $next',
      ),
      backgroundColor: Colors.green,
    ),
  );
  return true;
}
