import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../routes/app_routes.dart';
import '../core/utils/auth_bootstrap.dart';
import '../core/utils/permission_setup_gate.dart';
import '../presentation/theme/brand_colors.dart';

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
    // Run auth bootstrap immediately; only keep a short brand moment in parallel.
    final minBrand = Future<void>.delayed(const Duration(milliseconds: 600));

    final user = FirebaseAuth.instance.currentUser;
    late final bool ok;
    if (user != null) {
      ok = await AuthBootstrap.setup(context);
    } else {
      ok = false;
    }

    await minBrand;
    if (!mounted) return;

    if (user != null) {
      if (ok) {
        await PermissionSetupGate.navigateAfterAuth(context);
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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: BrandColors.washGradient)),
          Positioned(
            top: -70,
            left: -50,
            child: _blob(color: BrandColors.blue.withOpacity(0.10), size: 200)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 0, end: 24, duration: 3000.ms),
          ),
          Positioned(
            bottom: -90,
            right: -60,
            child: _blob(color: BrandColors.green.withOpacity(0.12), size: 240)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 0, end: -22, duration: 3200.ms),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const BrandAppIcon(size: 112)
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .scale(
                          begin: const Offset(0.94, 0.94),
                          end: const Offset(1, 1),
                          duration: 500.ms,
                          curve: Curves.easeOut,
                        ),
                    const SizedBox(height: 28),
                    LayoutBuilder(
                      builder: (context, c) {
                        return Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: BrandColors.blue.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: c.maxWidth * 0.55,
                              decoration: const BoxDecoration(
                                gradient: BrandColors.logoGradient,
                              ),
                            )
                                .animate(onPlay: (controller) => controller.repeat())
                                .moveX(
                                  begin: -c.maxWidth,
                                  end: c.maxWidth,
                                  duration: 1600.ms,
                                ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Opening Arthigo...',
                      style: TextStyle(
                        color: BrandColors.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                    const SizedBox(height: 6),
                    Text(
                      'Loading wallet for Home — heavy sync runs in the background.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: BrandColors.muted,
                        fontSize: 12,
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 180.ms),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: const Text(
              'Secure • Fast • Modern',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BrandColors.muted,
                fontSize: 12,
                letterSpacing: 0.6,
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
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
      ),
    );
  }
}
