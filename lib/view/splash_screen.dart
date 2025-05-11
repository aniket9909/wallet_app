import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:ewallet/viewmodels/splash_screen_view_model.dart';

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => SplashViewModel(context),
      child: Consumer<SplashViewModel>(
        builder: (context, viewModel, child) {
          return Container(
            color: Colors.white,
            child: Center(
              child: Image.asset(
                'assets/logo/money_mate_logo.png',
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }
}
