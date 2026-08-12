import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/services/money_plan_engine.dart';

final moneyInr = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

class AllocationDonut extends StatelessWidget {
  final List<AllocationSlice> slices;
  final double size;
  final VoidCallback? onTap;

  const AllocationDonut({
    super.key,
    required this.slices,
    this.size = 180,
    this.onTap,
  });

  static const _colors = [
    Color(0xFF0B4FBF),
    Color(0xFF2ECC71),
    Color(0xFF00B8C4),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
  ];

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (s, e) => s + e.amount);
    if (total <= 0) {
      return SizedBox(
        height: size,
        child: Center(
          child: Text(
            'No allocations yet',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: size,
        width: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: size * 0.28,
                sections: [
                  for (var i = 0; i < slices.length; i++)
                    PieChartSectionData(
                      value: slices[i].amount,
                      color: _colors[i % _colors.length],
                      radius: size * 0.18,
                      title: '${slices[i].percentage.toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Where money goes',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '100%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Color colorFor(int index) => _colors[index % _colors.length];
}

class PlanMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const PlanMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
                if (onTap != null)
                  Icon(Icons.chevron_right, size: 18, color: Colors.grey[500]),
              ],
            ),
            const Spacer(),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SuggestionBanner extends StatelessWidget {
  final ReallocationSuggestion suggestion;
  final VoidCallback onApply;
  final VoidCallback onDismiss;
  final VoidCallback? onEdit;

  const SuggestionBanner({
    super.key,
    required this.suggestion,
    required this.onApply,
    required this.onDismiss,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  suggestion.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          Text(
            suggestion.description,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
          if (suggestion.allocations.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...suggestion.allocations.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${e.key}: ${moneyInr.format(e.value)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (suggestion.allocations.isNotEmpty)
                FilledButton(
                  onPressed: onApply,
                  child: const Text('Apply'),
                ),
              if (suggestion.allocations.isNotEmpty) const SizedBox(width: 8),
              if (onEdit != null)
                OutlinedButton(
                  onPressed: onEdit,
                  child: const Text('Edit'),
                ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onDismiss,
                child: const Text('Keep current plan'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BudgetConflictCard extends StatelessWidget {
  final BudgetConflict conflict;

  const BudgetConflictCard({super.key, required this.conflict});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Budget conflict',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your goals exceed your available monthly budget.',
            style: TextStyle(color: Colors.grey[800]),
          ),
          const SizedBox(height: 8),
          Text('Required: ${moneyInr.format(conflict.required)}'),
          Text('Available: ${moneyInr.format(conflict.available)}'),
          Text(
            'Shortfall: ${moneyInr.format(conflict.shortfall)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          if (conflict.affectedItems.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Affected: ${conflict.affectedItems.join(', ')}'),
          ],
          const SizedBox(height: 8),
          const Text(
            'Suggested solutions',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          ...conflict.suggestions.map(
            (s) => Text('• $s', style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
