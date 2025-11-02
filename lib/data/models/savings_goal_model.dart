import 'package:equatable/equatable.dart';

class SavingsGoalModel extends Equatable {
  final String id;
  final String name;
  final double targetAmount;
  final double monthlyIncome;
  final double monthlyExpense;
  final int timePeriodMonths;
  final double savedSoFar;
  final DateTime createdDate;
  final DateTime? targetDate;

  const SavingsGoalModel({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.timePeriodMonths,
    required this.savedSoFar,
    required this.createdDate,
    this.targetDate,
  });

  double get savingsPerMonth {
    if (timePeriodMonths == 0) return 0;
    return (targetAmount - savedSoFar) / timePeriodMonths;
  }

  double get progressPercentage {
    if (targetAmount == 0) return 0;
    return (savedSoFar / targetAmount * 100).clamp(0, 100);
  }

  double get remainingAmount => (targetAmount - savedSoFar).clamp(0, double.infinity);

  bool get isCompleted => savedSoFar >= targetAmount;

  factory SavingsGoalModel.fromJson(String id, Map<dynamic, dynamic> json) {
    return SavingsGoalModel(
      id: id,
      name: json['name'] ?? '',
      targetAmount: (json['target_amount'] ?? 0).toDouble(),
      monthlyIncome: (json['monthly_income'] ?? 0).toDouble(),
      monthlyExpense: (json['monthly_expense'] ?? 0).toDouble(),
      timePeriodMonths: json['time_period'] ?? 0,
      savedSoFar: (json['saved_so_far'] ?? 0).toDouble(),
      createdDate: json['created_date'] != null
          ? DateTime.parse(json['created_date'])
          : DateTime.now(),
      targetDate: json['target_date'] != null
          ? DateTime.parse(json['target_date'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'target_amount': targetAmount,
      'monthly_income': monthlyIncome,
      'monthly_expense': monthlyExpense,
      'time_period': timePeriodMonths,
      'saved_so_far': savedSoFar,
      'created_date': createdDate.toIso8601String(),
      'target_date': targetDate?.toIso8601String(),
    };
  }

  SavingsGoalModel copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? monthlyIncome,
    double? monthlyExpense,
    int? timePeriodMonths,
    double? savedSoFar,
    DateTime? createdDate,
    DateTime? targetDate,
  }) {
    return SavingsGoalModel(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      monthlyExpense: monthlyExpense ?? this.monthlyExpense,
      timePeriodMonths: timePeriodMonths ?? this.timePeriodMonths,
      savedSoFar: savedSoFar ?? this.savedSoFar,
      createdDate: createdDate ?? this.createdDate,
      targetDate: targetDate ?? this.targetDate,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        targetAmount,
        monthlyIncome,
        monthlyExpense,
        timePeriodMonths,
        savedSoFar,
        createdDate,
        targetDate,
      ];
}

