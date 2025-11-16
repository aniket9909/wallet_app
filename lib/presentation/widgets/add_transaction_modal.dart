import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/cubits/transaction_cubit.dart';
import '../../logic/cubits/account_cubit.dart';
import '../../logic/cubits/settings_cubit.dart';
import '../../data/models/transaction_model_new.dart';

class AddTransactionModal extends StatefulWidget {
  const AddTransactionModal({super.key});

  @override
  State<AddTransactionModal> createState() => _AddTransactionModalState();
}

class _AddTransactionModalState extends State<AddTransactionModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _noteController = TextEditingController();

  TransactionType _transactionType = TransactionType.debit;
  bool _isTransfer = false;
  String? _selectedCategory;
  String? _selectedAccount;
  String? _selectedToAccount;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
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
                Text(
                  'Add Transaction',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),

                // Transaction Type Toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTypeButton(
                          'Credit',
                          TransactionType.credit,
                          Icons.arrow_downward,
                          Colors.green,
                        ),
                      ),
                      Expanded(
                        child: _buildTypeButton(
                          'Debit',
                          TransactionType.debit,
                          Icons.arrow_upward,
                          Colors.red,
                        ),
                      ),
                      Expanded(
                        child: _buildTransferButton(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Amount Field
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
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
                      return 'Please enter amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description Field
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Category Dropdown (hidden for transfer)
                if (!_isTransfer)
                  BlocBuilder<SettingsCubit, SettingsState>(
                    builder: (context, state) {
                      final categories = state is SettingsLoaded
                          ? state.settings.expenseTypes
                          : ['Food', 'Bills', 'Shopping', 'Travel'];

                      return DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        items:
                            categories.map<DropdownMenuItem<String>>((category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select category';
                          }
                          return null;
                        },
                      );
                    },
                  ),
                const SizedBox(height: 16),

                // Account(s) Dropdown
                BlocBuilder<AccountCubit, AccountState>(
                  builder: (context, state) {
                    final accounts = state is AccountLoaded ? state.accounts : [];

                    if (accounts.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'No accounts available. Please add an account first.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      );
                    }

                    final accountItems =
                        accounts.map<DropdownMenuItem<String>>((account) {
                      return DropdownMenuItem<String>(
                        value: account.name,
                        child: Text(account.name),
                      );
                    }).toList();

                    return Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedAccount,
                          decoration: InputDecoration(
                            labelText: _isTransfer ? 'From Account' : 'Account',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          items: accountItems,
                          onChanged: (String? value) {
                            setState(() {
                              _selectedAccount = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select account';
                            }
                            return null;
                          },
                        ),
                        if (_isTransfer) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedToAccount,
                            decoration: InputDecoration(
                              labelText: 'To Account',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            items: accountItems,
                            onChanged: (String? value) {
                              setState(() {
                                _selectedToAccount = value;
                              });
                            },
                            validator: (value) {
                              if (!_isTransfer) return null;
                              if (value == null) {
                                return 'Please select destination account';
                              }
                              if (value == _selectedAccount) {
                                return 'Accounts must be different';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Note Field (Optional)
                TextFormField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: 'Note (Optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _submitTransaction,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _isTransfer ? 'Transfer' : 'Add Transaction',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildTypeButton(
    String label,
    TransactionType type,
    IconData icon,
    Color color,
  ) {
    final isSelected = _transactionType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _transactionType = type;
          _isTransfer = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferButton() {
    final isSelected = _isTransfer;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isTransfer = true;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.swap_horiz,
              color: isSelected ? Colors.blue : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Transfer',
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitTransaction() {
    if (_formKey.currentState!.validate()) {
      final amount = double.parse(_amountController.text);
      final description = _descriptionController.text;
      final note = _noteController.text.isEmpty ? null : _noteController.text;

      // Close modal first
      Navigator.pop(context);

      if (_isTransfer) {
        // Create two transactions: debit from source, credit to destination
        final debitTx = TransactionModelNew(
          id: '',
          type: TransactionType.debit,
          amount: amount,
          description: description.isEmpty ? 'Transfer to $_selectedToAccount' : description,
          category: 'Transfer',
          account: _selectedAccount!,
          date: DateTime.now(),
          note: note,
        );
        final creditTx = TransactionModelNew(
          id: '',
          type: TransactionType.credit,
          amount: amount,
          description: description.isEmpty ? 'Transfer from $_selectedAccount' : description,
          category: 'Transfer',
          account: _selectedToAccount!,
          date: DateTime.now(),
          note: note,
        );

        final cubit = context.read<TransactionCubit>();
        cubit.addTransaction(debitTx);
        cubit.addTransaction(creditTx);
      } else {
        final transaction = TransactionModelNew(
          id: '', // Will be set by Firebase key
          type: _transactionType,
          amount: amount,
          description: description,
          category: _selectedCategory!,
          account: _selectedAccount!,
          date: DateTime.now(),
          note: note,
        );
        // Add transaction (stream will update UI automatically)
        context.read<TransactionCubit>().addTransaction(transaction);
      }

      // Show success message after a brief delay to ensure operation started
      Future.delayed(const Duration(milliseconds: 300), () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isTransfer
                  ? 'Transfer completed!'
                  : 'Transaction added successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      });
    }
  }
}

