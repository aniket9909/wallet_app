import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../routes/app_routes.dart';
import '../data/services/firebase_realtime_service.dart';

class SplashScreenNew extends StatefulWidget {
  const SplashScreenNew({super.key});

  @override
  State<SplashScreenNew> createState() => _SplashScreenNewState();
}

class _SplashScreenNewState extends State<SplashScreenNew> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    // Wait for 3 seconds
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Check if user is logged in
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Initialize user data in Realtime Database
      await FirebaseRealtimeService().initializeUserData();
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } else {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                size: 80,
                color: Colors.white,
              ),
            )
                .animate(onPlay: (controller) => controller.repeat())
                .shimmer(duration: 2000.ms, color: Colors.white.withOpacity(0.3))
                .scale(duration: 2000.ms, begin: const Offset(1, 1), end: const Offset(1.1, 1.1))
                .then()
                .scale(duration: 2000.ms, begin: const Offset(1.1, 1.1), end: const Offset(1, 1)),
            
            const SizedBox(height: 32),

            // App Name
            const Text(
              'E-Wallet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ).animate().fadeIn(duration: 800.ms, delay: 400.ms),

            const SizedBox(height: 8),

            const Text(
              'Expense Manager',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.2,
              ),
            ).animate().fadeIn(duration: 800.ms, delay: 600.ms),

            const SizedBox(height: 48),

            // Loading Indicator
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ).animate().fadeIn(duration: 800.ms, delay: 800.ms),

            const SizedBox(height: 16),

            Text(
              'Loading your wallet...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ).animate().fadeIn(duration: 800.ms, delay: 1000.ms),
          ],
        ),
      ),              
    );
  }
}

