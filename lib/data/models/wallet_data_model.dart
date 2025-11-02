import 'package:equatable/equatable.dart';

class WalletDataModel extends Equatable {
  final double totalBalance;
  final double totalIncome;
  final double totalExpense;
  final double monthlyIncome;
  final double monthlyExpense;

  const WalletDataModel({
    required this.totalBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.monthlyIncome,
    required this.monthlyExpense,
  });

  factory WalletDataModel.fromJson(Map<dynamic, dynamic> json) {
    return WalletDataModel(
      totalBalance: (json['total_balance'] ?? 0).toDouble(),
      totalIncome: (json['total_income'] ?? 0).toDouble(),
      totalExpense: (json['total_expense'] ?? 0).toDouble(),
      monthlyIncome: (json['monthly_income'] ?? 0).toDouble(),
      monthlyExpense: (json['monthly_expense'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_balance': totalBalance,
      'total_income': totalIncome,
      'total_expense': totalExpense,
      'monthly_income': monthlyIncome,
      'monthly_expense': monthlyExpense,
    };
  }

  WalletDataModel copyWith({
    double? totalBalance,
    double? totalIncome,
    double? totalExpense,
    double? monthlyIncome,
    double? monthlyExpense,
  }) {
    return WalletDataModel(
      totalBalance: totalBalance ?? this.totalBalance,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpense: totalExpense ?? this.totalExpense,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      monthlyExpense: monthlyExpense ?? this.monthlyExpense,
    );
  }

  @override
  List<Object?> get props => [
        totalBalance,
        totalIncome,
        totalExpense,
        monthlyIncome,
        monthlyExpense,
      ];
}

