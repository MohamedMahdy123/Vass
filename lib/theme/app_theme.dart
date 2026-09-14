import 'package:flutter/material.dart';

import 'tokens.dart';

/// Font families are loaded by the Google Fonts <link> in web/index.html, the
/// same way the design doc loads them.
const kSans = 'Geist';
const kSerif = 'Instrument Serif';

ThemeData buildVessTheme(VessTokens t, Brightness brightness) {
  final base = ThemeData(brightness: brightness, useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: t.bg,
    canvasColor: t.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: t.accent,
      brightness: brightness,
    ).copyWith(
      primary: t.accent,
      surface: t.card,
      background: t.bg,
    ),
    extensions: [t],
    textTheme: base.textTheme.apply(
      fontFamily: kSans,
      bodyColor: t.ink,
      displayColor: t.ink,
    ),
    splashFactory: InkRipple.splashFactory,
  );
}

/// Display type — Instrument Serif, used for every large heading.
TextStyle serif(BuildContext context, double size, {Color? color}) {
  return TextStyle(
    fontFamily: kSerif,
    fontSize: size,
    height: 1.04,
    color: color ?? Theme.of(context).extension<VessTokens>()!.ink,
  );
}

/// The uppercase micro-label used for tags and eyebrows.
TextStyle eyebrow(Color color, {double size = 12}) {
  return TextStyle(
    fontFamily: kSans,
    fontSize: size,
    letterSpacing: size * 0.18,
    fontWeight: FontWeight.w600,
    color: color,
  );
}
