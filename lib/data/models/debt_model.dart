import 'package:equatable/equatable.dart';

enum DebtType { borrow, lend }

class DebtModel extends Equatable {
  final String id;
  final DebtType type; // borrow = you owe someone, lend = someone owes you
  final String personName;
  final double amount;
  final double paidAmount;
  final String description;
  final DateTime date;
  final DateTime? dueDate;
  final String? note;
  final bool isPaid;

  const DebtModel({
    required this.id,
    required this.type,
    required this.personName,
    required this.amount,
    required this.paidAmount,
    required this.description,
    required this.date,
    this.dueDate,
    this.note,
    this.isPaid = false,
  });

  double get remainingAmount => (amount - paidAmount).clamp(0, double.infinity);
  double get progressPercentage => amount > 0 ? (paidAmount / amount * 100).clamp(0, 100) : 0;
  bool get isOverdue => dueDate != null && DateTime.now().isAfter(dueDate!) && !isPaid;

  factory DebtModel.fromJson(String id, Map<dynamic, dynamic> json) {
    return DebtModel(
      id: id,
      type: json['type'] == 'borrow' ? DebtType.borrow : DebtType.lend,
      personName: json['person_name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      paidAmount: (json['paid_amount'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      note: json['note'],
      isPaid: json['is_paid'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'type': type == DebtType.borrow ? 'borrow' : 'lend',
      'person_name': personName,
      'amount': amount,
      'paid_amount': paidAmount,
      'description': description,
      'date': date.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'note': note,
      'is_paid': isPaid,
    };
    // Don't include ID - Firebase key is the ID
    return json;
  }

  DebtModel copyWith({
    String? id,
    DebtType? type,
    String? personName,
    double? amount,
    double? paidAmount,
    String? description,
    DateTime? date,
    DateTime? dueDate,
    String? note,
    bool? isPaid,
  }) {
    return DebtModel(
      id: id ?? this.id,
      type: type ?? this.type,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      paidAmount: paidAmount ?? this.paidAmount,
      description: description ?? this.description,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      note: note ?? this.note,
      isPaid: isPaid ?? this.isPaid,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        personName,
        amount,
        paidAmount,
        description,
        date,
        dueDate,
        note,
        isPaid,
      ];
}

