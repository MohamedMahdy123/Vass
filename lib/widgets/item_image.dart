import 'package:flutter/material.dart';

import '../core/supabase_service.dart';
import '../data/models/item.dart';
import '../data/wardrobe_repository.dart';

/// Renders a garment. When the item has a photo we show it; until then (manual
/// adds, pre-M2) we show a color swatch derived from the item's real `color`
/// attribute — a truthful representation, not a fake photo.
class ItemImage extends StatelessWidget {
  const ItemImage({super.key, required this.item, this.radius = 18, this.child});

  final Item item;
  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final base = swatchColor(item.color);
    final r = BorderRadius.circular(radius);

    final swatch = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.72, -0.94),
          end: const Alignment(0.72, 0.94),
          colors: [base, _darken(base, 0.72)],
        ),
        borderRadius: r,
      ),
      child: child,
    );

    // Just-captured bytes render instantly, no network round-trip.
    if (item.localBytes != null) {
      return ClipRRect(
        borderRadius: r,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(item.localBytes!, fit: BoxFit.cover),
            if (child != null) child!,
          ],
        ),
      );
    }

    final path = item.imagePath;

    // A full URL (e.g. the demo wardrobe / catalog) renders directly.
    if (path != null && (path.startsWith('http://') || path.startsWith('https://'))) {
      return ClipRRect(
        borderRadius: r,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(path, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => swatch),
            if (child != null) child!,
          ],
        ),
      );
    }

    // A storage path is only meaningful against a live backend.
    if (path == null || !SupabaseService.isReady) return swatch;

    return FutureBuilder<String>(
      future: WardrobeRepository().signedUrl(path),
      builder: (context, snap) {
        if (!snap.hasData) return swatch;
        return ClipRRect(
          borderRadius: r,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(snap.data!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => swatch),
              if (child != null) child!,
            ],
          ),
        );
      },
    );
  }
}

Color _darken(Color c, double factor) => Color.fromARGB(
      c.alpha,
      (c.red * factor).round(),
      (c.green * factor).round(),
      (c.blue * factor).round(),
    );

/// Maps a color name to a swatch base. Covers the design's own palette plus
/// common wardrobe colors; unknown names hash to a deterministic muted tone so
/// every item still reads as a distinct, calm block.
Color swatchColor(String? name) {
  if (name == null || name.trim().isEmpty) return const Color(0xFFB8B0A2);
  final key = name.trim().toLowerCase();
  final hit = _named[key];
  if (hit != null) return hit;
  // Deterministic muted fallback from the string.
  var h = 0;
  for (final code in key.codeUnits) {
    h = (h * 31 + code) & 0x7fffffff;
  }
  final hue = (h % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.18, 0.52).toColor();
}

const _named = <String, Color>{
  // design palette
  'ash': Color(0xFF8A857B),
  'ivory': Color(0xFFF2EDE3),
  'sand': Color(0xFFD3C3AE),
  'charcoal': Color(0xFF33343A),
  'indigo': Color(0xFF41506B),
  'espresso': Color(0xFF3A342E),
  'taupe': Color(0xFF57524A),
  'camel': Color(0xFFCDB999),
  'onyx': Color(0xFF2A2724),
  'chalk': Color(0xFFF0EDE6),
  'cognac': Color(0xFF5A4636),
  'emerald': Color(0xFF178C64),
  'mocha': Color(0xFF7A6A58),
  'sage': Color(0xFFBCC6BA),
  'bone': Color(0xFFEAE2D3),
  // common colors
  'black': Color(0xFF2A2724),
  'white': Color(0xFFF2EDE3),
  'grey': Color(0xFF8A857B),
  'gray': Color(0xFF8A857B),
  'navy': Color(0xFF2C384F),
  'blue': Color(0xFF41506B),
  'green': Color(0xFF3E6B54),
  'red': Color(0xFF8C4A44),
  'pink': Color(0xFFD6A9A9),
  'brown': Color(0xFF5A4636),
  'beige': Color(0xFFD3C3AE),
  'cream': Color(0xFFEAE2D3),
  'tan': Color(0xFFCDB999),
  'olive': Color(0xFF6B6A4E),
  'burgundy': Color(0xFF5A2A32),
  'khaki': Color(0xFFB7A88A),
  'denim': Color(0xFF41506B),
  'yellow': Color(0xFFC9B36A),
  'orange': Color(0xFFC08A4E),
  'purple': Color(0xFF6B5A78),
  'silver': Color(0xFFB8B4AC),
};

/// True when the swatch is pale enough to need dark text on top.
bool swatchIsLight(String? name) => swatchColor(name).computeLuminance() > 0.6;
