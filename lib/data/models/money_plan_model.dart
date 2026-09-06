import 'package:equatable/equatable.dart';

enum PlanPriority { critical, high, medium, low, flexible }

enum ExpenseKind { staticExpense, dynamicExpense, optionalExpense }

enum GoalStatus { onTrack, atRisk, offTrack, completed, paused }

enum GoalType { standard, gold, emergency, other }

enum InvestmentType {
  sip,
  stocks,
  mutualFunds,
  retirement,
  other,
}

enum ReallocationRuleAction { investment, emergency, goals, personal }

extension PlanPriorityX on PlanPriority {
  String get label {
    switch (this) {
      case PlanPriority.critical:
        return 'Critical';
      case PlanPriority.high:
        return 'High';
      case PlanPriority.medium:
        return 'Medium';
      case PlanPriority.low:
        return 'Low';
      case PlanPriority.flexible:
        return 'Flexible';
    }
  }

  int get rank {
    switch (this) {
      case PlanPriority.critical:
        return 0;
      case PlanPriority.high:
        return 1;
      case PlanPriority.medium:
        return 2;
      case PlanPriority.low:
        return 3;
      case PlanPriority.flexible:
        return 4;
    }
  }

  static PlanPriority fromString(String? value) {
    return PlanPriority.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PlanPriority.medium,
    );
  }
}

extension ExpenseKindX on ExpenseKind {
  String get label {
    switch (this) {
      case ExpenseKind.staticExpense:
        return 'Static';
      case ExpenseKind.dynamicExpense:
        return 'Dynamic';
      case ExpenseKind.optionalExpense:
        return 'Optional';
    }
  }

  static ExpenseKind fromString(String? value) {
    return ExpenseKind.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ExpenseKind.dynamicExpense,
    );
  }
}

extension GoalStatusX on GoalStatus {
  String get label {
    switch (this) {
      case GoalStatus.onTrack:
        return 'On Track';
      case GoalStatus.atRisk:
        return 'At Risk';
      case GoalStatus.offTrack:
        return 'Off Track';
      case GoalStatus.completed:
        return 'Completed';
      case GoalStatus.paused:
        return 'Paused';
    }
  }

  static GoalStatus fromString(String? value) {
    return GoalStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => GoalStatus.onTrack,
    );
  }
}

class PlanIncome extends Equatable {
  final double monthlyIncome;
  final double otherIncome;
  final String frequency;
  final double? minimumExpectedIncome;

  const PlanIncome({
    this.monthlyIncome = 0,
    this.otherIncome = 0,
    this.frequency = 'monthly',
    this.minimumExpectedIncome,
  });

  double get availableMonthlyIncome => monthlyIncome + otherIncome;

  double get annualIncome => availableMonthlyIncome * 12;

  PlanIncome copyWith({
    double? monthlyIncome,
    double? otherIncome,
    String? frequency,
    double? minimumExpectedIncome,
  }) {
    return PlanIncome(
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      otherIncome: otherIncome ?? this.otherIncome,
      frequency: frequency ?? this.frequency,
      minimumExpectedIncome:
          minimumExpectedIncome ?? this.minimumExpectedIncome,
    );
  }

