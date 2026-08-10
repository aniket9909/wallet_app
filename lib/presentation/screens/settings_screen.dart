import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../logic/cubits/settings_cubit.dart';
import '../../data/models/settings_model.dart';
import '../widgets/settings_section.dart';
import '../widgets/sms_setup_section.dart';
import '../../routes/app_routes.dart';
import '../../core/utils/auth_bootstrap.dart';
import 'account_last_digits_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
              // Header
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
              Expanded(child: _buildSettingsTab(context)),
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

                      // SMS Setup
                      SettingsSection(
                        title: 'SMS Bank Alerts',
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: SmsSetupSection(),
                        ),
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
              AuthBootstrap.reset(context);
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
