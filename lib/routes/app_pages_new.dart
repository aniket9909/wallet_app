import 'package:flutter/material.dart';
import '../view/splash_screen_new.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/auth/forgot_password_page.dart';
import '../presentation/screens/main_navigation_screen.dart';
import '../presentation/screens/partial_transactions_screen.dart';
import 'app_routes.dart';

class AppPagesNew {
  static Map<String, WidgetBuilder> get routes {
    return {
      AppRoutes.splash: (context) => const SplashScreenNew(),
      AppRoutes.login: (context) => const LoginPage(),
      AppRoutes.register: (context) => const RegisterPage(),
      AppRoutes.forgotPassword: (context) => const ForgotPasswordPage(),
      AppRoutes.home: (context) => const MainNavigationScreen(),
      AppRoutes.partialTransactions: (context) => const PartialTransactionsScreen(),
    };
  }
}

