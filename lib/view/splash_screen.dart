import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ewallet/viewmodels/splash_screen_view_model.dart';
import 'package:ewallet/presentation/theme/brand_colors.dart';

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => SplashViewModel(context),
      child: Consumer<SplashViewModel>(
        builder: (context, viewModel, child) {
          return Container(
            color: Colors.white,
            child: const Center(
              child: BrandLogo(width: 280),
            ),
          );
        },
      ),
    );
  }
}
