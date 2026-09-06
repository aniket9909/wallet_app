import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/utils/planner_navigation.dart';
import '../../core/utils/sms_detection_util.dart';
import '../../data/models/account_model.dart';
import '../../data/models/money_plan_model.dart';
import '../../data/models/sms_message_model.dart';
import '../../data/models/transaction_model_new.dart';
import '../../logic/cubits/account_cubit.dart';
import '../../logic/cubits/money_plan_cubit.dart';
import '../../logic/cubits/sms_cubit.dart';
import '../../logic/cubits/transaction_cubit.dart';

/// Session gate so the stack opens once per home visit.
class PendingSmsReviewGate {
  static bool _shownThisSession = false;

  static bool get alreadyShown => _shownThisSession;

  static void markShown() => _shownThisSession = true;

  static void reset() => _shownThisSession = false;
}

/// Lightweight swipe card for the newest unsynced SMS (max 5).
class PendingSmsReviewStack extends StatefulWidget {
  final List<SmsMessageModel> messages;

  const PendingSmsReviewStack({super.key, required this.messages});

  static const maxReviewCount = 5;

  static Future<void> showIfNeeded(BuildContext context) async {
    if (PendingSmsReviewGate.alreadyShown) return;
    if (!context.mounted) return;

    // Let the dashboard paint first so the popup does not jank open.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!context.mounted || PendingSmsReviewGate.alreadyShown) return;

    List<SmsMessageModel> pending = const [];
    try {
      pending = await context.read<SmsCubit>().getPendingUnsyncedRecent(
            days: 5,
            limit: maxReviewCount,
          );
    } catch (_) {
      return;
    }

    if (!context.mounted || pending.isEmpty) return;

    PendingSmsReviewGate.markShown();

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Pending SMS review',
      barrierColor: const Color(0xFF0F172A).withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (ctx, anim, secondary) {
        return PendingSmsReviewStack(messages: pending);
      },
      transitionBuilder: (ctx, anim, secondary, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  @override
  State<PendingSmsReviewStack> createState() => _PendingSmsReviewStackState();
}

class _PendingSmsReviewStackState extends State<PendingSmsReviewStack> {
  late List<SmsMessageModel> _queue;
  final ValueNotifier<double> _dragDx = ValueNotifier<double>(0);
  bool _busy = false;
  bool _closing = false;

  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  String? _selectedBank;
  late String _selectedSection;
  late String _selectedSubtype;
  late TransactionType _txnType;

  static const _swipeThreshold = 110.0;

  @override
  void initState() {
    super.initState();
    _queue = List<SmsMessageModel>.from(
      widget.messages.take(PendingSmsReviewStack.maxReviewCount),
    );
    _amountController = TextEditingController();
    _descriptionController = TextEditingController();
    _bindCurrentSms();
  }

  @override
  void dispose() {
    _dragDx.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  SmsMessageModel? get _current => _queue.isEmpty ? null : _queue.first;

  MoneyPlanModel? _plan() {
    try {
      final state = context.read<MoneyPlanCubit>().state;
      if (state is MoneyPlanLoaded) return state.plan;
    } catch (_) {}
    return null;
  }

  List<String> _subtypes() {
    return PlannerCategories.subtypesFor(_selectedSection, plan: _plan());
  }

  void _bindCurrentSms() {
    final sms = _current;
    if (sms == null) return;

    _txnType = (sms.transactionType ?? '').toLowerCase() == 'credit'
        ? TransactionType.credit
        : TransactionType.debit;
    _selectedSection = PlannerCategories.defaultSectionFor(
      isCredit: _txnType == TransactionType.credit,
    );
    final subs = PlannerCategories.subtypesFor(_selectedSection, plan: _plan());
    _selectedSubtype = subs.isNotEmpty ? subs.first : 'Other';

    _amountController.text =
        sms.amount != null ? sms.amount!.toStringAsFixed(2) : '';
    final suggested = SmsDetectionUtil.suggestedSyncDescription(
      smsBody: sms.body,
      transactionType: sms.transactionType,
    );
    _descriptionController.text = suggested ?? '';
  }

  void _applySection(String section) {
    final subs = PlannerCategories.subtypesFor(section, plan: _plan());
    setState(() {
      _selectedSection = section;
      _selectedSubtype =
          subs.contains(_selectedSubtype) ? _selectedSubtype : (subs.isNotEmpty ? subs.first : 'Other');
    });
  }

  void _closeAll() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  Future<void> _advance() async {
    if (_queue.isEmpty) {
      _closeAll();
      return;
    }
    setState(_bindCurrentSms);
  }

  Future<void> _skipCurrent() async {
    if (_busy || _queue.isEmpty) return;
    setState(() {
      _queue.removeAt(0);
      _dragDx.value = 0;
    });
    await _advance();
  }

  Future<void> _deleteCurrent() async {
    if (_busy || _queue.isEmpty) return;
    final sms = _queue.first;
    setState(() => _busy = true);

    try {
      if (sms.id != null) {
        await context.read<SmsCubit>().markAsDecline(sms.id!, reload: false);
      }
    } catch (_) {
      if (sms.id != null) {
        await context.read<SmsCubit>().deleteSms(sms.id!);
      }
    }

    if (!mounted) return;
    setState(() {
      _queue.removeWhere((m) => m.id == sms.id);
      _dragDx.value = 0;
      _busy = false;
    });
    await _advance();
  }

  Future<void> _syncCurrent() async {
    if (_busy || _queue.isEmpty) return;
    final sms = _queue.first;

    final accounts = context.read<AccountCubit>().state;
    if (accounts is! AccountLoaded || accounts.accounts.isEmpty) {
      _toast('Add a bank account first', Colors.orange);
      return;
    }
    if (_selectedBank == null || _selectedBank!.isEmpty) {
      _toast('Select a bank account', Colors.orange);
      return;
    }
    if (_selectedSubtype.isEmpty) {
      _toast('Select a subcategory', Colors.orange);
      return;
    }
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _toast('Enter a valid amount', Colors.orange);
      return;
    }

    setState(() => _busy = true);

    try {
      final description = SmsDetectionUtil.resolveSyncDescription(
        smsBody: sms.body,
        userDescription: _descriptionController.text,
        transactionType: sms.transactionType,
      );

      final transaction = TransactionModelNew(
        id: '',
        type: _txnType,
        amount: amount,
        description: description,
        category: _selectedSubtype,
        account: _selectedBank!,
        date: sms.date,
        note: PlannerCategories.formatNote(
          section: _selectedSection,
          subtype: _selectedSubtype,
          extra: sms.body,
        ),
      );

      await context.read<TransactionCubit>().addTransaction(transaction);
      if (sms.id != null) {
        await context.read<SmsCubit>().finalizeSync(sms.id!, reload: false);
      }

      if (!mounted) return;
      setState(() {
        _queue.removeWhere((m) => m.id == sms.id);
        _dragDx.value = 0;
        _busy = false;
      });
      _toast('Saved · $_selectedSection · $_selectedSubtype', Colors.green);
      await _advance();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('Sync failed: $e', Colors.red);
      }
    }
  }

  void _toast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onHeaderDragUpdate(DragUpdateDetails d) {
    if (_busy) return;
    _dragDx.value += d.delta.dx;
  }

  void _onHeaderDragEnd(DragEndDetails details) {
    if (_busy) return;
    final dx = _dragDx.value;
    if (dx <= -_swipeThreshold) {
      _deleteCurrent();
    } else if (dx >= _swipeThreshold) {
      _skipCurrent();
    } else {
      _dragDx.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sms = _current;
    final isCredit = _txnType == TransactionType.credit;
    final accent = isCredit ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final dateFmt = DateFormat('dd MMM · hh:mm a');

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 14,
            right: 14,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 10,
          ),
          child: Column(
            children: [
              _topBar(),
              const SizedBox(height: 10),
              Expanded(
                child: sms == null
                    ? const Center(
                        child: Text(
                          'All caught up',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      )
                    : ValueListenableBuilder<double>(
                        valueListenable: _dragDx,
                        builder: (context, dragDx, child) {
                          final rotation =
                              (dragDx / 420).clamp(-0.12, 0.12);
                          final skipOpacity =
                              (dragDx / _swipeThreshold).clamp(0.0, 1.0);
                          final deleteOpacity =
                              (-dragDx / _swipeThreshold).clamp(0.0, 1.0);
                          return Transform.translate(
                            offset: Offset(dragDx * 0.35, 0),
                            child: Transform.rotate(
                              angle: rotation,
                              child: Stack(
                                children: [
                                  child!,
                                  Positioned(
                                    top: 18,
                                    left: 18,
                                    child: Opacity(
                                      opacity: deleteOpacity,
                                      child: _stamp(
                                        'REMOVE',
                                        const Color(0xFFFECACA),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 18,
                                    right: 18,
                                    child: Opacity(
                                      opacity: skipOpacity,
                                      child: _stamp(
                                        'SKIP',
                                        const Color(0xFFBBF7D0),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: _modernCard(
                          theme: theme,
                          sms: sms,
                          accent: accent,
                          isCredit: isCredit,
                          currency: currency,
                          dateFmt: dateFmt,
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              if (sms != null) _actionRow(accent),
              TextButton(
                onPressed: _closeAll,
                child: const Text(
                  'Close all & later',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.sms_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Review bank SMS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              Text(
                _queue.isEmpty
                    ? 'Nothing left'
                    : '${_queue.length} of ${PendingSmsReviewStack.maxReviewCount} latest',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _closeAll,
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _modernCard({
    required ThemeData theme,
    required SmsMessageModel sms,
    required Color accent,
    required bool isCredit,
    required NumberFormat currency,
    required DateFormat dateFmt,
  }) {
    final subtypes = _subtypes();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          GestureDetector(
            onHorizontalDragUpdate: _onHeaderDragUpdate,
            onHorizontalDragEnd: _onHeaderDragEnd,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              color: accent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _pill(isCredit ? 'CREDIT' : 'DEBIT'),
                      const Spacer(),
                      Text(
                        dateFmt.format(sms.date),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    sms.amount != null ? currency.format(sms.amount) : '₹ —',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sms.address.isEmpty ? 'Unknown sender' : sms.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sms.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      height: 1.3,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<AccountCubit, AccountState>(
              buildWhen: (prev, next) =>
                  next is AccountLoaded || next is AccountLoading,
              builder: (context, accountState) {
                final accounts = accountState is AccountLoaded
                    ? accountState.accounts
                    : <AccountModel>[];

                if (_selectedBank == null && accounts.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || _selectedBank != null) return;
                    setState(() => _selectedBank = accounts.first.name);
                  });
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  children: [
                    _sectionLabel('Bank account'),
                    const SizedBox(height: 8),
                    if (accounts.isEmpty)
                      _hintBox('Add a bank account in Accounts first')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: accounts.map((a) {
                          final selected = _selectedBank == a.name;
                          return ChoiceChip(
                            label: Text(
                              a.lastDigits != null && a.lastDigits!.isNotEmpty
                                  ? '${a.name} ···${a.lastDigits}'
                                  : a.name,
                            ),
                            selected: selected,
                            selectedColor: accent.withOpacity(0.16),
                            onSelected: (_) =>
                                setState(() => _selectedBank = a.name),
                            labelStyle: TextStyle(
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? accent : Colors.grey[800],
                              fontSize: 12.5,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? accent
                                  : Colors.grey.withOpacity(0.28),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 14),
                    _sectionLabel('Category'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PlannerSections.pickerOrder.map((section) {
                        final selected = _selectedSection == section;
                        final color = PlannerSections.colorFor(section);
                        return ChoiceChip(
                          avatar: Icon(
                            PlannerSections.iconFor(section),
                            size: 15,
                            color: selected ? color : Colors.grey[700],
                          ),
                          label: Text(section),
                          selected: selected,
                          selectedColor: color.withOpacity(0.16),
                          onSelected: (_) => _applySection(section),
                          labelStyle: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? color : Colors.grey[800],
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: selected
                                ? color
                                : Colors.grey.withOpacity(0.28),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    _sectionLabel('Subcategory'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: subtypes.map((sub) {
                        final selected = _selectedSubtype == sub;
                        final color =
                            PlannerSections.colorFor(_selectedSection);
                        return FilterChip(
                          label: Text(sub),
                          selected: selected,
                          selectedColor: color.withOpacity(0.16),
                          checkmarkColor: color,
                          onSelected: (_) =>
                              setState(() => _selectedSubtype = sub),
                          labelStyle: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? color : Colors.grey[800],
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: selected
                                ? color
                                : Colors.grey.withOpacity(0.28),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    _sectionLabel('Details'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _typeToggle(
                            label: 'Debit',
                            selected: !isCredit,
                            color: const Color(0xFFDC2626),
                            onTap: () {
                              setState(() {
                                _txnType = TransactionType.debit;
                              });
                              if (_selectedSection == PlannerSections.income) {
                                _applySection(PlannerSections.essentials);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _typeToggle(
                            label: 'Credit',
                            selected: isCredit,
                            color: const Color(0xFF059669),
                            onTap: () {
                              setState(() {
                                _txnType = TransactionType.credit;
                              });
                              _applySection(PlannerSections.income);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _fieldDeco(
                        label: 'Amount',
                        prefix: '₹ ',
                        icon: Icons.currency_rupee,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _fieldDeco(
                        label: 'Description',
                        icon: Icons.notes_outlined,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(Color accent) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _busy ? null : _deleteCurrent,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade200,
              side: BorderSide(color: Colors.red.withOpacity(0.45)),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Remove'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: _busy ? null : _syncCurrent,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Sync & save'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: _busy ? null : _skipCurrent,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withOpacity(0.35)),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Skip'),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 13,
        color: Colors.grey[850],
      ),
    );
  }

  Widget _hintBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(color: Colors.orange)),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _typeToggle({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.grey.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey.withOpacity(0.2),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? color : Colors.grey[700],
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDeco({
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _stamp(String text, Color color) {
    return Transform.rotate(
      angle: text == 'SKIP' ? 0.22 : -0.22,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
