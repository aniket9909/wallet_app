import 'package:ewallet/view/home.dart';
import 'package:flutter/material.dart';
import 'package:ewallet/routes/app_routes.dart';
import 'package:ewallet/core/utils/view_imports.dart';
import 'package:ewallet/view/dashboard.dart';
class AppPages {
  static Map<String , WidgetBuilder> pageList ={
    AppRoutes.splashScreen :(context)=>SplashScreen(),
    AppRoutes.dashboard :(context)=>Dashboard(),
    AppRoutes.home :(context)=>Home(),
  };
}