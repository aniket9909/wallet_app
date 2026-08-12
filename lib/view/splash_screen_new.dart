import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../routes/app_routes.dart';
import '../core/utils/auth_bootstrap.dart';

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
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final ok = await AuthBootstrap.setup(context);
      if (!mounted) return;
      if (ok) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load your wallet. Please sign in again.'),
            backgroundColor: Colors.red,
          ),
        );
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
      }
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
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
          ),
          Positioned(
            top: -60,
            left: -40,
            child: _blob(color: Colors.white.withOpacity(0.10), size: 180)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 0, end: 30, duration: 3000.ms),
          ),
          Positioned(
            bottom: -80,
            right: -50,
            child: _blob(color: Colors.white.withOpacity(0.08), size: 220)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 0, end: -25, duration: 3200.ms),
          ),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.82,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.35),
                              Colors.white.withOpacity(0.20),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/logo/logo.jpeg',
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                          .animate(onPlay: (controller) => controller.repeat())
                          .shimmer(duration: 2000.ms, color: Colors.white.withOpacity(0.25))
                          .scale(duration: 1800.ms, begin: const Offset(1, 1), end: const Offset(1.06, 1.06))
                          .then()
                          .scale(duration: 1800.ms, begin: const Offset(1.06, 1.06), end: const Offset(1, 1)),
                      const SizedBox(height: 20),
                      Text(
                        'Arthigo',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ).animate().fadeIn(duration: 600.ms),
                      const SizedBox(height: 6),
                      Text(
                        'Smart Wallet App',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.1,
                        ),
                      ).animate().fadeIn(duration: 600.ms, delay: 150.ms),
                      const SizedBox(height: 22),
                      LayoutBuilder(
                        builder: (context, c) {
                          return Container(
                            height: 8,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: c.maxWidth * 0.75,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.9),
                                      Colors.white.withOpacity(0.6),
                                    ],
                                  ),
                                ),
                              )
                                  .animate(onPlay: (controller) => controller.repeat())
                                  .moveX(begin: -c.maxWidth, end: c.maxWidth, duration: 1600.ms),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Preparing your wallet...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Secure • Fast • Modern',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob({required Color color, required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
    );
  }
}