  factory PlanIncome.fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return const PlanIncome();
    return PlanIncome(
      monthlyIncome: (json['monthly_income'] ?? 0).toDouble(),
      otherIncome: (json['other_income'] ?? 0).toDouble(),
      frequency: json['frequency'] ?? 'monthly',
      minimumExpectedIncome: json['minimum_expected_income'] != null
          ? (json['minimum_expected_income'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'monthly_income': monthlyIncome,
        'other_income': otherIncome,
        'frequency': frequency,
        'minimum_expected_income': minimumExpectedIncome,
      };

  @override
  List<Object?> get props =>
      [monthlyIncome, otherIncome, frequency, minimumExpectedIncome];
}

class PlanExpense extends Equatable {
  final String id;
  final String name;
  final double monthlyAmount;
  final double? minimumAmount;
  final double? normalAmount;
  final double? maximumAmount;
  final ExpenseKind kind;
  final bool isProtected;
  final PlanPriority priority;

  const PlanExpense({
    required this.id,
    required this.name,
    required this.monthlyAmount,
    this.minimumAmount,
    this.normalAmount,
    this.maximumAmount,
    this.kind = ExpenseKind.dynamicExpense,
    this.isProtected = false,
    this.priority = PlanPriority.high,
  });

  PlanExpense copyWith({
    String? id,
    String? name,
    double? monthlyAmount,
    double? minimumAmount,
    double? normalAmount,
    double? maximumAmount,
    ExpenseKind? kind,
    bool? isProtected,
    PlanPriority? priority,
  }) {
    return PlanExpense(
      id: id ?? this.id,
      name: name ?? this.name,
      monthlyAmount: monthlyAmount ?? this.monthlyAmount,
      minimumAmount: minimumAmount ?? this.minimumAmount,
      normalAmount: normalAmount ?? this.normalAmount,
      maximumAmount: maximumAmount ?? this.maximumAmount,
      kind: kind ?? this.kind,
      isProtected: isProtected ?? this.isProtected,
      priority: priority ?? this.priority,
    );
  }

  factory PlanExpense.fromJson(String id, Map<dynamic, dynamic> json) {
    return PlanExpense(
      id: id,
      name: json['name'] ?? '',
      monthlyAmount: (json['monthly_amount'] ?? 0).toDouble(),
      minimumAmount: json['minimum_amount'] != null
          ? (json['minimum_amount'] as num).toDouble()
          : null,
      normalAmount: json['normal_amount'] != null
          ? (json['normal_amount'] as num).toDouble()
          : null,
      maximumAmount: json['maximum_amount'] != null
          ? (json['maximum_amount'] as num).toDouble()
          : null,
      kind: ExpenseKindX.fromString(json['kind']),
      isProtected: json['is_protected'] ?? false,
      priority: PlanPriorityX.fromString(json['priority']),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'monthly_amount': monthlyAmount,
        'minimum_amount': minimumAmount,
        'normal_amount': normalAmount,
        'maximum_amount': maximumAmount,
        'kind': kind.name,
        'is_protected': isProtected,
        'priority': priority.name,
      };

  @override
  List<Object?> get props => [
        id,
        name,
        monthlyAmount,
        minimumAmount,
        normalAmount,
        maximumAmount,
        kind,
        isProtected,
        priority,
      ];
}

class PlanInvestment extends Equatable {
  final String id;
  final String name;
  final InvestmentType type;
  final double monthlyAmount;
  final double minimumAmount;
  final double? targetAmount;
  final bool isProtected;
  final PlanPriority priority;
  final String? notes;

  const PlanInvestment({
    required this.id,
    required this.name,
    this.type = InvestmentType.sip,
    required this.monthlyAmount,
    this.minimumAmount = 0,
    this.targetAmount,
    this.isProtected = true,
    this.priority = PlanPriority.critical,
    this.notes,
  });

  PlanInvestment copyWith({
    String? id,
    String? name,
    InvestmentType? type,
    double? monthlyAmount,
    double? minimumAmount,
    double? targetAmount,
    bool? isProtected,
    PlanPriority? priority,
    String? notes,
  }) {
    return PlanInvestment(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      monthlyAmount: monthlyAmount ?? this.monthlyAmount,
      minimumAmount: minimumAmount ?? this.minimumAmount,
      targetAmount: targetAmount ?? this.targetAmount,
      isProtected: isProtected ?? this.isProtected,
      priority: priority ?? this.priority,
      notes: notes ?? this.notes,
    );
  }

  factory PlanInvestment.fromJson(String id, Map<dynamic, dynamic> json) {
    return PlanInvestment(
      id: id,
      name: json['name'] ?? '',
      type: InvestmentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => InvestmentType.sip,
      ),
      monthlyAmount: (json['monthly_amount'] ?? 0).toDouble(),
      minimumAmount: (json['minimum_amount'] ?? 0).toDouble(),
      targetAmount: json['target_amount'] != null
          ? (json['target_amount'] as num).toDouble()
          : null,
      isProtected: json['is_protected'] ?? true,
      priority: PlanPriorityX.fromString(json['priority']),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        'monthly_amount': monthlyAmount,
        'minimum_amount': minimumAmount,
        'target_amount': targetAmount,
        'is_protected': isProtected,
        'priority': priority.name,
        'notes': notes,
      };

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        monthlyAmount,
        minimumAmount,
        targetAmount,
        isProtected,
        priority,
        notes,
      ];
}

class PlanEmergencyFund extends Equatable {
  final double currentSavings;
  final double monthlyEssentialExpenses;
  final int targetMonths;
  final double monthlyContribution;
  final bool isProtected;
  final PlanPriority priority;

  const PlanEmergencyFund({
    this.currentSavings = 0,
    this.monthlyEssentialExpenses = 0,
    this.targetMonths = 6,
    this.monthlyContribution = 0,
    this.isProtected = true,
    this.priority = PlanPriority.high,
  });

  double get targetAmount => monthlyEssentialExpenses * targetMonths;

  double get remainingAmount =>
      (targetAmount - currentSavings).clamp(0, double.infinity);

  double get progressPercentage {
    if (targetAmount <= 0) return 0;
    return (currentSavings / targetAmount * 100).clamp(0, 100);
  }

  bool get isComplete => currentSavings >= targetAmount && targetAmount > 0;

  /// Dynamic monthly need based on remaining months to fill (spread over targetMonths).
  double get requiredMonthlyContribution {
    if (isComplete || targetMonths <= 0) return 0;
    return remainingAmount / targetMonths;
  }

  PlanEmergencyFund copyWith({
    double? currentSavings,
    double? monthlyEssentialExpenses,
    int? targetMonths,
    double? monthlyContribution,
    bool? isProtected,
    PlanPriority? priority,
  }) {
    return PlanEmergencyFund(
      currentSavings: currentSavings ?? this.currentSavings,
      monthlyEssentialExpenses:
          monthlyEssentialExpenses ?? this.monthlyEssentialExpenses,
      targetMonths: targetMonths ?? this.targetMonths,
      monthlyContribution: monthlyContribution ?? this.monthlyContribution,
      isProtected: isProtected ?? this.isProtected,
      priority: priority ?? this.priority,
    );
  }

  factory PlanEmergencyFund.fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return const PlanEmergencyFund();
    return PlanEmergencyFund(
      currentSavings: (json['current_savings'] ?? 0).toDouble(),
      monthlyEssentialExpenses:
          (json['monthly_essential_expenses'] ?? 0).toDouble(),
      targetMonths: json['target_months'] ?? 6,
      monthlyContribution: (json['monthly_contribution'] ?? 0).toDouble(),
      isProtected: json['is_protected'] ?? true,
      priority: PlanPriorityX.fromString(json['priority']),
    );
  }

  Map<String, dynamic> toJson() => {
        'current_savings': currentSavings,
        'monthly_essential_expenses': monthlyEssentialExpenses,
        'target_months': targetMonths,
        'monthly_contribution': monthlyContribution,
        'is_protected': isProtected,
        'priority': priority.name,
      };

  @override
  List<Object?> get props => [
        currentSavings,
        monthlyEssentialExpenses,
        targetMonths,
        monthlyContribution,
        isProtected,
        priority,
      ];
}

class PlanGoldDetails extends Equatable {
  final double quantityTola;
  final double purity; // e.g. 22
  final double pricePerGram;
  final double additionalCharges;
  final double priceBufferPercent;
  final String priceSource; // market | manual | app | conservative

