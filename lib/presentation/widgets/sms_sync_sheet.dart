import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../data/models/account_model.dart';
import '../../data/models/sms_message_model.dart';
import '../../data/models/transaction_model_new.dart';
import '../../logic/cubits/account_cubit.dart';
import '../../logic/cubits/money_plan_cubit.dart';
import '../../logic/cubits/sms_cubit.dart';
import '../../logic/cubits/transaction_cubit.dart';
import '../../core/utils/sms_detection_util.dart';
import '../../core/utils/planner_navigation.dart';

class SmsSyncSheet extends StatefulWidget {
  final SmsMessageModel message;
  final String? initialAccount;
  final String? initialCategory;
  final String? initialPlannerSection;
  final bool asPage;

  const SmsSyncSheet({
    super.key,
    required this.message,
    this.initialAccount,
    this.initialCategory,
    this.initialPlannerSection,
    this.asPage = false,
  });

  static const plannerSections = PlannerSections.pickerOrder;

  /// Default subtypes for each Money Planner section.
  static const Map<String, List<String>> plannerSubtypes =
      PlannerCategories.defaultSubtypes;

  /// Opens the sync form (account, planner category, description, amount).
  /// Returns `true` when the SMS was saved successfully.
  static Future<bool> show(
    BuildContext context,
    SmsMessageModel message, {
    String? initialAccount,
    String? initialCategory,
    String? initialPlannerSection,
    bool asPage = false,
  }) async {
    if (asPage) {
      final result = await Navigator.of(context, rootNavigator: true).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => Scaffold(
            body: SmsSyncSheet(
              message: message,
              initialAccount: initialAccount,
              initialCategory: initialCategory,
              initialPlannerSection: initialPlannerSection,
              asPage: true,
            ),
          ),
        ),
      );
      return result == true;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      useRootNavigator: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SmsSyncSheet(
        message: message,
        initialAccount: initialAccount,
        initialCategory: initialCategory,
        initialPlannerSection: initialPlannerSection,
      ),
    );
    return result == true;
  }

  @override
  State<SmsSyncSheet> createState() => _SmsSyncSheetState();
}

