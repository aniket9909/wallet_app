import 'package:flutter/material.dart';
import 'package:wallet_app/routes/app_routes.dart';
import 'package:wallet_app/core/utils/view_imports.dart';
import 'package:wallet_app/view/home.dart';
class AppPages {
  static Map<String , WidgetBuilder> pageList ={
    AppRoutes.splashScreen :(context)=>SplashScreen(),
    AppRoutes.home :(context)=>Home(),
  };
}