  const PlanGoldDetails({
    this.quantityTola = 1,
    this.purity = 22,
    this.pricePerGram = 0,
    this.additionalCharges = 0,
    this.priceBufferPercent = 5,
    this.priceSource = 'manual',
  });

  /// 1 tola ≈ 11.6638 grams
  double get quantityGrams => quantityTola * 11.6638;

  double get estimatedCost {
    final base = quantityGrams * pricePerGram + additionalCharges;
    return base * (1 + priceBufferPercent / 100);
  }

  PlanGoldDetails copyWith({
    double? quantityTola,
    double? purity,
    double? pricePerGram,
    double? additionalCharges,
    double? priceBufferPercent,
    String? priceSource,
  }) {
    return PlanGoldDetails(
      quantityTola: quantityTola ?? this.quantityTola,
      purity: purity ?? this.purity,
      pricePerGram: pricePerGram ?? this.pricePerGram,
      additionalCharges: additionalCharges ?? this.additionalCharges,
      priceBufferPercent: priceBufferPercent ?? this.priceBufferPercent,
      priceSource: priceSource ?? this.priceSource,
    );
  }

  factory PlanGoldDetails.fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return const PlanGoldDetails();
    return PlanGoldDetails(
      quantityTola: (json['quantity_tola'] ?? 1).toDouble(),
      purity: (json['purity'] ?? 22).toDouble(),
      pricePerGram: (json['price_per_gram'] ?? 0).toDouble(),
      additionalCharges: (json['additional_charges'] ?? 0).toDouble(),
      priceBufferPercent: (json['price_buffer_percent'] ?? 5).toDouble(),
      priceSource: json['price_source'] ?? 'manual',
    );
  }

