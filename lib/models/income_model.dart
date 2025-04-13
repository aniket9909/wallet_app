// models/expense_model.dart
class IncomeModel {
  final String id;
  final String title;
  final String source;
  final double amount;
  final String category;
  final DateTime date;
  final String note;

  IncomeModel({
    required this.id,
    required this.title,
    required this.source,
    required this.amount,
    required this.category,
    required this.date,
    required this.note,
  });

  factory IncomeModel.fromMap(Map<String, dynamic> map, String docId) {
    return IncomeModel(
      id: docId,
      title: map['title'],
      source: map['source'],
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
      'source': source,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
    };
  }
}
