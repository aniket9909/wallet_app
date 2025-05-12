// models/expense_model.dart
class ExpenseModel {
  final String id;
  final String title;
  final String fromWalletId;
  final double amount;
  final String category;
  final DateTime date;
  final String note;

  ExpenseModel({
    required this.id,
    required this.title,
    required this.fromWalletId,
    required this.amount,
    required this.category,
    required this.date,
    required this.note,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map, String docId) {
    return ExpenseModel(
      id: docId,
      title: map['title'],

      fromWalletId: map['fromWalletId'],
      amount: map['amount'],
      category: map['category'],
      date: DateTime.parse(map['date']),
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'fromWalletId': fromWalletId,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
    };
  }
}
