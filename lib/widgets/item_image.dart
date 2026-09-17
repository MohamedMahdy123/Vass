import 'package:flutter/material.dart';

import '../core/supabase_service.dart';
import '../data/models/item.dart';
import '../data/wardrobe_repository.dart';
import 'garment_silhouette.dart';

/// The single garment renderer for the whole app — wardrobe grid, item cards,
/// outfit suggestions and try-on chips all go through this so every piece reads
/// like a clean e-commerce product shot: the matted garment centred on a subtle
/// neutral tonal card.
///
/// Rendering priority (most product-shot-like first):
///   1. `processedBytes`      — just-processed transparent cut-out (in memory)
///   2. `processedImageUrl`   — stored transparent cut-out (URL or storage path)
///   3. `localBytes`          — the raw just-captured photo (pre-processing)
///   4. `imagePath`           — the raw original photo (URL or storage path)
///   5. a flat-lay garment silhouette in the item's colour (demo/seed, manual)
///
/// Cut-outs (1–2) are matted `contain` with padding on the card so nothing is
/// clipped; raw photos (3–4) fill the card `cover`.
class ItemImage extends StatelessWidget {
  const ItemImage({super.key, required this.item, this.radius = 18, this.child});

  final Item item;
  final double radius;
  final Widget? child;

  /// Inset kept around a matted cut-out so the garment never touches the edge.
  static const double _matPadding = 0.10;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);

    // 1 & 2 — transparent cut-out in memory: mat it, contained, on the card.
    if (item.processedBytes != null) {
      return _card(
        context,
        r,
        _matted(Image.memory(item.processedBytes!, fit: BoxFit.contain)),
      );
    }

    // 3 — raw just-captured photo (no cut-out yet): show it filling the card.
    if (item.localBytes != null) {
      return _card(context, r, Image.memory(item.localBytes!, fit: BoxFit.cover));
    }

    // Prefer the stored cut-out over the stored original.
    final cutoutUrl = item.processedImageUrl;
    final originalUrl = item.imagePath;
    final path = cutoutUrl ?? originalUrl;
    final isCutout = cutoutUrl != null;

    // A bundled asset cut-out (demo seed / catalog defaults) — matted like any
    // other cut-out, falling back to the silhouette if the file is missing.
    if (path != null && path.startsWith('assets/')) {
      final img = Image.asset(path,
          fit: BoxFit.contain, errorBuilder: (_, __, ___) => _silhouette());
      return _card(context, r, _matted(img));
    }

    // 2/4 — a full URL (demo/catalog/cut-out CDN) renders directly.
    if (path != null && (path.startsWith('http://') || path.startsWith('https://'))) {
      final img = Image.network(path,
          fit: isCutout ? BoxFit.contain : BoxFit.cover,
          errorBuilder: (_, __, ___) => _silhouette());
      return _card(context, r, isCutout ? _matted(img) : img);
    }

    // A storage path is only meaningful against a live backend.
    if (path == null || !SupabaseService.isReady) {
      // 5 — no photo at all: clean flat-lay silhouette.
      return _card(context, r, _silhouette());
    }

    return _card(
      context,
      r,
      FutureBuilder<String>(
        future: WardrobeRepository().signedUrl(path),
        builder: (context, snap) {
          if (!snap.hasData) return _silhouette();
          final img = Image.network(snap.data!,
              fit: isCutout ? BoxFit.contain : BoxFit.cover,
              errorBuilder: (_, __, ___) => _silhouette());
          return isCutout ? _matted(img) : img;
        },
      ),
    );
  }

  /// The catalog card ground: a flat, un-tinted near-white (or deep neutral in
  /// dark mode) so garments sit on a clean background with no colour cast —
  /// white-background product photos blend in seamlessly.
  Widget _card(BuildContext context, BorderRadius r, Widget content) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ground = dark ? const Color(0xFF201E1B) : const Color(0xFFFAF9F6);

    return ClipRRect(
      borderRadius: r,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: ground),
          content,
          if (child != null) child!,
        ],
      ),
    );
  }

  /// Centre and pad a contained cut-out so it never clips the card edge.
  Widget _matted(Widget img) => LayoutBuilder(
        builder: (context, c) {
          final pad = c.biggest.shortestSide * _matPadding;
          return Padding(padding: EdgeInsets.all(pad), child: Center(child: img));
        },
      );

  Widget _silhouette() =>
      GarmentSilhouette(category: item.category, color: swatchColor(item.primaryColor));
}

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
