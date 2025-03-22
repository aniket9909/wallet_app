import 'package:flutter/material.dart';
import 'dart:async';

class SplashViewModel extends ChangeNotifier {
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  SplashViewModel(BuildContext context) {
    _startSplashTimer(context);
  }

  void _startSplashTimer(BuildContext context) {
    Timer(Duration(seconds: 3), () {
      _isLoading = false;
      notifyListeners();
      Navigator.pushReplacementNamed(context, "/home");
    });
  }
}
