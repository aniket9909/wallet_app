// viewmodels/expense_viewmodel.dart
import 'package:flutter/material.dart';
import '../models/expense_model.dart';
import '../services/firebase_service.dart';

class ExpenseViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final String userId;

  ExpenseViewModel(this.userId);

  List<ExpenseModel> _expenses = [];
  List<ExpenseModel> get expenses => _expenses;

  void listenToExpenses() {
    _firebaseService.getExpenses("123").listen((data) {
      _expenses = data;
      notifyListeners();
    });
  }

  Future<void> addExpense(ExpenseModel expense) async {
    var expenses = ExpenseModel(
            id: '',
            title: 'Test Expense',
            amount: 100,
            category: 'Test',
            date: DateTime.now(),
            note: 'Sample note',
          );
    await _firebaseService.addExpense("123", expense);
  }
}

