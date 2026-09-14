import 'package:flutter/material.dart';

/// Design tokens ported verbatim from the Vess design doc (`Vess.dc.html`, the
/// `T` object). Names match the CSS custom properties so the two stay
/// comparable — do not rename without updating the design doc.
class VessTokens extends ThemeExtension<VessTokens> {
  const VessTokens({
    required this.bg,
    required this.bg2,
    required this.card,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.accent,
    required this.accentSoft,
    required this.accentInk,
    required this.sand,
    required this.sand2,
    required this.tab,
    required this.overlay,
    required this.shadow,
    required this.ob1,
    required this.ob2,
    required this.ob3,
  });

  final Color bg;
  final Color bg2;
  final Color card;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color line;
  final Color accent;
  final Color accentSoft;
  final Color accentInk;
  final Color sand;
  final Color sand2;
  final Color tab;
  final Color overlay;

  /// Ambient card shadow (`--shadow`).
  final List<BoxShadow> shadow;

  /// Onboarding card gradients (`--ob1a/--ob1b` etc), as [start, end] pairs.
  final List<Color> ob1;
  final List<Color> ob2;
  final List<Color> ob3;

  static const light = VessTokens(
    bg: Color(0xFFEFEBE4),
    bg2: Color(0xFFF7F3EC),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF1A1917),
    ink2: Color(0xFF726C62),
    ink3: Color(0xFFA49E93),
    line: Color(0xFFE7E1D8),
    accent: Color(0xFF0F7A57),
    accentSoft: Color(0xFFE4EFE9),
    accentInk: Color(0xFF0B5C42),
    sand: Color(0xFFE7DFD2),
    sand2: Color(0xFFF3EEE5),
    tab: Color(0xD1F7F3EC),
    overlay: Color(0x6B1A1917),
    shadow: [
      BoxShadow(
        color: Color(0x12282218),
        blurRadius: 34,
        offset: Offset(0, 12),
      ),
    ],
    ob1: [Color(0xFFC9BCA8), Color(0xFFA99B86)],
    ob2: [Color(0xFF2D2A26), Color(0xFF4A453E)],
    ob3: [Color(0xFF0F7A57), Color(0xFF0B5C42)],
  );

  static const dark = VessTokens(
    bg: Color(0xFF100F0E),
    bg2: Color(0xFF171614),
    card: Color(0xFF1B1A17),
    ink: Color(0xFFF1EEE7),
    ink2: Color(0xFF9E988C),
    ink3: Color(0xFF68635A),
    line: Color(0xFF2A2823),
    accent: Color(0xFF3EC08D),
    accentSoft: Color(0xFF16271F),
    accentInk: Color(0xFF8FE0C1),
    sand: Color(0xFF252219),
    sand2: Color(0xFF1E1C18),
    tab: Color(0xBD171614),
    overlay: Color(0x94000000),
    shadow: [
      BoxShadow(
        color: Color(0x8C000000),
        blurRadius: 46,
        offset: Offset(0, 16),
      ),
    ],
    ob1: [Color(0xFF7C7160), Color(0xFF5A5145)],
    ob2: [Color(0xFF000000), Color(0xFF2A2620)],
    ob3: [Color(0xFF0F7A57), Color(0xFF083E2D)],
  );

  /// The 152° gradient the design uses in place of clothing photography.
  static LinearGradient itemGradient(Color a, Color b) {
    // CSS `152deg` measures clockwise from "to top"; Flutter measures from the
    // centre outward, so this is the equivalent begin/end pair.
    return LinearGradient(
      begin: const Alignment(-0.72, -0.94),
      end: const Alignment(0.72, 0.94),
      colors: [a, b],
    );
  }

  @override
  VessTokens copyWith() => this;

  @override
  VessTokens lerp(ThemeExtension<VessTokens>? other, double t) {
    // Themes swap wholesale rather than interpolating.
    return t < 0.5 ? this : (other as VessTokens? ?? this);
  }
}

extension VessTokensX on BuildContext {
  VessTokens get vess => Theme.of(this).extension<VessTokens>()!;
}
