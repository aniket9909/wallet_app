import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../logic/cubits/settings_cubit.dart';
import '../../logic/cubits/account_cubit.dart';
import '../../logic/cubits/transaction_cubit.dart';
import '../../logic/cubits/partial_transaction_cubit.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/partial_transaction_model.dart';
import '../../data/models/transaction_model_new.dart';
import '../widgets/settings_section.dart';
import '../../routes/app_routes.dart';
import 'account_last_digits_screen.dart';
import 'package:intl/intl.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  void _testSmsFunctionality() {
    final accountState = context.read<AccountCubit>().state;
    if (accountState is! AccountLoaded || accountState.accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one account first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Create dummy static SMS transaction
    final firstAccount = accountState.accounts.first;
    final dummySms = PartialTransaction(
      id: 'test-${DateTime.now().millisecondsSinceEpoch}',
      accountName: firstAccount.name,
      amount: 1500.0,
      type: TransactionType.debit,
      description: 'SMS debit ${firstAccount.lastDigits ?? "XXXX"}',
      date: DateTime.now(),
      smsBody: 'Your A/c ${firstAccount.lastDigits ?? "XXXX"} debited by INR 1,500.00 on ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}. Avl Bal: INR 25,000.00',
      matchedDigits: firstAccount.lastDigits ?? 'XXXX',
    );

    _showSmsReviewSheet([dummySms]);
  }

  void _showSmsReviewSheet(List<PartialTransaction> partials) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SmsReviewSheet(
        partials: partials,
        onAccept: (p) {
          final transaction = TransactionModelNew(
            id: '',
            type: p.type,
            amount: p.amount,
            description: p.description,
            category: 'SMS Import',
            account: p.accountName,
            date: p.date,
            note: p.smsBody,
          );
          context.read<TransactionCubit>().addTransaction(transaction);
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        },
        onReject: (p) {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction rejected'),
              backgroundColor: Colors.orange,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
              Theme.of(context).colorScheme.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with Tabs
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Settings', icon: Icon(Icons.settings)),
                  Tab(text: 'Partial Transactions', icon: Icon(Icons.receipt_long)),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSettingsTab(context),
                    _buildPartialTransactionsTab(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTab(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        if (state is SettingsLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is SettingsError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                const Text('Error loading settings'),
                const SizedBox(height: 8),
                Text(state.message),
              ],
            ),
          );
        }

        if (state is SettingsLoaded) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Section
                      _buildProfileCard(context, state.settings.profile)
                          .animate()
                          .fadeIn(duration: 600.ms)
                          .slideY(begin: -0.2, end: 0),
                      const SizedBox(height: 16),

                      // App Settings
                      SettingsSection(
                        title: 'App Settings',
                        items: [
                          SettingsTile(
                            icon: Icons.notifications_outlined,
                            title: 'Notifications',
                            trailing: Switch(
                              value: state.settings.notificationsEnabled,
                              onChanged: (value) {
                                context.read<SettingsCubit>().toggleNotifications();
                              },
                            ),
                          ),
                          SettingsTile(
                            icon: Icons.dark_mode_outlined,
                            title: 'Dark Mode',
                            trailing: Switch(
                              value: state.settings.darkMode,
                              onChanged: (value) {
                                context.read<SettingsCubit>().toggleDarkMode();
                              },
                            ),
                          ),
                          SettingsTile(
                            icon: Icons.language,
                            title: 'Currency',
                            subtitle: state.settings.currency,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              // Navigate to currency selection
                            },
                          ),
                        ],
                      ).animate(delay: 200.ms).fadeIn(duration: 600.ms),
                      const SizedBox(height: 16),

                      // Financial Details (modernized)
                      SettingsSection(
                        title: 'Financial Details',
                        items: [
                          SettingsTile(
                            icon: Icons.tag,
                            title: 'Account Last Digits',
                            subtitle: 'Store last 4/6 digits for accounts',
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AccountLastDigitsScreen(),
                                ),
                              );
                            },
                          ),
                          SettingsTile(
                            icon: Icons.credit_card,
                            title: 'Card Details',
                            subtitle: state.settings.cardDetails != null
                                ? 'Card added'
                                : 'Not added',
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              _showCardDetailsDialog(context, state.settings);
                            },
                          ),
                        ],
                      ).animate(delay: 400.ms).fadeIn(duration: 600.ms),
                      const SizedBox(height: 16),

                      // Expense Categories
                      SettingsSection(
                        title: 'Expense Categories',
                        items: [
                          SettingsTile(
                            icon: Icons.category_outlined,
                            title: 'Manage Categories',
                            subtitle: '${state.settings.expenseTypes.length} categories',
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              _showCategoriesDialog(context, state.settings);
                            },
                          ),
                        ],
                      ).animate(delay: 600.ms).fadeIn(duration: 600.ms),
                      const SizedBox(height: 16),

                      // Testing Section
                      SettingsSection(
                        title: 'Testing',
                        items: [
                          SettingsTile(
                            icon: Icons.bug_report_outlined,
                            title: 'Test SMS Functionality',
                            subtitle: 'Test SMS transaction detection',
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _testSmsFunctionality,
                          ),
                        ],
                      ).animate(delay: 800.ms).fadeIn(duration: 600.ms),
                      const SizedBox(height: 16),

                      // About
                      SettingsSection(
                        title: 'About',
                        items: [
                          SettingsTile(
                            icon: Icons.info_outline,
                            title: 'About App',
                            subtitle: 'Version 1.0.0',
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {},
                          ),
                          SettingsTile(
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy Policy',
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {},
                          ),
                          SettingsTile(
                            icon: Icons.description_outlined,
                            title: 'Terms of Service',
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {},
                          ),
                        ],
                      ).animate(delay: 800.ms).fadeIn(duration: 600.ms),
                      const SizedBox(height: 16),

                      // Logout Button
                      _buildLogoutButton(context)
                          .animate(delay: 1000.ms)
                          .fadeIn(duration: 600.ms),
                const SizedBox(height: 80),
              ],
            ),
          );
        }

        return const SizedBox();
      },
    );
  }

  Widget _buildPartialTransactionsTab(BuildContext context) {
    return BlocBuilder<PartialTransactionCubit, PartialTransactionState>(
      builder: (context, state) {
        if (state is PartialTransactionLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is PartialTransactionError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error: ${state.message}'),
              ],
            ),
          );
        }

        if (state is PartialTransactionLoaded) {
          return Column(
            children: [
              // Add Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Partial Transactions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddPartialDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: state.partials.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No partial transactions',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          context.read<PartialTransactionCubit>().loadPartialTransactions();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: state.partials.length,
                          itemBuilder: (context, index) {
                            final partial = state.partials[index];
                            return _PartialTransactionCard(partial: partial)
                                .animate()
                                .fadeIn(duration: 300.ms, delay: (index * 50).ms)
                                .slideX(begin: 0.1, end: 0);
                          },
                        ),
                      ),
              ),
            ],
          );
        }

        return const SizedBox();
      },
    );
  }

  void _showAddPartialDialog(BuildContext context) {
    final accountState = context.read<AccountCubit>().state;
    if (accountState is! AccountLoaded || accountState.accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one account first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final smsBodyController = TextEditingController();
    final digitsController = TextEditingController();
    TransactionType selectedType = TransactionType.debit;
    String? selectedAccount;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Partial Transaction'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Account'),
                    items: accountState.accounts.map((acc) {
                      return DropdownMenuItem(
                        value: acc.name,
                        child: Text(acc.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedAccount = value;
                        final acc = accountState.accounts
                            .firstWhere((a) => a.name == value);
                        digitsController.text = acc.lastDigits ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TransactionType>(
                    decoration: const InputDecoration(labelText: 'Type'),
                    value: selectedType,
                    items: [
                      DropdownMenuItem(
                        value: TransactionType.credit,
                        child: const Text('Credit'),
                      ),
                      DropdownMenuItem(
                        value: TransactionType.debit,
                        child: const Text('Debit'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: digitsController,
                    decoration: const InputDecoration(labelText: 'Last Digits'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: smsBodyController,
                    decoration: const InputDecoration(labelText: 'SMS Body'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (selectedAccount == null ||
                      amountController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill all required fields'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final amount = double.tryParse(amountController.text);
                  if (amount == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid amount'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final partial = PartialTransaction(
                    id: '',
                    accountName: selectedAccount!,
                    amount: amount,
                    type: selectedType,
                    description: descriptionController.text.isEmpty
                        ? 'SMS ${selectedType == TransactionType.credit ? 'credit' : 'debit'} ${digitsController.text}'
                        : descriptionController.text,
                    date: DateTime.now(),
                    smsBody: smsBodyController.text.isEmpty
                        ? 'Test SMS transaction'
                        : smsBodyController.text,
                    matchedDigits: digitsController.text,
                  );

                  context.read<PartialTransactionCubit>().addPartialTransaction(partial);
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Partial transaction added'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, UserProfile profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white,
            backgroundImage: profile.avatar != null
                ? NetworkImage(profile.avatar!)
                : null,
            child: profile.avatar == null
                ? Text(
                    profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'U',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),

          // Profile Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name.isNotEmpty ? profile.name : 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.email,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                if (profile.phone != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    profile.phone!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Edit Button
          IconButton(
            onPressed: () {
              // Navigate to edit profile
            },
            icon: const Icon(Icons.edit, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Logout'),
                content: const Text('Are you sure you want to logout?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Logout', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );

            if (confirm == true && context.mounted) {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              }
            }
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Bank details dialog removed as per latest settings requirements

  void _showCardDetailsDialog(BuildContext context, SettingsModel settings) {
    final cardNumberController = TextEditingController(
      text: settings.cardDetails?.cardNumber ?? '',
    );
    final expiryController = TextEditingController(
      text: settings.cardDetails?.expiry ?? '',
    );
    String cardType = settings.cardDetails?.cardType ?? 'Debit';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Card Details'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: cardNumberController,
                    decoration: const InputDecoration(labelText: 'Card Number'),
                  ),
                  TextField(
                    controller: expiryController,
                    decoration: const InputDecoration(labelText: 'Expiry (MM/YY)'),
                  ),
                  DropdownButtonFormField<String>(
                    value: cardType,
                    decoration: const InputDecoration(labelText: 'Card Type'),
                    items: ['Debit', 'Credit'].map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        cardType = value!;
                      });
                    },
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final updatedSettings = settings.copyWith(
                cardDetails: CardDetails(
                  cardNumber: cardNumberController.text,
                  expiry: expiryController.text,
                  cardType: cardType,
                ),
              );
              context.read<SettingsCubit>().updateSettings(updatedSettings);
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCategoriesDialog(BuildContext context, SettingsModel settings) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Expense Categories'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: settings.expenseTypes.length,
            itemBuilder: (context, index) {
              final category = settings.expenseTypes[index];
              return ListTile(
                title: Text(category),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    context.read<SettingsCubit>().removeExpenseType(category);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _showAddCategoryDialog(context);
            },
            child: const Text('Add Category'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Category Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<SettingsCubit>().addExpenseType(controller.text);
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// Partial Transaction Card Widget
class _PartialTransactionCard extends StatelessWidget {
  final PartialTransaction partial;

  const _PartialTransactionCard({required this.partial});

  @override
  Widget build(BuildContext context) {
    final isCredit = partial.type == TransactionType.credit;
    final color = isCredit ? Colors.green : Colors.red;
    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showEditDialog(context, partial),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(0.12),
                    child: Icon(
                      isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partial.accountName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(partial.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isCredit ? '+' : '-'}₹${partial.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!partial.seen)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'New',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                partial.description,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  partial.smsBody,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _showDeleteConfirmation(context, partial),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _acceptTransaction(context, partial),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, PartialTransaction partial) {
    final accountState = context.read<AccountCubit>().state;
    if (accountState is! AccountLoaded) return;

    final amountController = TextEditingController(text: partial.amount.toString());
    final descriptionController = TextEditingController(text: partial.description);
    final smsBodyController = TextEditingController(text: partial.smsBody);
    final digitsController = TextEditingController(text: partial.matchedDigits);
    TransactionType selectedType = partial.type;
    String? selectedAccount = partial.accountName;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Partial Transaction'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Account'),
                    value: selectedAccount,
                    items: accountState.accounts.map((acc) {
                      return DropdownMenuItem(
                        value: acc.name,
                        child: Text(acc.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedAccount = value;
                        final acc = accountState.accounts
                            .firstWhere((a) => a.name == value);
                        digitsController.text = acc.lastDigits ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TransactionType>(
                    decoration: const InputDecoration(labelText: 'Type'),
                    value: selectedType,
                    items: [
                      DropdownMenuItem(
                        value: TransactionType.credit,
                        child: const Text('Credit'),
                      ),
                      DropdownMenuItem(
                        value: TransactionType.debit,
                        child: const Text('Debit'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: digitsController,
                    decoration: const InputDecoration(labelText: 'Last Digits'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: smsBodyController,
                    decoration: const InputDecoration(labelText: 'SMS Body'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || selectedAccount == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid input'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final updated = partial.copyWith(
                    accountName: selectedAccount,
                    amount: amount,
                    type: selectedType,
                    description: descriptionController.text,
                    smsBody: smsBodyController.text,
                    matchedDigits: digitsController.text,
                  );

                  context.read<PartialTransactionCubit>().updatePartialTransaction(updated);
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Partial transaction updated'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, PartialTransaction partial) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Partial Transaction'),
        content: const Text('Are you sure you want to delete this partial transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<PartialTransactionCubit>().deletePartialTransaction(partial.id);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Partial transaction deleted'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _acceptTransaction(BuildContext context, PartialTransaction partial) {
    final transaction = TransactionModelNew(
      id: '',
      type: partial.type,
      amount: partial.amount,
      description: partial.description,
      category: 'SMS Import',
      account: partial.accountName,
      date: partial.date,
      note: partial.smsBody,
    );
    context.read<TransactionCubit>().addTransaction(transaction);
    context.read<PartialTransactionCubit>().markAsSeen(partial.id);
    context.read<PartialTransactionCubit>().deletePartialTransaction(partial.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transaction saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

// SMS Review Sheet Widget
class _SmsReviewSheet extends StatefulWidget {
  final List<PartialTransaction> partials;
  final Function(PartialTransaction) onAccept;
  final Function(PartialTransaction) onReject;

  const _SmsReviewSheet({
    required this.partials,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_SmsReviewSheet> createState() => _SmsReviewSheetState();
}

class _SmsReviewSheetState extends State<_SmsReviewSheet> {
  late List<PartialTransaction> _pending;

  @override
  void initState() {
    super.initState();
    _pending = List.from(widget.partials);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Test SMS Transaction',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_pending.length}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _pending.isEmpty
                    ? const Center(
                        child: Text('No pending SMS transactions'),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _pending.length,
                        itemBuilder: (context, index) {
                          final p = _pending[index];
                          return _SmsPartialTile(
                            partial: p,
                            onAccept: () {
                              widget.onAccept(p);
                              setState(() {
                                _pending.removeWhere((e) => e.id == p.id);
                              });
                            },
                            onReject: () {
                              widget.onReject(p);
                              setState(() {
                                _pending.removeWhere((e) => e.id == p.id);
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SmsPartialTile extends StatelessWidget {
  final PartialTransaction partial;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _SmsPartialTile({
    required this.partial,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isCredit = partial.type == TransactionType.credit;
    final color = isCredit ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(
                    isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    partial.accountName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${isCredit ? '+' : '-'}₹${partial.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              partial.smsBody,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onReject,
                  child: const Text('Incorrect'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onAccept,
                  child: const Text('Correct'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

