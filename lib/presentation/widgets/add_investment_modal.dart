import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../logic/cubits/investment_cubit.dart';
import '../../logic/cubits/account_cubit.dart';
import '../../data/models/investment_model.dart';

class AddInvestmentModal extends StatefulWidget {
  const AddInvestmentModal({super.key});

  @override
  State<AddInvestmentModal> createState() => _AddInvestmentModalState();
}

class _AddInvestmentModalState extends State<AddInvestmentModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _investedAmountController = TextEditingController();
  final _currentValueController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _noteController = TextEditingController();

  InvestmentType _investmentType = InvestmentType.mutualFund;
  DateTime? _purchaseDate;
  DateTime? _maturityDate;
  String? _selectedAccount;

  @override
  void initState() {
    super.initState();
    _purchaseDate = DateTime.now();
    _currentValueController.text = '0';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _investedAmountController.dispose();
    _currentValueController.dispose();
    _interestRateController.dispose();
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.trending_up, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Add Investment',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Investment Type
                DropdownButtonFormField<InvestmentType>(
                  value: _investmentType,
                  decoration: InputDecoration(
                    labelText: 'Investment Type',
                    prefixIcon: const Icon(Icons.category),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: InvestmentType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_getInvestmentTypeName(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _investmentType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Investment Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Investment Name',
                    hintText: 'e.g., SBI Mutual Fund',
                    prefixIcon: const Icon(Icons.account_balance),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter investment name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Invested Amount
                TextFormField(
                  controller: _investedAmountController,
                  decoration: InputDecoration(
                    labelText: 'Invested Amount',
                    prefixText: '₹ ',
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
                      return 'Please enter invested amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Current Value
                TextFormField(
                  controller: _currentValueController,
                  decoration: InputDecoration(
                    labelText: 'Current Value',
                    prefixText: '₹ ',
                    hintText: 'Leave 0 if same as invested',
                    prefixIcon: const Icon(Icons.account_balance_wallet),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),

                // Interest Rate (Optional)
                TextFormField(
                  controller: _interestRateController,
                  decoration: InputDecoration(
                    labelText: 'Interest Rate % (Optional)',
                    prefixIcon: const Icon(Icons.percent),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Purchase Date
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _purchaseDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        _purchaseDate = date;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Purchase Date',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    child: Text(
                      _purchaseDate != null
                          ? DateFormat('MMM dd, yyyy').format(_purchaseDate!)
                          : 'Select purchase date',
                      style: TextStyle(
                        color: _purchaseDate != null
                            ? Colors.black87
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Maturity Date (Optional)
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _maturityDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (date != null) {
                      setState(() {
                        _maturityDate = date;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Maturity Date (Optional)',
                      prefixIcon: const Icon(Icons.event),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    child: Text(
                      _maturityDate != null
                          ? DateFormat('MMM dd, yyyy').format(_maturityDate!)
                          : 'Select maturity date',
                      style: TextStyle(
                        color: _maturityDate != null
                            ? Colors.black87
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Account (Optional)
                BlocBuilder<AccountCubit, AccountState>(
                  builder: (context, state) {
                    final accounts = state is AccountLoaded ? state.accounts : [];

                    if (accounts.isEmpty) {
                      return const SizedBox();
                    }

                    return DropdownButtonFormField<String>(
                      value: _selectedAccount,
                      decoration: InputDecoration(
                        labelText: 'Linked Account (Optional)',
                        prefixIcon: const Icon(Icons.account_balance_wallet),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: accounts.map<DropdownMenuItem<String>>((account) {
                        return DropdownMenuItem<String>(
                          value: account.name,
                          child: Text(account.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedAccount = value;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Note
                TextFormField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: 'Note (Optional)',
                    prefixIcon: const Icon(Icons.note),
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
                    onPressed: _submitInvestment,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Add Investment',
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

  String _getInvestmentTypeName(InvestmentType type) {
    switch (type) {
      case InvestmentType.mutualFund:
        return 'Mutual Fund';
      case InvestmentType.fixedDeposit:
        return 'Fixed Deposit';
      case InvestmentType.stocks:
        return 'Stocks';
      case InvestmentType.gold:
        return 'Gold';
      case InvestmentType.bonds:
        return 'Bonds';
      case InvestmentType.other:
        return 'Other';
    }
  }

  void _submitInvestment() {
    if (_formKey.currentState!.validate()) {
      final investment = InvestmentModel(
        id: '', // Will be set by Firebase key
        type: _investmentType,
        name: _nameController.text,
        investedAmount: double.parse(_investedAmountController.text),
        currentValue: _currentValueController.text.isEmpty
            ? double.parse(_investedAmountController.text)
            : double.parse(_currentValueController.text),
        purchaseDate: _purchaseDate ?? DateTime.now(),
        maturityDate: _maturityDate,
        interestRate: _interestRateController.text.isNotEmpty
            ? double.tryParse(_interestRateController.text)
            : null,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        account: _selectedAccount,
        note: _noteController.text.isEmpty ? null : _noteController.text,
      );

      // Close modal first
      Navigator.pop(context);

      // Add investment (stream will update UI automatically)
      context.read<InvestmentCubit>().addInvestment(investment);

      // Show success message after a brief delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Investment added successfully!'),
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

