import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/money_plan_model.dart';
import '../../../logic/cubits/money_plan_cubit.dart';
import '../../widgets/money_planner/money_plan_widgets.dart';
import '../../theme/brand_colors.dart';
import '../../theme/onboarding_assets.dart';

class MoneyPlanSetupWizard extends StatefulWidget {
  final bool isOnboarding;
  final VoidCallback? onFinished;
  final VoidCallback? onSkipped;

  const MoneyPlanSetupWizard({
    super.key,
    this.isOnboarding = false,
    this.onFinished,
    this.onSkipped,
  });

  @override
  State<MoneyPlanSetupWizard> createState() => _MoneyPlanSetupWizardState();
}

class _MoneyPlanSetupWizardState extends State<MoneyPlanSetupWizard> {
  final _pageController = PageController();
  int _step = 0;
  static const _totalSteps = 7;

  late PlanIncome _income;
  late List<PlanExpense> _expenses;
  late List<PlanInvestment> _investments;
  late PlanEmergencyFund _emergency;
  late List<PlanGoal> _goals;
  late List<PlanDebt> _debts;
  late double _personal;
  int _cycleStartDay = 1;

  final _incomeCtrl = TextEditingController(text: '40000');
  final _otherIncomeCtrl = TextEditingController(text: '0');
  final _minIncomeCtrl = TextEditingController();
  final _sipCtrl = TextEditingController(text: '7500');
  final _sipMinCtrl = TextEditingController(text: '7500');
  final _efCurrentCtrl = TextEditingController(text: '0');
  final _efMonthsCtrl = TextEditingController(text: '6');
  final _efMonthlyCtrl = TextEditingController(text: '4000');
  final _personalCtrl = TextEditingController(text: '3500');

  // Goal draft
  final _goalNameCtrl = TextEditingController();
  final _goalTargetCtrl = TextEditingController();
  final _goalSavedCtrl = TextEditingController(text: '0');
  DateTime? _goalDate;
  PlanPriority _goalPriority = PlanPriority.medium;
  bool _goalIsGold = false;
  final _goldTolaCtrl = TextEditingController(text: '1');
  final _goldPriceCtrl = TextEditingController(text: '7000');

  // Debt draft
  final _debtNameCtrl = TextEditingController();
  final _debtEmiCtrl = TextEditingController();
  final _debtMonthsCtrl = TextEditingController();
  final _debtOutstandingCtrl = TextEditingController();

  static const _defaultExpenseDefs = [
    ('Housing/Rent', 8000.0, ExpenseKind.staticExpense, true),
    ('Electricity', 1500.0, ExpenseKind.dynamicExpense, false),
    ('Internet/Phone', 800.0, ExpenseKind.staticExpense, true),
    ('Food & Groceries', 7000.0, ExpenseKind.dynamicExpense, false),
    ('Transportation', 3000.0, ExpenseKind.dynamicExpense, false),
    ('Healthcare', 1000.0, ExpenseKind.optionalExpense, false),
    ('Insurance', 1500.0, ExpenseKind.staticExpense, true),
    ('Family responsibilities', 2000.0, ExpenseKind.staticExpense, true),
  ];

  late List<TextEditingController> _expenseAmountCtrls;

