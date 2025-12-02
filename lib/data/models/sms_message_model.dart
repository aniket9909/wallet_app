import 'package:equatable/equatable.dart';

enum SmsStatus { pending, correct, wrong, decline }

class SmsMessageModel extends Equatable {
  final int? id;
  final String body;
  final String address;
  final DateTime date;
  final bool isRead;
  final SmsStatus status;
  final bool isCreditDebit; // Whether this SMS is a credit/debit transaction
  final double? amount; // Extracted amount if credit/debit
  final String? transactionType; // 'credit' or 'debit' if applicable

  const SmsMessageModel({
    this.id,
    required this.body,
    required this.address,
    required this.date,
    this.isRead = false,
    this.status = SmsStatus.pending,
    this.isCreditDebit = false,
    this.amount,
    this.transactionType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'body': body,
      'address': address,
      'date': date.millisecondsSinceEpoch,
      'is_read': isRead ? 1 : 0,
      'status': status.name,
      'is_credit_debit': isCreditDebit ? 1 : 0,
      'amount': amount,
      'transaction_type': transactionType,
    };
  }

  factory SmsMessageModel.fromMap(Map<String, dynamic> map) {
    return SmsMessageModel(
      id: map['id'] as int?,
      body: map['body'] as String,
      address: map['address'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      isRead: (map['is_read'] as int) == 1,
      status: SmsStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String? ?? 'pending'),
        orElse: () => SmsStatus.pending,
      ),
      isCreditDebit: (map['is_credit_debit'] as int? ?? 0) == 1,
      amount: map['amount'] as double?,
      transactionType: map['transaction_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'body': body,
      'address': address,
      'date': date.millisecondsSinceEpoch,
      'isRead': isRead,
      'status': status.name,
      'isCreditDebit': isCreditDebit,
      'amount': amount,
      'transactionType': transactionType,
    };
  }

  factory SmsMessageModel.fromJson(String id, Map<dynamic, dynamic> json) {
    return SmsMessageModel(
      id: int.tryParse(id),
      body: json['body'] as String,
      address: json['address'] as String? ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(json['date'] as int),
      isRead: json['isRead'] as bool? ?? false,
      status: SmsStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'pending'),
        orElse: () => SmsStatus.pending,
      ),
      isCreditDebit: json['isCreditDebit'] as bool? ?? false,
      amount: (json['amount'] as num?)?.toDouble(),
      transactionType: json['transactionType'] as String?,
    );
  }

  SmsMessageModel copyWith({
    int? id,
    String? body,
    String? address,
    DateTime? date,
    bool? isRead,
    SmsStatus? status,
    bool? isCreditDebit,
    double? amount,
    String? transactionType,
  }) {
    return SmsMessageModel(
      id: id ?? this.id,
      body: body ?? this.body,
      address: address ?? this.address,
      date: date ?? this.date,
      isRead: isRead ?? this.isRead,
      status: status ?? this.status,
      isCreditDebit: isCreditDebit ?? this.isCreditDebit,
      amount: amount ?? this.amount,
      transactionType: transactionType ?? this.transactionType,
    );
  }

  @override
  List<Object?> get props => [id, body, address, date, isRead, status, isCreditDebit, amount, transactionType];
}