class _SmsSyncSheetState extends State<SmsSyncSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late TransactionType _selectedType;
  String? _selectedBank;
  String? _selectedPlannerSection;
  String? _selectedSubtype;
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
    _selectedPlannerSection = widget.initialPlannerSection ??
        (_selectedType == TransactionType.credit ? 'Income' : 'Essentials');
    final initialCat = widget.initialCategory;
    if (initialCat != null && initialCat.isNotEmpty) {
      _selectedSubtype = initialCat;
      // Prefer a planner section that already contains this subtype.
      for (final entry in SmsSyncSheet.plannerSubtypes.entries) {
        if (entry.value.contains(initialCat)) {
          _selectedPlannerSection = entry.key;
          break;
        }
      }
      if (widget.initialPlannerSection != null &&
          widget.initialPlannerSection!.isNotEmpty) {
        _selectedPlannerSection = widget.initialPlannerSection;
      }
    } else {
      _selectedSubtype = _defaultSubtypeFor(_selectedPlannerSection!);
    }
    if (widget.initialAccount != null && widget.initialAccount!.isNotEmpty) {
      _selectedBank = widget.initialAccount;
    }
    context.read<AccountCubit>().loadAccounts();
    try {
      context.read<MoneyPlanCubit>().loadPlan();
    } catch (_) {}
  }

  String _defaultSubtypeFor(String section) {
    final list = SmsSyncSheet.plannerSubtypes[section];
    return list?.first ?? 'Other';
  }

  void _applyPlannerSection(String section) {
    _selectedPlannerSection = section;
    final subtypes = _subtypesFor(section);
    _selectedSubtype =
        subtypes.contains(_selectedSubtype) ? _selectedSubtype : subtypes.first;
  }

  void _onPlannerSectionChanged(String? section) {
    if (section == null) return;
    setState(() => _applyPlannerSection(section));
  }

  List<String> _subtypesFor(String section) {
    final defaults =
        List<String>.from(SmsSyncSheet.plannerSubtypes[section] ?? const ['Other']);

    // Merge live Money Planner items when available.
    try {
      final state = context.read<MoneyPlanCubit>().state;
      if (state is MoneyPlanLoaded) {
        final plan = state.plan;
        switch (section) {
          case 'Essentials':
            for (final e in plan.expenses) {
              if (e.name.isNotEmpty && !defaults.contains(e.name)) {
                defaults.insert(0, e.name);
              }
            }
            break;
          case 'Investment':
            for (final i in plan.investments) {
              if (i.name.isNotEmpty && !defaults.contains(i.name)) {
                defaults.insert(0, i.name);
              }
            }
            break;
          case 'Goals':
            for (final g in plan.goals) {
              if (g.name.isNotEmpty && !defaults.contains(g.name)) {
                defaults.insert(0, g.name);
              }
            }
            break;
          case 'Debt & EMI':
            for (final d in plan.debts) {
              if (d.name.isNotEmpty && !defaults.contains(d.name)) {
                defaults.insert(0, d.name);
              }
            }
            break;
          default:
            break;
        }
      }
    } catch (_) {}

    final fromOverlay = widget.initialCategory;
    if (fromOverlay != null &&
        fromOverlay.isNotEmpty &&
        !defaults.contains(fromOverlay)) {
      defaults.insert(0, fromOverlay);
    }

    return defaults;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedBank ??= _guessBank(context);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _guessBank(BuildContext context) {
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

    final address = widget.message.address.toUpperCase();
    for (final account in accountState.accounts) {
      final name = account.name.toUpperCase();
      if (address.contains(name) ||
          name.split(' ').any((p) => p.length > 2 && address.contains(p))) {
        return account.name;
      }
    }

    final banks = accountState.accounts
        .where((a) => a.type.toLowerCase().contains('bank'))
        .toList();
    if (banks.isNotEmpty) return banks.first.name;
    return accountState.accounts.first.name;
  }

  Future<void> _sync() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final accountState = context.read<AccountCubit>().state;
    if (accountState is! AccountLoaded || accountState.accounts.isEmpty) {
      _showSnack('Add at least one bank/account first', Colors.orange);
      return;
    }

    if (_selectedBank == null || _selectedBank!.isEmpty) {
      _showSnack('Select a bank', Colors.orange);
      return;
    }
    if (_selectedPlannerSection == null || _selectedPlannerSection!.isEmpty) {
      _showSnack('Select a planner section', Colors.orange);
      return;
    }
    if (_selectedSubtype == null || _selectedSubtype!.isEmpty) {
      _showSnack('Select a subtype', Colors.orange);
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
        category: _selectedSubtype!,
        account: _selectedBank!,
        date: sms.date,
        note:
            'Planner: $_selectedPlannerSection · Subtype: $_selectedSubtype\n${sms.body}',
      );

      await context.read<TransactionCubit>().addTransaction(transaction);

      if (sms.id != null) {
        await context.read<SmsCubit>().finalizeSync(sms.id!);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      if (!context.mounted) return;
      _showSnack('Synced to $_selectedPlannerSection · marked as read', Colors.green);
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
    final accent = isCredit ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final primary = Theme.of(context).colorScheme.primary;
    final dateFormat = DateFormat('MMM dd, yyyy · hh:mm a');
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final parsedAmount = double.tryParse(_amountController.text.trim());
    final media = MediaQuery.of(context);
    final subtypes = _subtypesFor(_selectedPlannerSection ?? 'Essentials');

    // Auto-select first account when none chosen yet.
    if (_selectedBank == null && accounts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selectedBank != null) return;
        setState(() => _selectedBank = accounts.first.name);
      });
    }

    final sheetHeight =
        widget.asPage ? media.size.height : media.size.height * 0.94;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        width: media.size.width,
        height: sheetHeight,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: widget.asPage
              ? BorderRadius.zero
              : const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Full-width top bar
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  20,
                  widget.asPage
                      ? (media.padding.top > 0 ? media.padding.top : 14)
                      : (media.padding.top > 0 ? 8 : 14),
                  12,
                  16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primary,
                      Color.lerp(primary, accent, 0.45)!,
                    ],
                  ),
                  borderRadius: widget.asPage
                      ? BorderRadius.zero
                      : const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.asPage)
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SMS setup',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                parsedAmount != null
                                    ? currency.format(parsedAmount)
                                    : '₹ —',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              Text(
                                dateFormat.format(widget.message.date),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isCredit ? 'Credit' : 'Debit',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.message.address.isEmpty
                          ? 'Unknown sender'
                          : widget.message.address,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.message.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                  children: [
                    _label('Account'),
                    const SizedBox(height: 10),
                    if (accounts.isEmpty)
                      _emptyHint('Add a bank/account first in Accounts')
                    else
                      ...accounts.map((a) {
                        final selected = _selectedBank == a.name;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedBank = a.name),
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: selected
                                    ? primary.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selected
                                      ? primary
                                      : Colors.grey.withOpacity(0.18),
                                  width: selected ? 1.6 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: selected
                                        ? primary.withOpacity(0.15)
                                        : Colors.grey.withOpacity(0.12),
                                    child: Icon(
                                      Icons.account_balance_rounded,
                                      color: selected
                                          ? primary
                                          : Colors.grey[700],
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          a.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: selected
                                                ? primary
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          a.lastDigits != null &&
                                                  a.lastDigits!.isNotEmpty
                                              ? '${a.type} · ···${a.lastDigits}'
                                              : a.type,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (selected)
                                    Icon(Icons.check_circle, color: primary),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 18),
                    _label('Planner category'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: SmsSyncSheet.plannerSections.map((section) {
                        final selected = _selectedPlannerSection == section;
                        return ChoiceChip(
                          label: Text(section),
                          selected: selected,
                          onSelected: (_) => _onPlannerSectionChanged(section),
                          selectedColor: primary.withOpacity(0.18),
                          labelStyle: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? primary : Colors.grey[800],
                            fontSize: 13,
                          ),
                          side: BorderSide(
                            color: selected
                                ? primary
                                : Colors.grey.withOpacity(0.25),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    _label('Subtype · $_selectedPlannerSection'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: subtypes.map((sub) {
                        final selected = _selectedSubtype == sub;
                        return FilterChip(
                          label: Text(sub),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedSubtype = sub),
                          selectedColor: accent.withOpacity(0.16),
                          checkmarkColor: accent,
                          labelStyle: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? accent : Colors.grey[800],
                            fontSize: 13,
                          ),
                          side: BorderSide(
                            color: selected
                                ? accent
                                : Colors.grey.withOpacity(0.25),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    _label('Type'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _TypeChip(
                            label: 'Debit',
                            icon: Icons.arrow_upward_rounded,
                            color: const Color(0xFFDC2626),
                            selected: !isCredit,
                            onTap: () => setState(() {
                              _selectedType = TransactionType.debit;
                              if (_selectedPlannerSection == 'Income') {
                                _applyPlannerSection('Essentials');
                              }
                            }),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TypeChip(
                            label: 'Credit',
                            icon: Icons.arrow_downward_rounded,
                            color: const Color(0xFF059669),
                            selected: isCredit,
                            onTap: () => setState(() {
                              _selectedType = TransactionType.credit;
                              _applyPlannerSection('Income');
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _label('Details'),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: _modernField(
                        label: 'Amount',
                        icon: Icons.currency_rupee,
                        prefix: '₹ ',
                      ),
                      validator: (value) {
                        final amount = double.tryParse(value?.trim() ?? '');
                        if (amount == null || amount <= 0) {
                          return 'Enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: _modernField(
                        label: 'Description',
                        icon: Icons.notes_outlined,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    if (_extractedName != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'From $_extractedName',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _isSyncing || accounts.isEmpty ? null : _sync,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSyncing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save to wallet',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: Colors.grey[800],
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: const TextStyle(color: Colors.orange)),
    );
  }

  InputDecoration _modernField({
    required String label,
    required IconData icon,
    String? prefix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixText: prefix,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.grey.withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.5,
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
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.12) : Colors.grey.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : Colors.grey.withOpacity(0.2),
              width: selected ? 1.6 : 1,
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
