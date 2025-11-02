import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../logic/cubits/savings_goal_cubit.dart';
import '../../data/models/savings_goal_model.dart';

class AddGoalModal extends StatefulWidget {
  const AddGoalModal({super.key});

  @override
  State<AddGoalModal> createState() => _AddGoalModalState();
}

class _AddGoalModalState extends State<AddGoalModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _monthlyIncomeController = TextEditingController();
  final _monthlyExpenseController = TextEditingController();
  final _timePeriodController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _monthlyIncomeController.dispose();
    _monthlyExpenseController.dispose();
    _timePeriodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.savings, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Create Savings Goal',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Goal Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Goal Name',
                    hintText: 'e.g., Buy New Bike',
                    prefixIcon: const Icon(Icons.flag),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter goal name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Target Amount
                TextFormField(
                  controller: _targetAmountController,
                  decoration: InputDecoration(
                    labelText: 'Target Amount',
                    hintText: '80000',
                    prefixIcon: const Icon(Icons.currency_rupee),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter target amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Monthly Income
                TextFormField(
                  controller: _monthlyIncomeController,
                  decoration: InputDecoration(
                    labelText: 'Monthly Income',
                    hintText: '40000',
                    prefixIcon: const Icon(Icons.arrow_downward, color: Colors.green),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter monthly income';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Monthly Expense
                TextFormField(
                  controller: _monthlyExpenseController,
                  decoration: InputDecoration(
                    labelText: 'Monthly Expense',
                    hintText: '30000',
                    prefixIcon: const Icon(Icons.arrow_upward, color: Colors.red),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter monthly expense';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Time Period
                TextFormField(
                  controller: _timePeriodController,
                  decoration: InputDecoration(
                    labelText: 'Time Period (months)',
                    hintText: '12',
                    prefixIcon: const Icon(Icons.calendar_month),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter time period';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Info Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'We\'ll calculate how much you need to save each month based on your income and expenses.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _submitGoal,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle),
                        SizedBox(width: 8),
                        Text(
                          'Create Goal',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submitGoal() {
    if (_formKey.currentState!.validate()) {
      final goal = SavingsGoalModel(
        id: const Uuid().v4(),
        name: _nameController.text,
        targetAmount: double.parse(_targetAmountController.text),
        monthlyIncome: double.parse(_monthlyIncomeController.text),
        monthlyExpense: double.parse(_monthlyExpenseController.text),
        timePeriodMonths: int.parse(_timePeriodController.text),
        savedSoFar: 0,
        createdDate: DateTime.now(),
      );

      context.read<SavingsGoalCubit>().addGoal(goal);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Savings goal created successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      Navigator.pop(context);
    }
  }
}

