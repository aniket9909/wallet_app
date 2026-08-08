import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'firebase_options.dart';
import 'routes/app_routes.dart';
import 'routes/app_pages_new.dart';
import 'presentation/theme/app_theme.dart';

// Data Layer
import 'data/services/firebase_realtime_service.dart';
import 'data/services/sms_coordinator_service.dart';
import 'data/repositories/wallet_repository.dart';
import 'data/repositories/account_repository.dart';
import 'data/repositories/transaction_repository.dart';
import 'data/repositories/savings_goal_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/debt_repository.dart';
import 'data/repositories/investment_repository.dart';
import 'data/repositories/partial_transaction_repository.dart';
import 'data/repositories/sms_repository.dart';

// Logic Layer
import 'logic/cubits/wallet_cubit.dart';
import 'logic/cubits/account_cubit.dart';
import 'logic/cubits/transaction_cubit.dart';
import 'logic/cubits/savings_goal_cubit.dart';
import 'logic/cubits/settings_cubit.dart';
import 'logic/cubits/debt_cubit.dart';
import 'logic/cubits/investment_cubit.dart';
import 'logic/cubits/partial_transaction_cubit.dart';
import 'logic/cubits/sms_cubit.dart';

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
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  late final SmsCoordinatorService _smsCoordinator;

  @override
  void initState() {
    super.initState();
    _smsCoordinator = SmsCoordinatorService(navigatorKey: navigatorKey);
    _smsCoordinator.startListenerIfPermitted();
    _syncLocalSmsToFirebase();
  }

  Future<void> _syncLocalSmsToFirebase() async {
    print('========== SYNCING LOCAL SMS TO FIREBASE ==========');
    // Wait for widget tree to be ready
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final context = navigatorKey.currentContext;
        if (context != null) {
          final smsRepo = context.read<SmsRepository>();
          final allSms = await smsRepo.getAllSms();
          print('Found ${allSms.length} local SMS messages to sync');
          
          if (allSms.isNotEmpty) {
            await smsRepo.syncAllToFirebase(allSms);
            print('All SMS messages synced to Firebase');
          }
        }
      } catch (e) {
        print('Error syncing local SMS to Firebase: $e');
      }
      print('==================================================');
    });
  }

  @override
  void dispose() {
    _smsCoordinator.dispose();
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
        RepositoryProvider<SmsRepository>(
          create: (context) => SmsRepository(
            firebaseService: context.read<FirebaseRealtimeService>(),
          ),
        ),
        RepositoryProvider<SmsCoordinatorService>(
          create: (context) => _smsCoordinator,
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
          BlocProvider<SmsCubit>(
            create: (context) => SmsCubit(
              context.read<SmsRepository>(),
            )..loadAllSms(),
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

