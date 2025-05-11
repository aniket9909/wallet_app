// viewmodels/expense_viewmodel.dart
import 'package:flutter/material.dart';
import '../models/expense_model.dart';
import '../services/firebase_service.dart';

class DashboardViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final String userId;
  String tabType = "all";
  DashboardViewModel(this.userId);
  TextEditingController descriptionController = TextEditingController();
  TextEditingController amountController = TextEditingController();
  TextEditingController categoryController = TextEditingController();
  double totalAmount = 0.0;
  double totalIncome = 0.0;
  double totalExpense = 0.0;
  double totalSavings = 0.0;
  double totalDebt = 0.0;
  double totalInvestment = 0.0;
  double totalNetWorth = 0.0;
  double totalCashFlow = 0.0;
  double totalCash = 0.0;
  double totalCredit = 0.0;
  double totalDebit = 0.0;
 String selectedPeriod = "this_week";
  TextEditingController noteController = TextEditingController();

  List<ExpenseModel> _expenses = [];
  List<ExpenseModel> _backUp = [];
  List<ExpenseModel> get expenses => _expenses;

  void listenToExpenses() {
    _firebaseService.getExpenses("123").listen((data) {
      _expenses = data;
      _backUp = data;
      notifyListeners();
      calculate();
    });
  }
  changePeriod(String period) {
    selectedPeriod = period;
    notifyListeners();
  }
  Future<void> addExpense(ExpenseModel expense) async {
    var result = await _firebaseService.addExpense("123", expense);
    notifyListeners();
  }

  changeTab(String tabType) {
    this.tabType = tabType;
    _expenses = _backUp;
    if (tabType == "income") {
      _expenses =
          _backUp.where((expense) => expense.category == "Income").toList();
    } else if (tabType == "expense") {
      _expenses =
          _backUp.where((expense) => expense.category == "Expense").toList();
    }
    notifyListeners();
  }

  calculate() {
    totalAmount = 0.0;
    totalIncome = 0.0;
    totalExpense = 0.0;
    totalSavings = 0.0;
    totalDebt = 0.0;
    totalInvestment = 0.0;
    totalNetWorth = 0.0;
    totalCashFlow = 0.0;
    totalCash = 0.0;
    totalCredit = 0.0;
    totalDebit = 0.0;

    for (var expense in _expenses) {
      if (expense.category == "Income") {
        totalIncome += expense.amount;
      } else if (expense.category == "Expense") {
        totalExpense += expense.amount;
      }
    }
    totalAmount = totalIncome - totalExpense;
    notifyListeners();
  }

  bool validateAndSubmit() {
    if (descriptionController.text.isNotEmpty &&
        amountController.text.isNotEmpty &&
        categoryController.text.isNotEmpty) {
      final expense = ExpenseModel(
        id: UniqueKey().toString(),
        title: descriptionController.text,
        amount: double.tryParse(amountController.text) ?? 0.0,
        category: categoryController.text,
        date: DateTime.now(),
        note: noteController.text,
      );
      print("Expense: ${expense.toMap()}");
      addExpense(expense);
      // calculate();
      return true;
    }
    return false;
  }
}