  Map<String, dynamic> toJson() => {
        'quantity_tola': quantityTola,
        'purity': purity,
        'price_per_gram': pricePerGram,
        'additional_charges': additionalCharges,
        'price_buffer_percent': priceBufferPercent,
        'price_source': priceSource,
      };

  @override
  List<Object?> get props => [
        quantityTola,
        purity,
        pricePerGram,
        additionalCharges,
        priceBufferPercent,
        priceSource,
      ];
}

class PlanGoal extends Equatable {
  final String id;
  final String name;
  final GoalType goalType;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final PlanPriority priority;
  final double monthlyContribution;
  final bool isFlexible;
  final bool isPaused;
  final PlanGoldDetails? goldDetails;
  final String? notes;

  const PlanGoal({
    required this.id,
    required this.name,
    this.goalType = GoalType.standard,
    required this.targetAmount,
    this.currentAmount = 0,
    this.targetDate,
    this.priority = PlanPriority.medium,
    this.monthlyContribution = 0,
    this.isFlexible = true,
    this.isPaused = false,
    this.goldDetails,
    this.notes,
  });

  double get remainingAmount =>
      (effectiveTarget - currentAmount).clamp(0, double.infinity);

  double get effectiveTarget {
    if (goalType == GoalType.gold && goldDetails != null) {
      return goldDetails!.estimatedCost;
    }
    return targetAmount;
  }

  double get progressPercentage {
    if (effectiveTarget <= 0) return 0;
    return (currentAmount / effectiveTarget * 100).clamp(0, 100);
  }

  bool get isCompleted => currentAmount >= effectiveTarget && effectiveTarget > 0;

  int get remainingMonths {
    if (targetDate == null) return 1;
    final now = DateTime.now();
    final months = (targetDate!.year - now.year) * 12 +
        (targetDate!.month - now.month);
    return months < 1 ? 1 : months;
  }

  /// Required monthly = remaining ÷ months left (never a fixed forever amount).
  double get requiredMonthlyContribution {
    if (isCompleted || isPaused) return 0;
    return remainingAmount / remainingMonths;
  }

  GoalStatus get computedStatus {
    if (isPaused) return GoalStatus.paused;
    if (isCompleted) return GoalStatus.completed;
    final required = requiredMonthlyContribution;
    if (required <= 0) return GoalStatus.onTrack;
    final ratio = monthlyContribution / required;
    if (ratio >= 0.95) return GoalStatus.onTrack;
    if (ratio >= 0.7) return GoalStatus.atRisk;
    return GoalStatus.offTrack;
  }

