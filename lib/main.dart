import 'package:flutter/material.dart';
import 'package:wallet_app/core/widgets/themes_data.dart';
import 'package:wallet_app/routes/app_pages.dart';
import 'package:wallet_app/routes/app_routes.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wallet App',
      theme: lightTheme,
      initialRoute: AppRoutes.splashScreen,
      routes: AppPages.pageList,
    );
  }
}
