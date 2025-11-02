import 'package:equatable/equatable.dart';

enum TransactionType { credit, debit }

class TransactionModelNew extends Equatable {
  final String id;
  final TransactionType type;
  final double amount;
  final String description;
  final String category;
  final String account;
  final DateTime date;
  final String? note;

  const TransactionModelNew({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.category,
    required this.account,
    required this.date,
    this.note,
  });

  factory TransactionModelNew.fromJson(String id, Map<dynamic, dynamic> json) {
    return TransactionModelNew(
      id: id,
      type: json['type'] == 'credit' ? TransactionType.credit : TransactionType.debit,
      amount: (json['amount'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      account: json['account'] ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type == TransactionType.credit ? 'credit' : 'debit',
      'amount': amount,
      'description': description,
      'category': category,
      'account': account,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  TransactionModelNew copyWith({
    String? id,
    TransactionType? type,
    double? amount,
    String? description,
    String? category,
    String? account,
    DateTime? date,
    String? note,
  }) {
    return TransactionModelNew(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      category: category ?? this.category,
      account: account ?? this.account,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  @override
  List<Object?> get props => [id, type, amount, description, category, account, date, note];
}

