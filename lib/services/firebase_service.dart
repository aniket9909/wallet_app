// services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ewallet/models/income_model.dart';
import '../models/expense_model.dart';

class FirebaseService {
  // Private constructor
  FirebaseService._privateConstructor();

  // Singleton instance
  static final FirebaseService _instance =
      FirebaseService._privateConstructor();

  // Factory constructor to return the same instance
  factory FirebaseService() {
    return _instance;
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addExpense(String userId, ExpenseModel expense) async {
    await _firestore
        .collection('wallet')
        .doc(userId)
        .collection('expenses')
        .add(expense.toMap());
  }

  Future<void> addIncome(String userId, IncomeModel expense) async {
    await _firestore
        .collection('wallet')
        .doc(userId)
        .collection('income')
        .add(expense.toMap());
  }

  Stream<List<IncomeModel>> getIncome(String userId) {
    return _firestore
        .collection('wallet')
        .doc(userId)
        .collection('income')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => IncomeModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<ExpenseModel>> getExpenses(String userId) {
    return _firestore
        .collection('wallet')
        .doc(userId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
