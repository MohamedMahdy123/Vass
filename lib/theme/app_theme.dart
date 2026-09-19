import 'package:flutter/material.dart';

import 'tokens.dart';

/// Font families are loaded by the Google Fonts <link> in web/index.html, the
/// same way the design doc loads them.
const kSans = 'Geist';
const kSerif = 'Instrument Serif';

/// Sans type scale (Geist). One ramp so screens stop inventing per-widget
/// half-point sizes. Serif headings keep using [serif]; eyebrows use [eyebrow].
class VessType {
  const VessType._();

  /// Chat text, inputs, primary body.
  static const body = 14.5;

  /// Secondary body, subtitles, list-tile text.
  static const bodySm = 13.5;

  /// Chip labels, small buttons, meta.
  static const label = 12.5;

  /// Captions and tiny meta.
  static const caption = 11.5;
}

/// Corner-radius scale. One set of values instead of a new radius per widget.
class VessRadius {
  const VessRadius._();

  /// Chips, small controls, the back button.
  static const sm = 14.0;

  /// Inputs, in-flow CTAs, the send button.
  static const md = 16.0;

  /// Raised cards and bottom sheets.
  static const lg = 22.0;

  /// Fully-rounded pills / accent buttons.
  static const pill = 999.0;
}

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
