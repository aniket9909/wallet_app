/// Budget month cycle based on a chosen day of month (e.g. 7 → 7th to next 7th).
class BudgetCycle {
  /// Inclusive start of the cycle (usually the salary / reset day).
  final DateTime start;

  /// Exclusive end of the cycle (next cycle start).
  final DateTime endExclusive;

  const BudgetCycle({
    required this.start,
    required this.endExclusive,
  });

  Duration get duration => endExclusive.difference(start);

  bool contains(DateTime date) =>
      !date.isBefore(start) && date.isBefore(endExclusive);

  bool get isCurrent {
    final now = DateTime.now();
    return contains(now);
  }

  bool isPast({DateTime? now}) {
    final today = now ?? DateTime.now();
    return !today.isBefore(endExclusive);
  }

  /// Display label like "7 Feb – 6 Mar 2026".
  String get label {
    final lastDay = endExclusive.subtract(const Duration(days: 1));
    final sameYear = start.year == lastDay.year;
    final startFmt = _fmt(start, includeYear: !sameYear);
    final endFmt = _fmt(lastDay, includeYear: true);
    return '$startFmt – $endFmt';
  }

  /// Short label for dropdowns when day is 1: "February 2026", else full range.
  String labelForDay(int cycleStartDay) {
    if (cycleStartDay <= 1) {
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[start.month - 1]} ${start.year}';
    }
    return label;
  }

  static String _fmt(DateTime d, {required bool includeYear}) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final base = '${d.day} ${months[d.month - 1]}';
    return includeYear ? '$base ${d.year}' : base;
  }

  /// Clamp [day] into a valid day for [year]/[month].
  static DateTime dateOnOrBefore(int year, int month, int day) {
    final last = DateTime(year, month + 1, 0).day;
    final d = day.clamp(1, last);
    return DateTime(year, month, d);
  }

  /// Normalize stored day to 1–28 so every month has that day.
  static int normalizeDay(int day) => day.clamp(1, 28);

  /// Cycle that contains [now] for the given reset day.
  ///
  /// Example day=7 on Mar 10 → Mar 7 → Apr 7.
  /// Example day=7 on Mar 3 → Feb 7 → Mar 7.
  static BudgetCycle containing(DateTime now, int cycleStartDay) {
    final day = normalizeDay(cycleStartDay);
    final thisStart = dateOnOrBefore(now.year, now.month, day);
    if (!now.isBefore(thisStart)) {
      final nextStart = dateOnOrBefore(now.year, now.month + 1, day);
      return BudgetCycle(start: thisStart, endExclusive: nextStart);
    }
    final prevStart = dateOnOrBefore(now.year, now.month - 1, day);
    return BudgetCycle(start: prevStart, endExclusive: thisStart);
  }

  /// Cycle identified by its start date (for pickers).
  static BudgetCycle fromStart(DateTime start, int cycleStartDay) {
    final day = normalizeDay(cycleStartDay);
    final s = dateOnOrBefore(start.year, start.month, day);
    final end = dateOnOrBefore(s.year, s.month + 1, day);
    return BudgetCycle(start: s, endExclusive: end);
  }

  /// Previous / next cycle starts for navigation.
  BudgetCycle previous(int cycleStartDay) {
    final day = normalizeDay(cycleStartDay);
    final prevStart = dateOnOrBefore(start.year, start.month - 1, day);
    return fromStart(prevStart, day);
  }

  BudgetCycle next(int cycleStartDay) {
    final day = normalizeDay(cycleStartDay);
    return fromStart(endExclusive, day);
  }

  static List<BudgetCycle> availableCycles({
    required int cycleStartDay,
    required List<DateTime> transactionDates,
    DateTime? now,
    int count = 12,
  }) {
    final day = normalizeDay(cycleStartDay);
    final today = now ?? DateTime.now();
    final current = containing(today, day);
    final map = <String, BudgetCycle>{
      _key(current.start): current,
    };

    var cursor = current;
    for (var i = 1; i < count; i++) {
      cursor = cursor.previous(day);
      map[_key(cursor.start)] = cursor;
    }

    for (final d in transactionDates) {
      final c = containing(d, day);
      map[_key(c.start)] = c;
    }

    final list = map.values.toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    return list;
  }

  static String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

  @override
  bool operator ==(Object other) =>
      other is BudgetCycle &&
      other.start == start &&
      other.endExclusive == endExclusive;

  @override
  int get hashCode => Object.hash(start, endExclusive);
}
