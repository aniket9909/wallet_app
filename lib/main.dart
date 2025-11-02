import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'firebase_options.dart';
import 'routes/app_routes.dart';
import 'routes/app_pages_new.dart';
import 'presentation/theme/app_theme.dart';

// Data Layer
import 'data/services/firebase_realtime_service.dart';
import 'data/repositories/wallet_repository.dart';
import 'data/repositories/account_repository.dart';
import 'data/repositories/transaction_repository.dart';
import 'data/repositories/savings_goal_repository.dart';
import 'data/repositories/settings_repository.dart';

// Logic Layer
import 'logic/cubits/wallet_cubit.dart';
import 'logic/cubits/account_cubit.dart';
import 'logic/cubits/transaction_cubit.dart';
import 'logic/cubits/savings_goal_cubit.dart';
import 'logic/cubits/settings_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        ],
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) {
            final isDarkMode = state is SettingsLoaded ? state.settings.darkMode : false;

            return MaterialApp(
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

