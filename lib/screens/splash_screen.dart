import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'onboarding_screen.dart';

/// Splash — the logo with two expanding rings behind it.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rings = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _rings.dispose();
    super.dispose();
  }

  void _begin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;

    return Scaffold(
      backgroundColor: t.bg,
      body: GestureDetector(
        onTap: _begin,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Two rings, offset by half the cycle.
                      _Ring(_rings, 0),
                      _Ring(_rings, 0.5),
                      Container(
                        width: 98,
                        height: 98,
                        decoration: BoxDecoration(
                          color: t.accent,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: t.accent.withOpacity(0.4),
                              blurRadius: 54,
                              offset: const Offset(0, 24),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Transform.translate(
                          offset: const Offset(0, -4),
                          child: const Text(
                            'V',
                            style: TextStyle(
                              fontFamily: kSerif,
                              fontSize: 54,
                              height: 1,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 38),
                Text('Vess', style: serif(context, 42)),
                const SizedBox(height: 10),
                Text('Dress with intention',
                    style: eyebrow(t.ink2, size: 12.5).copyWith(
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.w400,
                    )),
              ],
            ),
            Positioned(
              bottom: 60,
              child: TextButton(
                onPressed: _begin,
                child: Text(
                  'TAP TO BEGIN',
                  style: eyebrow(t.ink3).copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring(this.controller, this.offset);

  final AnimationController controller;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // Matches the CSS `ring` keyframes: scale .82 -> 1.35, opacity .5 -> 0.
        final v = (controller.value + offset) % 1.0;
        return Opacity(
          opacity: 0.5 * (1 - v),
          child: Transform.scale(
            scale: 0.82 + (1.35 - 0.82) * v,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: t.accent),
              ),
            ),
          ),
        );
      },
    );
  }
}