  @override
  void initState() {
    super.initState();
    final template = MoneyPlanModel.starterTemplate();
    _income = template.income;
    _expenses = _defaultExpenseDefs
        .asMap()
        .entries
        .map(
          (e) => PlanExpense(
            id: 'exp_${e.key}',
            name: e.value.$1,
            monthlyAmount: e.value.$2,
            kind: e.value.$3,
            isProtected: e.value.$4,
            priority: e.value.$4 ? PlanPriority.critical : PlanPriority.high,
          ),
        )
        .toList();
    _expenseAmountCtrls = _expenses
        .map((e) => TextEditingController(
              text: e.monthlyAmount.toStringAsFixed(0),
            ))
        .toList();
    _investments = template.investments;
    _emergency = template.emergencyFund;
    _goals = [];
    _debts = [];
    _personal = template.personalSpending;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _incomeCtrl.dispose();
    _otherIncomeCtrl.dispose();
    _minIncomeCtrl.dispose();
    _sipCtrl.dispose();
    _sipMinCtrl.dispose();
    _efCurrentCtrl.dispose();
    _efMonthsCtrl.dispose();
    _efMonthlyCtrl.dispose();
    _personalCtrl.dispose();
    _goalNameCtrl.dispose();
    _goalTargetCtrl.dispose();
    _goalSavedCtrl.dispose();
    _goldTolaCtrl.dispose();
    _goldPriceCtrl.dispose();
    _debtNameCtrl.dispose();
    _debtEmiCtrl.dispose();
    _debtMonthsCtrl.dispose();
    _debtOutstandingCtrl.dispose();
    for (final c in _expenseAmountCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _goTo(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  void _syncFromControllers() {
    final monthly = double.tryParse(_incomeCtrl.text) ?? 0;
    final other = double.tryParse(_otherIncomeCtrl.text) ?? 0;
    final minIncome = double.tryParse(_minIncomeCtrl.text);
    _income = PlanIncome(
      monthlyIncome: monthly,
      otherIncome: other,
      minimumExpectedIncome: minIncome,
    );

    _expenses = [
      for (var i = 0; i < _expenses.length; i++)
        _expenses[i].copyWith(
          monthlyAmount: double.tryParse(_expenseAmountCtrls[i].text) ?? 0,
        ),
    ];

    final sip = double.tryParse(_sipCtrl.text) ?? 0;
    final sipMin = double.tryParse(_sipMinCtrl.text) ?? sip;
    _investments = [
      PlanInvestment(
        id: 'sip_main',
        name: 'SIP',
        type: InvestmentType.sip,
        monthlyAmount: sip,
        minimumAmount: sipMin,
        isProtected: true,
        priority: PlanPriority.critical,
      ),
    ];

    final essentials =
        _expenses.fold<double>(0, (s, e) => s + e.monthlyAmount);
    _emergency = PlanEmergencyFund(
      currentSavings: double.tryParse(_efCurrentCtrl.text) ?? 0,
      monthlyEssentialExpenses: essentials,
      targetMonths: int.tryParse(_efMonthsCtrl.text) ?? 6,
      monthlyContribution: double.tryParse(_efMonthlyCtrl.text) ?? 0,
      isProtected: true,
      priority: PlanPriority.high,
    );

    _personal = double.tryParse(_personalCtrl.text) ?? 0;
  }

  MoneyPlanModel _buildPlan({bool complete = false}) {
    _syncFromControllers();
    return MoneyPlanModel(
      setupComplete: complete,
      cycleStartDay: _cycleStartDay.clamp(1, 28),
      income: _income,
      expenses: _expenses,
      investments: _investments,
      emergencyFund: _emergency,
      goals: _goals,
      debts: _debts,
      personalSpending: _personal,
      rules: MoneyPlanModel.starterTemplate().rules,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _finish() async {
    final plan = _buildPlan(complete: true);
    await context.read<MoneyPlanCubit>().completeSetup(plan);
    if (!mounted) return;
    widget.onFinished?.call();
  }

  void _addGoal() {
    final name = _goalNameCtrl.text.trim();
    if (name.isEmpty) return;

    PlanGoldDetails? gold;
    double target = double.tryParse(_goalTargetCtrl.text) ?? 0;
    if (_goalIsGold) {
      gold = PlanGoldDetails(
        quantityTola: double.tryParse(_goldTolaCtrl.text) ?? 1,
        pricePerGram: double.tryParse(_goldPriceCtrl.text) ?? 0,
        priceBufferPercent: 5,
        priceSource: 'manual',
      );
      target = gold.estimatedCost;
    }

    final goal = PlanGoal(
      id: const Uuid().v4(),
      name: name,
      goalType: _goalIsGold ? GoalType.gold : GoalType.standard,
      targetAmount: target,
      currentAmount: double.tryParse(_goalSavedCtrl.text) ?? 0,
      targetDate: _goalDate ?? DateTime.now().add(const Duration(days: 365)),
      priority: _goalPriority,
      goldDetails: gold,
      isFlexible: _goalPriority.rank >= PlanPriority.medium.rank,
    );

    setState(() {
      _goals = [
        ..._goals,
        goal.copyWith(
          monthlyContribution: goal.requiredMonthlyContribution,
        ),
      ];
      _goalNameCtrl.clear();
      _goalTargetCtrl.clear();
      _goalSavedCtrl.text = '0';
      _goalIsGold = false;
    });
  }

  void _addDebt() {
    final name = _debtNameCtrl.text.trim();
    final emi = double.tryParse(_debtEmiCtrl.text) ?? 0;
    if (name.isEmpty || emi <= 0) return;
    final months = int.tryParse(_debtMonthsCtrl.text) ?? 0;
    setState(() {
      _debts = [
        ..._debts,
        PlanDebt(
          id: const Uuid().v4(),
          name: name,
          emi: emi,
          remainingMonths: months,
          outstanding: double.tryParse(_debtOutstandingCtrl.text) ?? emi * months,
          principal: double.tryParse(_debtOutstandingCtrl.text) ?? emi * months,
          isMandatory: true,
          priority: PlanPriority.critical,
          endDate: months > 0
              ? DateTime.now().add(Duration(days: months * 30))
              : null,
        ),
      ];
      _debtNameCtrl.clear();
      _debtEmiCtrl.clear();
      _debtMonthsCtrl.clear();
      _debtOutstandingCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isOnboarding)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: widget.onSkipped,
                        child: const Text('Skip this step'),
                      ),
                    ),
                  Center(
                    child: widget.isOnboarding
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset(
                              OnboardingAssets.budget,
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                            ),
                          )
                        : const BrandLogo(width: 120),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.isOnboarding
                        ? 'Set up your monthly budget'
                        : 'All-in-One Money Planner',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: BrandColors.navy,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.isOnboarding
                        ? 'Step 3 of 3 · Monthly budget'
                        : 'Step ${_step + 1} of $_totalSteps',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: widget.isOnboarding
                          ? (2 + ((_step + 1) / _totalSteps)) / 3
                          : (_step + 1) / _totalSteps,
                      minHeight: 6,
                      backgroundColor: primary.withOpacity(0.12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _incomeStep(),
                  _expensesStep(),
                  _investmentStep(),
                  _emergencyStep(),
                  _goalsStep(),
                  _debtStep(),
                  _reviewStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: () => _goTo(_step - 1),
                      child: const Text('Back'),
                    ),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (_step < _totalSteps - 1) {
                          _syncFromControllers();
                          _goTo(_step + 1);
                        } else {
                          _finish();
                        }
                      },
                      child: Text(
                        _step < _totalSteps - 1 ? 'Continue' : 'Finish setup',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepShell({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], height: 1.4),
        ),
        const SizedBox(height: 20),
        child,
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType type = TextInputType.number,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
        ),
      ),
    );
  }

