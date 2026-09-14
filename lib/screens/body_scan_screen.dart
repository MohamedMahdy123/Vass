import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'login_screen.dart';
import 'shell.dart';

/// Fake 10-second body scan: a sweeping line, a grid overlay and a progress bar.
class BodyScanScreen extends StatefulWidget {
  const BodyScanScreen({super.key});

  @override
  State<BodyScanScreen> createState() => _BodyScanScreenState();
}

class _BodyScanScreenState extends State<BodyScanScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  Timer? _timer;
  int _progress = 0;
  bool _scanning = false;

  @override
  void dispose() {
    _timer?.cancel();
    _sweep.dispose();
    super.dispose();
  }

  String get _label {
    if (_progress >= 100) return 'Scan complete — fit calibrated';
    if (_scanning) return 'Scanning… $_progress%';
    return 'Ready when you are';
  }

  String get _button {
    if (_progress >= 100) return 'Enter your wardrobe';
    if (_scanning) return 'Scanning…';
    return 'Start scan';
  }

  void _action() {
    if (_progress >= 100) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const Shell()),
        (_) => false,
      );
      return;
    }
    if (_scanning) return;

    setState(() => _scanning = true);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() => _progress += 2);
      if (_progress >= 100) {
        _progress = 100;
        _scanning = false;
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    final showOverlay = _scanning || _progress >= 100;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 30, 30, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const VessBackButton(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: t.accentSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('STEP 1 OF 1',
                        style: eyebrow(t.accent, size: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('AI body scan', style: serif(context, 36)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  'A 10-second scan so every outfit is proportioned to you. '
                  'Fully private, processed on device.',
                  style: TextStyle(
                      fontFamily: kSans, fontSize: 15, height: 1.45, color: t.ink2),
                ),
              ),
              Expanded(
                child: Center(
                  child: Container(
                    width: 180,
                    height: 330,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: t.sand2,
                      border: Border.all(color: t.line),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(118, 270),
                          painter: _FigurePainter(t.ink3),
                        ),
                        // Grid overlay, fades in while scanning.
                        AnimatedOpacity(
                          opacity: showOverlay ? 0.5 : 0,
                          duration: const Duration(milliseconds: 400),
                          child: CustomPaint(
                            size: const Size(180, 330),
                            painter: _GridPainter(t.accent),
                          ),
                        ),
                        // Sweeping scan line.
                        if (_scanning)
                          AnimatedBuilder(
                            animation: _sweep,
                            builder: (context, _) {
                              final dy = 38 * math.sin(_sweep.value * 2 * math.pi);
                              return Transform.translate(
                                offset: Offset(0, dy),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 12),
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: t.accent,
                                    boxShadow: [
                                      BoxShadow(
                                          color: t.accent,
                                          blurRadius: 16,
                                          spreadRadius: 2),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Text(
                  _label,
                  style: TextStyle(
                    fontFamily: 'Geist Mono',
                    fontSize: 15,
                    letterSpacing: 0.6,
                    color: t.ink2,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: _progress / 100,
                  minHeight: 6,
                  backgroundColor: t.sand,
                  valueColor: AlwaysStoppedAnimation(t.accent),
                ),
              ),
              const SizedBox(height: 22),
              VessPrimaryButton(label: _button, onTap: _action),
            ],
          ),
        ),
      ),
    );
  }
}

/// The wireframe human figure from the design's inline SVG.
class _FigurePainter extends CustomPainter {
  _FigurePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawCircle(const Offset(59, 34), 24, p);
    final path = Path()
      ..moveTo(59, 58)
      ..lineTo(59, 154)
      ..moveTo(59, 76)
      ..lineTo(21, 102)
      ..moveTo(59, 76)
      ..lineTo(97, 102)
      ..moveTo(59, 154)
      ..lineTo(35, 246)
      ..moveTo(59, 154)
      ..lineTo(83, 246);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_FigurePainter old) => old.color != color;
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    for (double x = 0; x < size.width; x += 22) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}
