import 'package:equatable/equatable.dart';

enum InvestmentType { mutualFund, fixedDeposit, stocks, gold, bonds, other }

class InvestmentModel extends Equatable {
  final String id;
  final InvestmentType type;
  final String name; // e.g., "SBI Mutual Fund", "HDFC FD"
  final double investedAmount;
  final double currentValue;
  final DateTime purchaseDate;
  final DateTime? maturityDate;
  final double? interestRate; // Annual interest rate
  final String? description;
  final String? account; // Linked account name
  final String? note;

  const InvestmentModel({
    required this.id,
    required this.type,
    required this.name,
    required this.investedAmount,
    required this.currentValue,
    required this.purchaseDate,
    this.maturityDate,
    this.interestRate,
    this.description,
    this.account,
    this.note,
  });

  double get profit => currentValue - investedAmount;
  double get profitPercentage => investedAmount > 0
      ? ((currentValue - investedAmount) / investedAmount * 100)
      : 0;
  bool get isMatured => maturityDate != null && DateTime.now().isAfter(maturityDate!);
  int? get daysToMaturity => maturityDate != null
      ? maturityDate!.difference(DateTime.now()).inDays
      : null;

  factory InvestmentModel.fromJson(String id, Map<dynamic, dynamic> json) {
    return InvestmentModel(
      id: id,
      type: _parseInvestmentType(json['type'] ?? 'mutual_fund'),
      name: json['name'] ?? '',
      investedAmount: (json['invested_amount'] ?? 0).toDouble(),
      currentValue: (json['current_value'] ?? 0).toDouble(),
      purchaseDate: json['purchase_date'] != null
          ? DateTime.parse(json['purchase_date'])
          : DateTime.now(),
      maturityDate: json['maturity_date'] != null
          ? DateTime.parse(json['maturity_date'])
          : null,
      interestRate: json['interest_rate'] != null
          ? (json['interest_rate']).toDouble()
          : null,
      description: json['description'],
      account: json['account'],
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'type': _investmentTypeToString(type),
      'name': name,
      'invested_amount': investedAmount,
      'current_value': currentValue,
      'purchase_date': purchaseDate.toIso8601String(),
      'maturity_date': maturityDate?.toIso8601String(),
      'interest_rate': interestRate,
      'description': description,
      'account': account,
      'note': note,
    };
    // Don't include ID - Firebase key is the ID
    return json;
  }

  static InvestmentType _parseInvestmentType(String type) {
    switch (type) {
      case 'mutual_fund':
        return InvestmentType.mutualFund;
      case 'fixed_deposit':
        return InvestmentType.fixedDeposit;
      case 'stocks':
        return InvestmentType.stocks;
      case 'gold':
        return InvestmentType.gold;
      case 'bonds':
        return InvestmentType.bonds;
      default:
        return InvestmentType.other;
    }
  }

  static String _investmentTypeToString(InvestmentType type) {
    switch (type) {
      case InvestmentType.mutualFund:
        return 'mutual_fund';
      case InvestmentType.fixedDeposit:
        return 'fixed_deposit';
      case InvestmentType.stocks:
        return 'stocks';
      case InvestmentType.gold:
        return 'gold';
      case InvestmentType.bonds:
        return 'bonds';
      case InvestmentType.other:
        return 'other';
    }
  }

  InvestmentModel copyWith({
    String? id,
    InvestmentType? type,
    String? name,
    double? investedAmount,
    double? currentValue,
    DateTime? purchaseDate,
    DateTime? maturityDate,
    double? interestRate,
    String? description,
    String? account,
    String? note,
  }) {
    return InvestmentModel(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      investedAmount: investedAmount ?? this.investedAmount,
      currentValue: currentValue ?? this.currentValue,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      maturityDate: maturityDate ?? this.maturityDate,
      interestRate: interestRate ?? this.interestRate,
      description: description ?? this.description,
      account: account ?? this.account,
      note: note ?? this.note,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        name,
        investedAmount,
        currentValue,
        purchaseDate,
        maturityDate,
        interestRate,
        description,
        account,
        note,
      ];
}

