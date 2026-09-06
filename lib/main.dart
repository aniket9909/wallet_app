import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'firebase_options.dart';
import 'routes/app_routes.dart';
import 'routes/app_pages_new.dart';
import 'presentation/theme/app_theme.dart';
import 'core/database/local_app_database.dart';
import 'data/services/offline_sync_service.dart';
import 'data/services/overlay_cache_service.dart';

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
import 'data/repositories/money_plan_repository.dart';

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
import 'logic/cubits/money_plan_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is required for auth before first route; open SQLite after first frame.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());

  // Warm local DB without blocking the first paint / splash.
  // ignore: unawaited_futures
  LocalAppDatabase.instance.database;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  late final SmsCoordinatorService _smsCoordinator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _smsCoordinator = SmsCoordinatorService(navigatorKey: navigatorKey);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _smsCoordinator.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    // Debounced background work — do not block resume / Home.
    Future<void>.delayed(const Duration(seconds: 1), () {
      try {
        OfflineSyncService.instance.flush(ctx.read<FirebaseRealtimeService>());
        OverlayCacheService.syncFromLocalDatabase(force: false);
      } catch (_) {}
    });
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
        RepositoryProvider<MoneyPlanRepository>(
          create: (context) => MoneyPlanRepository(
            context.read<FirebaseRealtimeService>(),
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
            ),
          ),
          BlocProvider<AccountCubit>(
            create: (context) => AccountCubit(
              context.read<AccountRepository>(),
            ),
          ),
          BlocProvider<TransactionCubit>(
            create: (context) => TransactionCubit(
              context.read<TransactionRepository>(),
            ),
          ),
          BlocProvider<SavingsGoalCubit>(
            create: (context) => SavingsGoalCubit(
              context.read<SavingsGoalRepository>(),
            ),
          ),
          BlocProvider<SettingsCubit>(
            create: (context) => SettingsCubit(
              context.read<SettingsRepository>(),
            ),
          ),
          BlocProvider<DebtCubit>(
            create: (context) => DebtCubit(
              context.read<DebtRepository>(),
            ),
          ),
          BlocProvider<InvestmentCubit>(
            create: (context) => InvestmentCubit(
              context.read<InvestmentRepository>(),
            ),
          ),
          BlocProvider<PartialTransactionCubit>(
            create: (context) => PartialTransactionCubit(
              context.read<PartialTransactionRepository>(),
            ),
          ),
          BlocProvider<SmsCubit>(
            create: (context) => SmsCubit(
              context.read<SmsRepository>(),
            ),
          ),
          BlocProvider<MoneyPlanCubit>(
            create: (context) => MoneyPlanCubit(
              context.read<MoneyPlanRepository>(),
            ),
          ),
        ],
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) {
            final isDarkMode = state is SettingsLoaded ? state.settings.darkMode : false;

            return MaterialApp(
              navigatorKey: navigatorKey,
              debugShowCheckedModeBanner: false,
              title: 'Arthigo Smart Money Tracker',
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

