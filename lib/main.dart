import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_options.dart';
import 'routes/app_routes.dart';
import 'routes/app_pages_new.dart';
import 'presentation/theme/app_theme.dart';

// Data Layer
import 'data/services/firebase_realtime_service.dart';
import 'data/services/sms_listener_service.dart';
import 'data/repositories/wallet_repository.dart';
import 'data/repositories/account_repository.dart';
import 'data/repositories/transaction_repository.dart';
import 'data/repositories/savings_goal_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/debt_repository.dart';
import 'data/repositories/investment_repository.dart';
import 'data/repositories/partial_transaction_repository.dart';

// Logic Layer
import 'logic/cubits/wallet_cubit.dart';
import 'logic/cubits/account_cubit.dart';
import 'logic/cubits/transaction_cubit.dart';
import 'logic/cubits/savings_goal_cubit.dart';
import 'logic/cubits/settings_cubit.dart';
import 'logic/cubits/debt_cubit.dart';
import 'logic/cubits/investment_cubit.dart';
import 'logic/cubits/partial_transaction_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final SmsListenerService _smsListenerService = SmsListenerService();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _requestSmsPermissionsAndStartListener();
  }

  Future<void> _requestSmsPermissionsAndStartListener() async {
    print('========== REQUESTING SMS PERMISSIONS ==========');
    
    if (!Platform.isAndroid) {
      print('Not Android platform, returning...');
      return;
    }
    
    print('Platform is Android, checking SMS permission status...');
    
    // Check and request SMS permissions
    final smsStatus = await Permission.sms.status;
    print('SMS permission status: $smsStatus');
    print('  isGranted: ${smsStatus.isGranted}');
    print('  isDenied: ${smsStatus.isDenied}');
    print('  isPermanentlyDenied: ${smsStatus.isPermanentlyDenied}');
    
    if (smsStatus.isGranted) {
      // Permissions already granted, start listening
      print('Permissions already granted, starting SMS listener...');
      _startSmsListener();
    } else if (smsStatus.isDenied) {
      // Request permissions
      print('Permission denied, requesting SMS permission...');
      final result = await Permission.sms.request();
      print('Permission request result: $result');
      print('  isGranted: ${result.isGranted}');
      
      if (result.isGranted) {
        print('Permission granted! Starting SMS listener...');
        _startSmsListener();
      } else {
        print('ERROR: SMS permission denied. Cannot listen to SMS messages.');
        // Optionally show a message to the user
        _showPermissionDeniedMessage();
      }
    } else if (smsStatus.isPermanentlyDenied) {
      // Permission permanently denied, show dialog to open settings
      print('ERROR: SMS permission permanently denied.');
      _showPermissionPermanentlyDeniedDialog();
    }
    
    print('================================================');
  }

  void _startSmsListener() {
    print('========== STARTING SMS LISTENER ==========');
    print('SmsListenerService instance: available');
    
    _smsListenerService.startListening((body, address, date) {
      // Show popup when SMS is received
      print('========== SMS CALLBACK TRIGGERED ==========');
      print('SMS received in main.dart callback:');
      print('  Body: $body');
      print('  Address: $address');
      print('  Date: $date');
      print('Showing SMS popup...');
      _showSmsPopup(body, address, date);
      print('===========================================');
    });
    
    print('SMS listener started successfully');
    print('==================================');
  }

  void _showPermissionDeniedMessage() {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMS permission is required to receive SMS notifications'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    });
  }

  void _showPermissionPermanentlyDeniedDialog() {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('SMS Permission Required'),
          content: const Text(
            'SMS permission is required to receive SMS notifications. '
            'Please enable it in app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    });
  }

  void _showSmsPopup(String body, String address, DateTime date) {
    print('========== SHOWING SMS POPUP ==========');
    print('Body: $body');
    print('Address: $address');
    print('Date: $date');
    
    // Use navigatorKey to show dialog from anywhere
    final context = navigatorKey.currentContext;
    if (context == null) {
      print('ERROR: navigatorKey.currentContext is null! Cannot show popup.');
      return;
    }
    
    print('Context is available, showing dialog...');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.sms, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('New SMS Received'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (address.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'From: $address',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Time: ${_formatDateTime(date)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Message:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    body,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                print('SMS popup closed by user');
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
    
    print('Dialog shown successfully');
    print('==================================');
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _smsListenerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FirebaseRealtimeService>(
          create: (context) => FirebaseRealtimeService(),
        ),
        RepositoryProvider<WalletRepository>(
          create: (context) => WalletRepository(
            context.read<FirebaseRealtimeService>(),
          ),
        ),
        RepositoryProvider<AccountRepository>(
          create: (context) => AccountRepository(
            context.read<FirebaseRealtimeService>(),
          ),
        ),
        RepositoryProvider<TransactionRepository>(
          create: (context) => TransactionRepository(
            context.read<FirebaseRealtimeService>(),
          ),
        ),
        RepositoryProvider<SavingsGoalRepository>(
          create: (context) => SavingsGoalRepository(
            context.read<FirebaseRealtimeService>(),
          ),
        ),
        RepositoryProvider<SettingsRepository>(
          create: (context) => SettingsRepository(
            context.read<FirebaseRealtimeService>(),
          ),
        ),
        RepositoryProvider<DebtRepository>(
          create: (context) => DebtRepository(
            context.read<FirebaseRealtimeService>(),
          ),
        ),
        RepositoryProvider<InvestmentRepository>(
          create: (context) => InvestmentRepository(
            context.read<FirebaseRealtimeService>(),
          ),
        ),
        RepositoryProvider<PartialTransactionRepository>(
          create: (context) => PartialTransactionRepository(
            context.read<FirebaseRealtimeService>(),
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<WalletCubit>(
            create: (context) => WalletCubit(
              context.read<WalletRepository>(),
            )..loadWallet(),
          ),
          BlocProvider<AccountCubit>(
            create: (context) => AccountCubit(
              context.read<AccountRepository>(),
            )..loadAccounts(),
          ),
          BlocProvider<TransactionCubit>(
            create: (context) => TransactionCubit(
              context.read<TransactionRepository>(),
            )..loadTransactions(),
          ),
          BlocProvider<SavingsGoalCubit>(
            create: (context) => SavingsGoalCubit(
              context.read<SavingsGoalRepository>(),
            )..loadGoals(),
          ),
          BlocProvider<SettingsCubit>(
            create: (context) => SettingsCubit(
              context.read<SettingsRepository>(),
            )..loadSettings(),
          ),
          BlocProvider<DebtCubit>(
            create: (context) => DebtCubit(
              context.read<DebtRepository>(),
            )..loadDebts(),
          ),
          BlocProvider<InvestmentCubit>(
            create: (context) => InvestmentCubit(
              context.read<InvestmentRepository>(),
            )..loadInvestments(),
          ),
          BlocProvider<PartialTransactionCubit>(
            create: (context) => PartialTransactionCubit(
              context.read<PartialTransactionRepository>(),
            )..loadPartialTransactions(),
          ),
        ],
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) {
            final isDarkMode = state is SettingsLoaded ? state.settings.darkMode : false;

            return MaterialApp(
              navigatorKey: navigatorKey,
              debugShowCheckedModeBanner: false,
              title: 'E-Wallet & Expense Manager',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
              initialRoute: AppRoutes.splash,
              routes: AppPagesNew.routes,
            );
          },
        ),
      ),
    );
  }
}