  Widget _incomeStep() {
    return _stepShell(
      title: 'Income',
      subtitle:
          'Available monthly income = regular income + other income. Pick which day your budget month starts.',
      child: Column(
        children: [
          _field('Monthly income', _incomeCtrl, hint: '40000'),
          _field('Other regular income', _otherIncomeCtrl),
          _field('Expected minimum monthly income', _minIncomeCtrl),
          DropdownButtonFormField<int>(
            value: _cycleStartDay,
            decoration: const InputDecoration(
              labelText: 'Budget month starts on day',
              helperText:
                  'Example: day 7 → this cycle runs from the 7th to next month’s 7th',
            ),
            items: [
              for (var d = 1; d <= 28; d++)
                DropdownMenuItem(
                  value: d,
                  child: Text(
                    d == 1
                        ? '1 · Calendar month (1st–end)'
                        : '$d · $d${_daySuffix(d)} → next month $d${_daySuffix(d)}',
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _cycleStartDay = v);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: 'monthly',
            decoration: const InputDecoration(labelText: 'Income frequency'),
            items: const [
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
              DropdownMenuItem(value: 'biweekly', child: Text('Bi-weekly')),
            ],
            onChanged: (_) {},
          ),
        ],
      ),
    );
  }

  String _daySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  Widget _expensesStep() {
    return _stepShell(
      title: 'Essential expenses',
      subtitle:
          'Static expenses stay protected. Dynamic/optional ones can flex when the plan is tight.',
      child: Column(
        children: [
          for (var i = 0; i < _expenses.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _expenses[i].name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            _expenses[i].kind.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _expenseAmountCtrls[i],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monthly amount',
                        prefixText: '₹ ',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _investmentStep() {
    return _stepShell(
      title: 'Protected investment',
      subtitle:
          'Mark a minimum SIP as “do not compromise”. The planner will show a budget conflict instead of silently reducing it.',
      child: Column(
        children: [
          _field('Existing / target SIP (₹/month)', _sipCtrl),
          _field('Protected minimum SIP', _sipMinCtrl),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield, color: Colors.green),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Priority: Critical — protected investment will not be auto-reduced.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emergencyStep() {
    return _stepShell(
      title: 'Emergency fund',
      subtitle:
          'Target = essential monthly expenses × months. Once reached, this monthly allocation frees up automatically.',
      child: Column(
        children: [
          _field('Current emergency savings', _efCurrentCtrl),
          _field('Target months (3–6 recommended)', _efMonthsCtrl),
          _field('Monthly contribution', _efMonthlyCtrl),
        ],
      ),
    );
  }

  Widget _goalsStep() {
    return _stepShell(
      title: 'Goals',
      subtitle:
          'Required monthly contribution = remaining amount ÷ remaining months. Gold uses live quantity × price + buffer.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Gold goal'),
            value: _goalIsGold,
            onChanged: (v) => setState(() => _goalIsGold = v),
          ),
          _field('Goal name', _goalNameCtrl, type: TextInputType.text),
          if (_goalIsGold) ...[
            _field('Quantity (tola)', _goldTolaCtrl),
            _field('Price per gram', _goldPriceCtrl),
          ] else
            _field('Target amount', _goalTargetCtrl),
          _field('Already saved', _goalSavedCtrl),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _goalDate == null
                  ? 'Pick target date'
                  : 'Target: ${_goalDate!.day}/${_goalDate!.month}/${_goalDate!.year}',
            ),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 180)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked != null) setState(() => _goalDate = picked);
            },
          ),
          DropdownButtonFormField<PlanPriority>(
            value: _goalPriority,
            decoration: const InputDecoration(labelText: 'Priority'),
            items: PlanPriority.values
                .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _goalPriority = v);
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addGoal,
            icon: const Icon(Icons.add),
            label: const Text('Add goal'),
          ),
          const SizedBox(height: 12),
          ..._goals.map(
            (g) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                g.goalType == GoalType.gold
                    ? Icons.monetization_on
                    : Icons.flag,
              ),
              title: Text(
                g.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${moneyInr.format(g.requiredMonthlyContribution)}/mo · ${g.priority.label}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  setState(() {
                    _goals = _goals.where((x) => x.id != g.id).toList();
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _debtStep() {
    return _stepShell(
      title: 'Debt & EMIs',
      subtitle:
          'EMIs are static mandatory expenses until finished. When an EMI ends, cash flow is suggested for reallocation.',
      child: Column(
        children: [
          _field('Loan name', _debtNameCtrl, type: TextInputType.text),
          _field('EMI amount', _debtEmiCtrl),
          _field('Remaining months', _debtMonthsCtrl),
          _field('Outstanding balance', _debtOutstandingCtrl),
          OutlinedButton.icon(
            onPressed: _addDebt,
            icon: const Icon(Icons.add),
            label: const Text('Add EMI'),
          ),
          const SizedBox(height: 12),
          ..._debts.map(
            (d) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                d.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${moneyInr.format(d.emi)}/mo · ${d.remainingMonths} months left',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  setState(() {
                    _debts = _debts.where((x) => x.id != d.id).toList();
                  });
                },
              ),
            ),
          ),
          const Divider(height: 32),
          _field('Personal / discretionary spending', _personalCtrl),
        ],
      ),
    );
  }

  Widget _reviewStep() {
    final plan = _buildPlan();
    final income = plan.income.availableMonthlyIncome;
    final essentials =
        plan.expenses.fold<double>(0, (s, e) => s + e.monthlyAmount);
    final invest =
        plan.investments.fold<double>(0, (s, e) => s + e.monthlyAmount);
    final goals =
        plan.goals.fold<double>(0, (s, g) => s + g.monthlyContribution);
    final debt = plan.debts.fold<double>(0, (s, d) => s + d.emi);
    final emergency = plan.emergencyFund.monthlyContribution;
    final planned =
        essentials + invest + goals + debt + emergency + plan.personalSpending;

    double pct(double a) => income <= 0 ? 0 : a / income * 100;

    return _stepShell(
      title: 'Your Money Plan',
      subtitle: '100% of income accounted for — percentages are calculated, not hard-coded.',
      child: Column(
        children: [
          _reviewRow('Income', income, 100),
          _reviewRow('Essential expenses', essentials, pct(essentials)),
          _reviewRow('Protected investment', invest, pct(invest)),
          _reviewRow('Goals', goals, pct(goals)),
          _reviewRow('Emergency fund', emergency, pct(emergency)),
          _reviewRow('Debt / EMI', debt, pct(debt)),
          _reviewRow('Flexible spending', plan.personalSpending,
              pct(plan.personalSpending)),
          const Divider(height: 28),
          _reviewRow('Planned total', planned, pct(planned)),
          _reviewRow('Remaining', income - planned, pct(income - planned)),
          const SizedBox(height: 12),
          Text(
            income - planned >= -1
                ? 'Your plan is ready.'
                : 'Plan is over budget — adjust before continuing.',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: income - planned >= -1 ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(String label, double amount, double pct) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: Text(
              moneyInr.format(amount),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: Text(
              '${pct.toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
