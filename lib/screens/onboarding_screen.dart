import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'login_screen.dart';

/// Three-page onboarding with the fanned, floating card stack.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  int _page = 0;

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  void _next() {
    if (_page >= kOnboarding.length - 1) {
      _toLogin();
    } else {
      setState(() => _page++);
    }
  }

  void _toLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final page = kOnboarding[_page];

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 230,
                  height: 300,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _FloatCard(
                        _float, 0,
                        top: 14, left: 6, width: 150, height: 200,
                        angle: -8 * math.pi / 180, colors: t.ob1,
                      ),
                      _FloatCard(
                        _float, 0.8 / 6,
                        top: 44, right: 2, width: 140, height: 190,
                        angle: 7 * math.pi / 180, colors: t.ob2,
                      ),
                      _FloatCard(
                        _float, 0.4 / 6,
                        top: 74, left: 44, width: 150, height: 200,
                        angle: 0, colors: t.ob3,
                        label: page.tag,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 0, 30, 42),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(kOnboarding.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 7),
                        height: 6,
                        width: active ? 26 : 6,
                        decoration: BoxDecoration(
                          color: active ? t.accent : t.sand,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 22),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(page.title, style: serif(context, 38)),
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 310),
                    child: Text(
                      page.body,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 15.5,
                        height: 1.5,
                        color: t.ink2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _toLogin,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            fontFamily: kSans,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: t.ink3,
                          ),
                        ),
                      ),
                      _NextButton(
                        label: _page >= kOnboarding.length - 1
                            ? 'Get started'
                            : 'Next',
                        onTap: _next,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: t.accent.withOpacity(0.28),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                  fontFamily: kSans,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(width: 9),
            const Icon(Icons.arrow_forward, size: 18),
          ],
        ),
      ),
    );
  }
}

/// One card in the onboarding stack, drifting on the `floaty` keyframes.
class _FloatCard extends StatelessWidget {
  const _FloatCard(
    this.controller,
    this.delayFraction, {
    this.top,
    this.left,
    this.right,
    required this.width,
    required this.height,
    required this.angle,
    required this.colors,
    this.label,
  });

  final AnimationController controller;
  final double delayFraction;
  final double? top;
  final double? left;
  final double? right;
  final double width;
  final double height;
  final double angle;
  final List<Color> colors;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final v = (controller.value + delayFraction) % 1.0;
          // floaty: 0 -> -7px -> 0
          final dy = -7 * math.sin(v * 2 * math.pi);
          return Transform.translate(
            offset: Offset(0, dy),
            child: Transform.rotate(angle: angle, child: child),
          );
        },
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-0.8, -0.9),
              end: const Alignment(0.8, 0.9),
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: t.shadow,
          ),
          padding: const EdgeInsets.all(18),
          alignment: Alignment.bottomLeft,
          child: label == null
              ? null
              : Text(
                  label!.toUpperCase(),
                  style: eyebrow(Colors.white.withOpacity(0.9), size: 11)
                      .copyWith(letterSpacing: 1.5),
                ),
        ),
      ),
    );
  }
}
