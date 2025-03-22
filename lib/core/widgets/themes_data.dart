import 'package:flutter/material.dart';
import 'package:wallet_app/core/utils/custome_colors.dart';

// Define Light Theme
final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: Color(0xff243972),
  scaffoldBackgroundColor: Colors.white,
  textTheme: TextTheme(
    bodyLarge: TextStyle(color: Colors.black),
    bodyMedium: TextStyle(color: Colors.black87),
  ),
  
  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xff243972),
    titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
    ),
  ),
  extensions: [
    CustomColors(
      textColor: Colors.white,
      buttonColor: Color(0xff243972),
      cardColor: Colors.white,
      greenColor: Color(0xff41BE06),
      redColor: Color(0xffEB1F39),
        titleColor: Color(0xff1B2736),
      subtitleColor: Color(0xff6C757D),
      secondaryColor: Color(0xffA9A9A9),

    )
  ],
  colorScheme: ColorScheme.light(
    primary: Color(0xff243972),
  ),
);

// Define Dark Theme
final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: Colors.deepPurple,
  scaffoldBackgroundColor: Colors.black,
  textTheme: TextTheme(
    bodyLarge: TextStyle(color: Colors.white),
    bodyMedium: TextStyle(color: Colors.white70),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.deepPurple,
    titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
    ),
  ),
);