  PlanGoal copyWith({
    String? id,
    String? name,
    GoalType? goalType,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    PlanPriority? priority,
    double? monthlyContribution,
    bool? isFlexible,
    bool? isPaused,
    PlanGoldDetails? goldDetails,
    String? notes,
  }) {
    return PlanGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      goalType: goalType ?? this.goalType,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      priority: priority ?? this.priority,
      monthlyContribution: monthlyContribution ?? this.monthlyContribution,
      isFlexible: isFlexible ?? this.isFlexible,
      isPaused: isPaused ?? this.isPaused,
      goldDetails: goldDetails ?? this.goldDetails,
      notes: notes ?? this.notes,
    );
  }

  factory PlanGoal.fromJson(String id, Map<dynamic, dynamic> json) {
    return PlanGoal(
      id: id,
      name: json['name'] ?? '',
      goalType: GoalType.values.firstWhere(
        (e) => e.name == json['goal_type'],
        orElse: () => GoalType.standard,
      ),
      targetAmount: (json['target_amount'] ?? 0).toDouble(),
      currentAmount: (json['current_amount'] ?? 0).toDouble(),
      targetDate: json['target_date'] != null
          ? DateTime.tryParse(json['target_date'])
          : null,
      priority: PlanPriorityX.fromString(json['priority']),
      monthlyContribution: (json['monthly_contribution'] ?? 0).toDouble(),
      isFlexible: json['is_flexible'] ?? true,
      isPaused: json['is_paused'] ?? false,
      goldDetails: json['gold_details'] != null
          ? PlanGoldDetails.fromJson(
              Map<dynamic, dynamic>.from(json['gold_details'] as Map),
            )
          : null,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'goal_type': goalType.name,
        'target_amount': targetAmount,
        'current_amount': currentAmount,
        'target_date': targetDate?.toIso8601String(),
        'priority': priority.name,
        'monthly_contribution': monthlyContribution,
        'is_flexible': isFlexible,
        'is_paused': isPaused,
        'gold_details': goldDetails?.toJson(),
        'notes': notes,
      };

  @override
  List<Object?> get props => [
        id,
        name,
        goalType,
        targetAmount,
        currentAmount,
        targetDate,
        priority,
        monthlyContribution,
        isFlexible,
        isPaused,
        goldDetails,
        notes,
      ];
}

class PlanDebt extends Equatable {
  final String id;
  final String name;
  final double principal;
  final double outstanding;
  final double interestRate;
  final double emi;
  final int remainingMonths;
  final DateTime? startDate;
  final DateTime? endDate;
  final double processingFees;
  final PlanPriority priority;
  final bool isMandatory;

  const PlanDebt({
    required this.id,
    required this.name,
    this.principal = 0,
    this.outstanding = 0,
    this.interestRate = 0,
    required this.emi,
    this.remainingMonths = 0,
    this.startDate,
    this.endDate,
    this.processingFees = 0,
    this.priority = PlanPriority.critical,
    this.isMandatory = true,
  });

  bool get isActive => remainingMonths > 0 && outstanding > 0;

  PlanDebt copyWith({
    String? id,
    String? name,
    double? principal,
    double? outstanding,
    double? interestRate,
    double? emi,
    int? remainingMonths,
    DateTime? startDate,
    DateTime? endDate,
    double? processingFees,
    PlanPriority? priority,
    bool? isMandatory,
  }) {
    return PlanDebt(
      id: id ?? this.id,
      name: name ?? this.name,
      principal: principal ?? this.principal,
      outstanding: outstanding ?? this.outstanding,
      interestRate: interestRate ?? this.interestRate,
      emi: emi ?? this.emi,
      remainingMonths: remainingMonths ?? this.remainingMonths,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      processingFees: processingFees ?? this.processingFees,
      priority: priority ?? this.priority,
      isMandatory: isMandatory ?? this.isMandatory,
    );
  }

