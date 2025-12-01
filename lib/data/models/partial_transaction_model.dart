import 'package:equatable/equatable.dart';
import 'transaction_model_new.dart';

class PartialTransaction extends Equatable {
  final String id; // sms id or generated
  final String accountName;
  final double amount;
  final TransactionType type;
  final String description;
  final DateTime date;
  final String smsBody;
  final String matchedDigits;
  final bool seen; // Track if user has seen this transaction

  const PartialTransaction({
    required this.id,
    required this.accountName,
    required this.amount,
    required this.type,
    required this.description,
    required this.date,
    required this.smsBody,
    required this.matchedDigits,
    this.seen = false,
  });

  PartialTransaction copyWith({
    String? id,
    String? accountName,
    double? amount,
    TransactionType? type,
    String? description,
    DateTime? date,
    String? smsBody,
    String? matchedDigits,
    bool? seen,
  }) {
    return PartialTransaction(
      id: id ?? this.id,
      accountName: accountName ?? this.accountName,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      description: description ?? this.description,
      date: date ?? this.date,
      smsBody: smsBody ?? this.smsBody,
      matchedDigits: matchedDigits ?? this.matchedDigits,
      seen: seen ?? this.seen,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accountName': accountName,
      'amount': amount,
      'type': type == TransactionType.credit ? 'credit' : 'debit',
      'description': description,
      'date': date.millisecondsSinceEpoch,
      'smsBody': smsBody,
      'matchedDigits': matchedDigits,
      'seen': seen,
    };
  }

  factory PartialTransaction.fromJson(String id, Map<dynamic, dynamic> json) {
    return PartialTransaction(
      id: id,
      accountName: json['accountName'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      type: json['type'] == 'credit' ? TransactionType.credit : TransactionType.debit,
      description: json['description'] ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(json['date'] ?? DateTime.now().millisecondsSinceEpoch),
      smsBody: json['smsBody'] ?? '',
      matchedDigits: json['matchedDigits'] ?? '',
      seen: json['seen'] ?? false,
    );
  }

  @override
  List<Object?> get props =>
      [id, accountName, amount, type, description, date, smsBody, matchedDigits, seen];
}


