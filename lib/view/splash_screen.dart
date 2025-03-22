import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:wallet_app/viewmodels/splash_screen_view_model.dart';

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => SplashViewModel(context),
      child: Consumer<SplashViewModel>(
        builder: (context, viewModel, child) {
          return Center(
            child: FlutterLogo(
              size: 250,
            ),
          );
        },
      ),
    );
  }
}
