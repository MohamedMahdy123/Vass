/// A price band (whole dollars) hinting what the missing piece should cost —
/// used to filter affiliate product results and set expectations.
class PriceHint {
  const PriceHint(this.min, this.max);
  final int min;
  final int max;

  Map<String, dynamic> toMap() => {'min': min, 'max': max};
}

/// A structured description of a garment to look for — the bridge between gap
/// detection and a product search. [query] is what gets sent to an affiliate
/// catalog.
class ItemDescriptor {
  const ItemDescriptor({
    required this.category,
    this.color,
    this.material,
    this.style,
  });

  final String category; // 'belt', 'blazer', 'shoulder bag', ...
  final String? color;
  final String? material;
  final String? style;

  /// A natural search phrase, e.g. "slim tan leather belt".
  String get query => [style, color, material, category]
      .where((s) => s != null && s.trim().isNotEmpty)
      .join(' ');

  Map<String, dynamic> toMap() => {
        'category': category,
        'color': color,
        'material': material,
        'style': style,
      };
}

/// The one highest-impact piece an outfit is missing, with the reason it helps.
/// Deterministic rules produce this; a later LLM pass can refine the descriptor
/// and reason. Null (from the detector) means the look is already complete —
/// never invent a gap.
class MissingItem {
  const MissingItem({
    required this.slot,
    required this.descriptor,
    required this.reason,
    required this.priceHint,
    required this.confidence,
  });

  /// Normalized finishing slot: 'Outerwear' | 'Belt' | 'Bag'.
  final String slot;
  final ItemDescriptor descriptor;

  /// One warm, concrete sentence on why this piece completes the look.
  final String reason;
  final PriceHint priceHint;

  /// 0..1 — how strongly the occasion/weather call for this piece.
  final double confidence;

  String get query => descriptor.query;

  Map<String, dynamic> toMap() => {
        'slot': slot,
        'descriptor': descriptor.toMap(),
        'query': query,
        'reason': reason,
        'price_hint': priceHint.toMap(),
        'confidence': confidence,
      };
}
