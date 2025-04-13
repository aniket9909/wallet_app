import 'package:flutter/material.dart';
import 'package:ewallet/routes/app_routes.dart';
import 'package:ewallet/core/utils/view_imports.dart';
import 'package:ewallet/view/home.dart';
class AppPages {
  static Map<String , WidgetBuilder> pageList ={
    AppRoutes.splashScreen :(context)=>SplashScreen(),
    AppRoutes.home :(context)=>Home(),
  };
}