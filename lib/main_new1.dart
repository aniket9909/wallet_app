import 'package:ewallet/firebase_options.dart';
import 'package:ewallet/viewmodels/all_wallet_view_model.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/widgets/themes_data.dart';
import '../routes/app_pages.dart';
import '../routes/app_routes.dart';
import 'viewmodels/home_view_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DashboardViewModel('123')),
        ChangeNotifierProvider(create: (_) => AllWalletViewModel()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Arthigo Smart Money Tracker',
        theme: lightTheme,
        initialRoute: AppRoutes.splashScreen,
        routes: AppPages.pageList,
      ),
    );
  }
}
