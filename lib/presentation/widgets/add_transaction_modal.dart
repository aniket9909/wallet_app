import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/utils/planner_navigation.dart';
import '../../data/models/money_plan_model.dart';
import '../../data/models/transaction_model_new.dart';
import '../../logic/cubits/account_cubit.dart';
import '../../logic/cubits/money_plan_cubit.dart';
import '../../logic/cubits/transaction_cubit.dart';

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
  late String _selectedPlannerSection;
  late String _selectedSubtype;
  String? _selectedAccount;
  String? _selectedToAccount;
  String? _categoryError;

  @override
  void initState() {
    super.initState();
    _selectedPlannerSection =
        PlannerCategories.defaultSectionFor(isCredit: false);
    _selectedSubtype =
        PlannerCategories.subtypesFor(_selectedPlannerSection).first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<MoneyPlanCubit>().loadPlan();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  MoneyPlanModel? _currentPlan() {
    try {
      final state = context.read<MoneyPlanCubit>().state;
      if (state is MoneyPlanLoaded) return state.plan;
    } catch (_) {}
    return null;
  }

  List<String> _subtypesFor(String section) {
    return PlannerCategories.subtypesFor(section, plan: _currentPlan());
  }

  void _applySection(String section) {
    final subtypes = _subtypesFor(section);
    setState(() {
      _selectedPlannerSection = section;
      _selectedSubtype = subtypes.contains(_selectedSubtype)
          ? _selectedSubtype
          : subtypes.first;
      _categoryError = null;
    });
  }

  void _onTypeChanged(TransactionType type) {
    final section = PlannerCategories.defaultSectionFor(
      isCredit: type == TransactionType.credit,
    );
    setState(() {
      _transactionType = type;
      _isTransfer = false;
    });
    _applySection(section);
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
                Text(
                  'Add Transaction',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),
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
                      Expanded(child: _buildTransferButton()),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
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
                if (!_isTransfer) ...[
                  BlocBuilder<MoneyPlanCubit, MoneyPlanState>(
                    builder: (context, _) {
                      final subtypes = _subtypesFor(_selectedPlannerSection);
                      final sectionColor =
                          PlannerSections.colorFor(_selectedPlannerSection);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Money Planner category',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pick a planner section and subcategory so tracking stays complete.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Section',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: PlannerSections.pickerOrder.map((section) {
                              final selected =
                                  _selectedPlannerSection == section;
                              final color = PlannerSections.colorFor(section);
                              return ChoiceChip(
                                avatar: Icon(
                                  PlannerSections.iconFor(section),
                                  size: 16,
                                  color: selected ? color : Colors.grey[700],
                                ),
                                label: Text(section),
                                selected: selected,
                                selectedColor: color.withOpacity(0.18),
                                onSelected: (_) => _applySection(section),
                                labelStyle: TextStyle(
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected ? color : Colors.grey[800],
                                  fontSize: 12,
                                ),
                                side: BorderSide(
                                  color: selected
                                      ? color
                                      : Colors.grey.withOpacity(0.3),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Subcategory · $_selectedPlannerSection',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: subtypes.map((sub) {
                              final selected = _selectedSubtype == sub;
                              return FilterChip(
                                label: Text(sub),
                                selected: selected,
                                selectedColor: sectionColor.withOpacity(0.18),
                                checkmarkColor: sectionColor,
                                onSelected: (_) => setState(() {
                                  _selectedSubtype = sub;
                                  _categoryError = null;
                                }),
                                labelStyle: TextStyle(
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? sectionColor
                                      : Colors.grey[800],
                                  fontSize: 12,
                                ),
                                side: BorderSide(
                                  color: selected
                                      ? sectionColor
                                      : Colors.grey.withOpacity(0.3),
                                ),
                              );
                            }).toList(),
                          ),
                          if (_categoryError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _categoryError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                BlocBuilder<AccountCubit, AccountState>(
                  builder: (context, state) {
                    final accounts =
                        state is AccountLoaded ? state.accounts : [];

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
                            labelText:
                                _isTransfer ? 'From Account' : 'Account',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          items: accountItems,
                          onChanged: (String? value) {
                            setState(() => _selectedAccount = value);
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
                              setState(() => _selectedToAccount = value);
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
                      style: const TextStyle(
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
    final isSelected = !_isTransfer && _transactionType == type;

    return GestureDetector(
      onTap: () => _onTypeChanged(type),
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
            Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
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
          _categoryError = null;
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
    if (!_isTransfer &&
        (_selectedSubtype.isEmpty || _selectedPlannerSection.isEmpty)) {
      setState(() => _categoryError = 'Please select planner subcategory');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text);
    final description = _descriptionController.text;
    final userNote =
        _noteController.text.isEmpty ? null : _noteController.text;

    Navigator.pop(context);

    if (_isTransfer) {
      final debitTx = TransactionModelNew(
        id: '',
        type: TransactionType.debit,
        amount: amount,
        description: description.isEmpty
            ? 'Transfer to $_selectedToAccount'
            : description,
        category: 'Transfer',
        account: _selectedAccount!,
        date: DateTime.now(),
        note: userNote,
      );
      final creditTx = TransactionModelNew(
        id: '',
        type: TransactionType.credit,
        amount: amount,
        description: description.isEmpty
            ? 'Transfer from $_selectedAccount'
            : description,
        category: 'Transfer',
        account: _selectedToAccount!,
        date: DateTime.now(),
        note: userNote,
      );

      final cubit = context.read<TransactionCubit>();
      cubit.addTransaction(debitTx);
      cubit.addTransaction(creditTx);
    } else {
      final transaction = TransactionModelNew(
        id: '',
        type: _transactionType,
        amount: amount,
        description: description,
        category: _selectedSubtype,
        account: _selectedAccount!,
        date: DateTime.now(),
        note: PlannerCategories.formatNote(
          section: _selectedPlannerSection,
          subtype: _selectedSubtype,
          extra: userNote,
        ),
      );
      context.read<TransactionCubit>().addTransaction(transaction);
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isTransfer
                  ? 'Transfer completed!'
                  : 'Saved to $_selectedPlannerSection · $_selectedSubtype',
            ),
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
