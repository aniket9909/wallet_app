import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/account_model.dart';
import '../../../logic/cubits/account_cubit.dart';
import '../../theme/brand_colors.dart';
import 'onboarding_info_card.dart';

class OnboardingAccountStep extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  const OnboardingAccountStep({
    super.key,
    required this.onContinue,
    required this.onSkip,
  });

  @override
  State<OnboardingAccountStep> createState() => _OnboardingAccountStepState();
}

class _OnboardingAccountStepState extends State<OnboardingAccountStep> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();

  String _selectedType = 'Bank';
  bool _submitting = false;
  bool _showWhatHappens = false;
  final _accountTypes = ['Bank', 'Cash', 'UPI', 'Credit Card'];

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final balanceText = _balanceController.text.trim();
    final account = AccountModel(
      id: '',
      name: _nameController.text.trim(),
      balance: balanceText.isEmpty ? 0 : double.parse(balanceText),
      type: _selectedType,
    );

    await context.read<AccountCubit>().addAccount(account);

    if (!mounted) return;
    setState(() => _submitting = false);
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: BrandAppIcon(size: 80)),
                  const SizedBox(height: 20),
                  Text(
                    'Add your first account',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: BrandColors.navy,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Name is required. Current balance is optional — skip it if you are not sure yet.',
                    style: TextStyle(color: BrandColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () =>
                        setState(() => _showWhatHappens = !_showWhatHappens),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: BrandColors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: BrandColors.blue.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: BrandColors.blue, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'What happens when I continue?',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: BrandColors.navy,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Icon(
                            _showWhatHappens
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: BrandColors.blue,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showWhatHappens) ...[
                    const SizedBox(height: 12),
                    const OnboardingInfoCard(
                      icon: Icons.save_outlined,
                      iconColor: BrandColors.blue,
                      title: 'Continue',
                      body:
                          'Your account is saved locally and synced when online. It appears in Accounts and SMS transaction pickers.',
                      onTapHint:
                          'Next screen: set monthly income split and budget categories.',
                    ),
                    const OnboardingInfoCard(
                      icon: Icons.skip_next_outlined,
                      iconColor: BrandColors.muted,
                      title: 'Skip this step',
                      body:
                          'No account is added now. You can add one later from the Accounts tab.',
                      onTapHint: 'Goes to monthly budget setup, or skip that too from Home.',
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Account name *',
                      hintText: 'e.g. HDFC Bank',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter account name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _balanceController,
                    decoration: InputDecoration(
                      labelText: 'Current balance (optional)',
                      prefixText: '₹ ',
                      hintText: 'Leave blank if unknown',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: InputDecoration(
                      labelText: 'Account type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      for (final type in _accountTypes)
                        DropdownMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              Icon(_iconFor(type), size: 20),
                              const SizedBox(width: 10),
                              Text(type),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedType = v);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save & continue to budget',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _submitting ? null : widget.onSkip,
                child: const Text('Skip this step'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'Bank':
        return Icons.account_balance;
      case 'Cash':
        return Icons.money;
      case 'UPI':
        return Icons.qr_code_2;
      case 'Credit Card':
        return Icons.credit_card;
      default:
        return Icons.account_balance_wallet;
    }
  }
}