  factory PlanDebt.fromJson(String id, Map<dynamic, dynamic> json) {
    return PlanDebt(
      id: id,
      name: json['name'] ?? '',
      principal: (json['principal'] ?? 0).toDouble(),
      outstanding: (json['outstanding'] ?? 0).toDouble(),
      interestRate: (json['interest_rate'] ?? 0).toDouble(),
      emi: (json['emi'] ?? 0).toDouble(),
      remainingMonths: json['remaining_months'] ?? 0,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'])
          : null,
      endDate:
          json['end_date'] != null ? DateTime.tryParse(json['end_date']) : null,
      processingFees: (json['processing_fees'] ?? 0).toDouble(),
      priority: PlanPriorityX.fromString(json['priority']),
      isMandatory: json['is_mandatory'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'principal': principal,
        'outstanding': outstanding,
        'interest_rate': interestRate,
        'emi': emi,
        'remaining_months': remainingMonths,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'processing_fees': processingFees,
        'priority': priority.name,
        'is_mandatory': isMandatory,
      };

  @override
  List<Object?> get props => [
        id,
        name,
        principal,
        outstanding,
        interestRate,
        emi,
        remainingMonths,
        startDate,
        endDate,
        processingFees,
        priority,
        isMandatory,
      ];
}

class PlanRule extends Equatable {
  final String id;
  final String name;
  final String description;
  final bool isActive;

  const PlanRule({
    required this.id,
    required this.name,
    required this.description,
    this.isActive = true,
  });

  factory PlanRule.fromJson(String id, Map<dynamic, dynamic> json) {
    return PlanRule(
      id: id,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'is_active': isActive,
      };

  @override
  List<Object?> get props => [id, name, description, isActive];
}

/// Master money plan document.
class MoneyPlanModel extends Equatable {
  final bool setupComplete;
  /// Day of month when the budget cycle resets (1–28). Example: 7 → 7th to next 7th.
  final int cycleStartDay;
  final PlanIncome income;
  final List<PlanExpense> expenses;
  final List<PlanInvestment> investments;
  final PlanEmergencyFund emergencyFund;
  final List<PlanGoal> goals;
  final List<PlanDebt> debts;
  final List<PlanRule> rules;
  final double personalSpending;
  final List<PlanExpense> personalCategories;
  final DateTime? updatedAt;

  const MoneyPlanModel({
    this.setupComplete = false,
    this.cycleStartDay = 1,
    this.income = const PlanIncome(),
    this.expenses = const [],
    this.investments = const [],
    this.emergencyFund = const PlanEmergencyFund(),
    this.goals = const [],
    this.debts = const [],
    this.rules = const [],
    this.personalSpending = 0,
    this.personalCategories = const [],
    this.updatedAt,
  });

  /// Personal budget used by the engine — subcategory sum when set up.
  double get personalBudget => personalCategories.isNotEmpty
      ? personalCategories.fold<double>(0, (s, e) => s + e.monthlyAmount)
      : personalSpending;

  MoneyPlanModel copyWith({
    bool? setupComplete,
    int? cycleStartDay,
    PlanIncome? income,
    List<PlanExpense>? expenses,
    List<PlanInvestment>? investments,
    PlanEmergencyFund? emergencyFund,
    List<PlanGoal>? goals,
    List<PlanDebt>? debts,
    List<PlanRule>? rules,
    double? personalSpending,
    List<PlanExpense>? personalCategories,
    DateTime? updatedAt,
  }) {
    return MoneyPlanModel(
      setupComplete: setupComplete ?? this.setupComplete,
      cycleStartDay: cycleStartDay ?? this.cycleStartDay,
      income: income ?? this.income,
      expenses: expenses ?? this.expenses,
      investments: investments ?? this.investments,
      emergencyFund: emergencyFund ?? this.emergencyFund,
      goals: goals ?? this.goals,
      debts: debts ?? this.debts,
      rules: rules ?? this.rules,
      personalSpending: personalSpending ?? this.personalSpending,
      personalCategories: personalCategories ?? this.personalCategories,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MoneyPlanModel.fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return const MoneyPlanModel();

    List<T> mapList<T>(
      dynamic raw,
      T Function(String id, Map<dynamic, dynamic> m) builder,
    ) {
      if (raw == null || raw is! Map) return [];
      final map = raw;
      return map.entries
          .map((e) => builder(
                e.key.toString(),
                Map<dynamic, dynamic>.from(e.value as Map),
              ))
          .toList();
    }

    return MoneyPlanModel(
      setupComplete: json['setup_complete'] ?? false,
      cycleStartDay: ((json['cycle_start_day'] as num?)?.toInt() ?? 1).clamp(1, 28),
      income: PlanIncome.fromJson(
        json['income'] != null
            ? Map<dynamic, dynamic>.from(json['income'] as Map)
            : null,
      ),
      expenses: mapList(json['expenses'], PlanExpense.fromJson),
      investments: mapList(json['investments'], PlanInvestment.fromJson),
      emergencyFund: PlanEmergencyFund.fromJson(
        json['emergency_fund'] != null
            ? Map<dynamic, dynamic>.from(json['emergency_fund'] as Map)
            : null,
      ),
      goals: mapList(json['goals'], PlanGoal.fromJson),
      debts: mapList(json['debts'], PlanDebt.fromJson),
      rules: mapList(json['rules'], PlanRule.fromJson),
      personalSpending: (json['personal_spending'] ?? 0).toDouble(),
      personalCategories:
          mapList(json['personal_categories'], PlanExpense.fromJson),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> listToMap(List items) {
      final map = <String, dynamic>{};
      for (final item in items) {
        if (item is PlanExpense) {
          map[item.id] = item.toJson();
        } else if (item is PlanInvestment) {
          map[item.id] = item.toJson();
        } else if (item is PlanGoal) {
          map[item.id] = item.toJson();
        } else if (item is PlanDebt) {
          map[item.id] = item.toJson();
        } else if (item is PlanRule) {
          map[item.id] = item.toJson();
        }
      }
      return map;
    }

    return {
      'setup_complete': setupComplete,
      'cycle_start_day': cycleStartDay.clamp(1, 28),
      'income': income.toJson(),
      'expenses': listToMap(expenses),
      'investments': listToMap(investments),
      'emergency_fund': emergencyFund.toJson(),
      'goals': listToMap(goals),
      'debts': listToMap(debts),
      'rules': listToMap(rules),
      'personal_spending': personalSpending,
      'personal_categories': listToMap(personalCategories),
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  static MoneyPlanModel starterTemplate({double monthlyIncome = 40000}) {
    final expenses = [
      PlanExpense(
        id: 'housing',
        name: 'Housing + utilities',
        monthlyAmount: monthlyIncome * 0.20,
        kind: ExpenseKind.staticExpense,
        isProtected: true,
        priority: PlanPriority.critical,
      ),
      PlanExpense(
        id: 'food',
        name: 'Food & Groceries',
        monthlyAmount: monthlyIncome * 0.175,
        kind: ExpenseKind.dynamicExpense,
        priority: PlanPriority.high,
      ),
      PlanExpense(
        id: 'transport',
        name: 'Transportation',
        monthlyAmount: monthlyIncome * 0.075,
        kind: ExpenseKind.dynamicExpense,
        priority: PlanPriority.medium,
      ),
    ];
    final essentials =
        expenses.fold<double>(0, (s, e) => s + e.monthlyAmount);

    return MoneyPlanModel(
      setupComplete: false,
      cycleStartDay: 1,
      income: PlanIncome(monthlyIncome: monthlyIncome),
      expenses: expenses,
      investments: [
        PlanInvestment(
          id: 'sip_main',
          name: 'SIP',
          type: InvestmentType.sip,
          monthlyAmount: monthlyIncome * 0.1875,
          minimumAmount: monthlyIncome * 0.1875,
          isProtected: true,
          priority: PlanPriority.critical,
        ),
      ],
      emergencyFund: PlanEmergencyFund(
        monthlyEssentialExpenses: essentials,
        targetMonths: 6,
        monthlyContribution: monthlyIncome * 0.10,
      ),
      personalSpending: monthlyIncome * 0.0875,
      rules: const [
        PlanRule(
          id: 'rule_sip',
          name: 'Protect SIP',
          description: 'Never reduce SIP below the protected minimum.',
        ),
        PlanRule(
          id: 'rule_emergency',
          name: 'Emergency floor',
          description: 'Keep at least a minimum monthly emergency contribution.',
        ),
        PlanRule(
          id: 'rule_emi_end',
          name: 'EMI reallocation',
          description:
              'When EMI ends, move 70% to investment and 30% to goals.',
        ),
      ],
    );
  }

  @override
  List<Object?> get props => [
        setupComplete,
        cycleStartDay,
        income,
        expenses,
        investments,
        emergencyFund,
        goals,
        debts,
        rules,
        personalSpending,
        personalCategories,
        updatedAt,
      ];
}
