import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../data/models/account_model.dart';
import '../../data/models/sms_message_model.dart';
import '../../data/models/transaction_model_new.dart';
import '../../logic/cubits/account_cubit.dart';
import '../../logic/cubits/settings_cubit.dart';
import '../../logic/cubits/sms_cubit.dart';
import '../../logic/cubits/transaction_cubit.dart';
import '../../core/utils/sms_detection_util.dart';

class SmsSyncSheet extends StatefulWidget {
  final SmsMessageModel message;

  const SmsSyncSheet({super.key, required this.message});

  static Future<void> show(BuildContext context, SmsMessageModel message) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SmsSyncSheet(message: message),
    );
  }

  @override
  State<SmsSyncSheet> createState() => _SmsSyncSheetState();
}

class _SmsSyncSheetState extends State<SmsSyncSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late TransactionType _selectedType;
  String? _selectedAccount;
  String? _selectedCategory;
  String? _extractedName;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    final amount = widget.message.amount;
    _amountController = TextEditingController(
      text: amount != null ? amount.toStringAsFixed(2) : '',
    );
    _extractedName = SmsDetectionUtil.extractFromName(widget.message.body);
    final suggested = SmsDetectionUtil.suggestedSyncDescription(
      smsBody: widget.message.body,
      transactionType: widget.message.transactionType,
    );
    _descriptionController = TextEditingController(text: suggested ?? '');
    _selectedType = widget.message.transactionType == 'credit'
        ? TransactionType.credit
        : TransactionType.debit;
    context.read<AccountCubit>().loadAccounts();
    final settingsState = context.read<SettingsCubit>().state;
    if (settingsState is! SettingsLoaded) {
      context.read<SettingsCubit>().loadSettings();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedAccount ??= _guessAccountName(context);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _guessAccountName(BuildContext context) {
    final accountState = context.read<AccountCubit>().state;
    if (accountState is! AccountLoaded || accountState.accounts.isEmpty) {
      return null;
    }

    for (final account in accountState.accounts) {
      final digits = account.lastDigits;
      if (digits != null &&
          digits.isNotEmpty &&
          widget.message.body.contains(digits)) {
        return account.name;
      }
    }

    return accountState.accounts.first.name;
  }

  Future<void> _sync() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final accountState = context.read<AccountCubit>().state;
    if (accountState is! AccountLoaded || accountState.accounts.isEmpty) {
      _showSnack('Add at least one account first', Colors.orange);
      return;
    }

    if (_selectedAccount == null || _selectedAccount!.isEmpty) {
      _showSnack('Select an account', Colors.orange);
      return;
    }

    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      _showSnack('Please select category', Colors.orange);
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnack('Enter a valid amount', Colors.orange);
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final sms = widget.message;
      final description = SmsDetectionUtil.resolveSyncDescription(
        smsBody: sms.body,
        userDescription: _descriptionController.text,
        transactionType: sms.transactionType,
      );

      final transaction = TransactionModelNew(
        id: '',
        type: _selectedType,
        amount: amount,
        description: description,
        category: _selectedCategory!,
        account: _selectedAccount!,
        date: sms.date,
        note: sms.body,
      );

      await context.read<TransactionCubit>().addTransaction(transaction);

      if (sms.id != null) {
        await context.read<SmsCubit>().finalizeSync(sms.id!);
      }

      if (!mounted) return;
      Navigator.pop(context);
      if (!context.mounted) return;
      _showSnack('Synced to wallet and marked as read', Colors.green);
    } catch (e) {
      if (mounted) {
        _showSnack('Sync failed: $e', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountState = context.watch<AccountCubit>().state;
    final accounts =
        accountState is AccountLoaded ? accountState.accounts : <AccountModel>[];
    final isCredit = _selectedType == TransactionType.credit;
    final typeColor = isCredit ? Colors.green : Colors.red;
    final dateFormat = DateFormat('MMM dd, yyyy · hh:mm a');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: typeColor),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Sync to Wallet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  dateFormat.format(widget.message.date),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                if (_extractedName != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: typeColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 18, color: typeColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'SMS from $_extractedName',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: typeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: _selectedType == TransactionType.debit
                        ? 'SMS from name'
                        : 'SMS from sender',
                    helperText: _extractedName != null
                        ? 'From SMS: $_extractedName'
                        : 'No "from" name found — enter description manually',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount *',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    if (amount == null || amount <= 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Transaction type',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _TypeChip(
                        label: 'Debit',
                        icon: Icons.arrow_upward,
                        color: Colors.red,
                        selected: _selectedType == TransactionType.debit,
                        onTap: () => setState(
                          () => _selectedType = TransactionType.debit,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TypeChip(
                        label: 'Credit',
                        icon: Icons.arrow_downward,
                        color: Colors.green,
                        selected: _selectedType == TransactionType.credit,
                        onTap: () => setState(
                          () => _selectedType = TransactionType.credit,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                BlocBuilder<SettingsCubit, SettingsState>(
                  builder: (context, state) {
                    final categories = state is SettingsLoaded
                        ? state.settings.expenseTypes
                        : const ['Food', 'Bills', 'Shopping', 'Travel'];

                    return DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedCategory = value),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select category';
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (accounts.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'No accounts found. Add an account first.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: _selectedAccount,
                    decoration: InputDecoration(
                      labelText: 'Account *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: accounts
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.name,
                            child: Text(
                              a.lastDigits != null && a.lastDigits!.isNotEmpty
                                  ? '${a.name} (···${a.lastDigits})'
                                  : a.name,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedAccount = value),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select account';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.message.body,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing || accounts.isEmpty ? null : _sync,
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: Text(_isSyncing ? 'Syncing...' : 'Sync & Mark Read'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.12) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : Colors.grey[300]!,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? color : Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? color : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
