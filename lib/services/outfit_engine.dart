import '../data/models/item.dart';
import '../data/models/missing_item.dart';
import '../data/models/outfit.dart';

/// The deterministic outfit builder — the same rules the server's `recommend`
/// function encodes, run locally so demo mode gives a *real* recommendation
/// (not a canned one) and so the logic is unit-testable without a backend.
///
/// It narrows the wardrobe to coherent candidates (occasion, season/weather,
/// not-disliked), assembles a complete look (top + bottom, or a dress, plus
/// shoes; outerwear when it's cold), prefers colors and formality that agree,
/// and writes a concrete "why". A rotating [seed] gives a different valid look
/// on each "Try again".
class OutfitEngine {
  /// Normalized wardrobe slot for an item's free-text category.
  static String slotOf(Item i) {
    final c = (i.category ?? '').toLowerCase();
    if (c.contains('dress')) return 'Dress';
    if (c.contains('outerwear') || c.contains('coat') || c.contains('jacket')) {
      return 'Outerwear';
    }
    if (c.contains('footwear') || c.contains('shoe') || c.contains('boot') ||
        c.contains('sneaker')) {
      return 'Footwear';
    }
    if (c.contains('accessor') || c.contains('scarf') || c.contains('bag') ||
        c.contains('hat')) {
      return 'Accessories';
    }
    if (c.contains('bottom') || c.contains('trouser') || c.contains('jean') ||
        c.contains('pant') || c.contains('skirt') || c.contains('short')) {
      return 'Bottoms';
    }
    // Default everything else (tops, knitwear, shirts, blouses) to Tops.
    return 'Tops';
  }

  /// How dressy an occasion is, 0 (casual) → 3 (formal). Used to keep the
  /// pieces in a look at a similar register.
  static int formality(String? occasion) {
    switch ((occasion ?? '').toLowerCase()) {
      case 'formal':
      case 'evening':
        return 3;
      case 'work':
      case 'smart':
      case 'business':
        return 2;
      case 'casual':
      case 'everyday':
        return 0;
      default:
        return 1;
    }
  }

  /// Neutral colors combine with anything; a look built on neutrals + one
  /// accent reads as intentional. Loud + loud does not.
  static bool isNeutral(String? color) {
    final c = (color ?? '').toLowerCase();
    const neutrals = {
      'black', 'white', 'grey', 'gray', 'ash', 'charcoal', 'ivory', 'chalk',
      'bone', 'cream', 'sand', 'beige', 'taupe', 'camel', 'tan', 'khaki',
      'navy', 'onyx', 'espresso', 'mocha', 'brown', 'cognac', 'stone', 'oat',
    };
    if (neutrals.contains(c)) return true;
    // Multi-word / descriptive neutrals ("light grey", "off white").
    return neutrals.any((n) => c.contains(n));
  }

  static bool _warm(String? weather) {
    final w = (weather ?? '').toLowerCase();
    return w.contains('warm') || w.contains('hot') || w.contains('sun') ||
        w.contains('summer');
  }

  static bool _cold(String? weather) {
    final w = (weather ?? '').toLowerCase();
    return w.contains('cold') || w.contains('snow') || w.contains('freez') ||
        w.contains('winter') || w.contains('chill');
  }

  static bool _seasonFits(Item i, String? weather) {
    // Prefer explicit weather tags (the richer signal) when the piece has them.
    final tags = i.weatherTags.map((t) => t.toLowerCase()).toList();
    if (tags.isNotEmpty) {
      if (_warm(weather)) return !tags.contains('cold');
      if (_cold(weather)) return !tags.contains('hot');
      return true;
    }
    final s = (i.season ?? '').toLowerCase();
    if (s.isEmpty || s == 'all') return true;
    if (_warm(weather)) return s != 'winter';
    if (_cold(weather)) return s != 'summer';
    return true; // mild weather: everything's fair game
  }

  /// Build one look. Returns null when the wardrobe can't form a complete
  /// outfit (e.g. no shoes, or nothing but accessories).
  static OutfitSuggestion? build(
    List<Item> items, {
    String? occasion,
    String? weather,
    Set<String> dislikedIds = const {},
    int seed = 0,
  }) {
    final targetFormality = formality(occasion);

    // Score an item for this context: lower is better. Season/formality fit,
    // freshness (avoid what was worn most / most recently), plus a stable
    // per-seed jitter so "Try again" explores other valid combinations.
    double score(Item i) {
      var s = 0.0;
      if (!_seasonFits(i, weather)) s += 4;
      final occ = (i.occasion ?? '').toLowerCase();
      if (occ.isNotEmpty && occ != 'all') {
        s += (formality(i.occasion) - targetFormality).abs().toDouble();
      }
      s += i.wearCount * 0.15; // gently favor under-worn pieces
      // Deterministic jitter, distinct per seed and item.
      final j = (i.id.hashCode ^ (seed * 2654435761)) & 0x7fffffff;
      s += (j % 100) / 90.0;
      return s;
    }

    final pool = items
        .where((i) => !dislikedIds.contains(i.id))
        .where((i) => _seasonFits(i, weather))
        .toList();
    // If the season filter emptied a slot we still want a look, so fall back to
    // the full (non-disliked) set when needed, per slot, below.
    final fallback =
        items.where((i) => !dislikedIds.contains(i.id)).toList();

    List<Item> bySlot(List<Item> from, String slot) {
      final list = from.where((i) => slotOf(i) == slot).toList()
        ..sort((a, b) => score(a).compareTo(score(b)));
      return list;
    }

    Item? pick(String slot) {
      final primary = bySlot(pool, slot);
      if (primary.isNotEmpty) return primary.first;
      final backup = bySlot(fallback, slot);
      return backup.isEmpty ? null : backup.first;
    }

    final chosen = <Item>[];
    final slotFor = <String, Item>{};

    // Prefer a dress-led look only when a dress genuinely fits better than a
    // top+bottom for the occasion; otherwise build the classic three pieces.
    final dresses = bySlot(pool, 'Dress');
    final tops = bySlot(pool, 'Tops');
    final bottoms = bySlot(pool, 'Bottoms');
    final canSeparates = tops.isNotEmpty && bottoms.isNotEmpty;
    final useDress = dresses.isNotEmpty &&
        (!canSeparates || (targetFormality >= 2 && (seed % 2 == 0)));

    if (useDress) {
      chosen.add(dresses.first);
      slotFor['Dress'] = dresses.first;
    } else if (canSeparates) {
      chosen.add(tops.first);
      chosen.add(bottoms.first);
      slotFor['Top'] = tops.first;
      slotFor['Bottom'] = bottoms.first;
    } else {
      return null; // not enough to make a coherent core
    }

    final shoes = pick('Footwear');
    if (shoes == null) return null; // a look needs shoes
    chosen.add(shoes);
    slotFor['Shoes'] = shoes;

    // Outerwear: required when cold, optional otherwise (skip if warm).
    if (!_warm(weather)) {
      final outer = pick('Outerwear');
      if (outer != null && (_cold(weather) || targetFormality >= 2)) {
        chosen.add(outer);
        slotFor['Outerwear'] = outer;
      }
    }

    // One accessory to finish, if a fitting one exists.
    final acc = pick('Accessories');
    if (acc != null) {
      chosen.add(acc);
      slotFor['Accessory'] = acc;
    }

    final title = _titleFor(occasion, chosen);
    final reason = _reasonFor(
      chosen: chosen,
      slotFor: slotFor,
      occasion: occasion,
      weather: weather,
    );

    return OutfitSuggestion(
      title: title,
      itemIds: chosen.map((i) => i.id).toList(),
      reason: reason,
      occasion: occasion,
    );
  }

  static String _titleFor(String? occasion, List<Item> chosen) {
    final o = (occasion ?? '').toLowerCase();
    if (o == 'work' || o == 'smart' || o == 'business') return 'The Quiet Professional';
    if (o == 'formal' || o == 'evening') return 'After Hours';
    if (o == 'casual' || o == 'everyday') return 'Easy Everyday';
    // Fall back to something drawn from the anchor piece.
    final anchor = chosen.first;
    final color = anchor.color;
    if (color != null && color.isNotEmpty) return 'The $color Edit';
    return 'Today\'s Look';
  }

  /// The "why" — assembled from the *actual* choices so it's never generic.
  static String _reasonFor({
    required List<Item> chosen,
    required Map<String, Item> slotFor,
    String? occasion,
    String? weather,
  }) {
    final parts = <String>[];

    final anchor = slotFor['Dress'] ?? slotFor['Top'] ?? chosen.first;
    final occ = (occasion == null || occasion.isEmpty) ? 'today' : 'for $occasion';
    parts.add('${anchor.name} anchors this look $occ');

    final bottom = slotFor['Bottom'];
    if (bottom != null) {
      parts.add('the ${bottom.name.toLowerCase()} keeps it grounded and easy to move in');
    }

    // Color logic, stated plainly.
    final colors = chosen
        .map((i) => i.color)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toList();
    final accents = colors.where((c) => !isNeutral(c)).toList();
    if (accents.isNotEmpty) {
      parts.add('${accents.first} lifts an otherwise neutral palette without shouting');
    } else if (colors.isNotEmpty) {
      parts.add('a tonal, neutral palette that always reads as considered');
    }

    final outer = slotFor['Outerwear'];
    if (outer != null) {
      final w = _cold(weather)
          ? "it's cold out, so the ${outer.name.toLowerCase()} does the heavy lifting"
          : 'the ${outer.name.toLowerCase()} adds a layer you can shed indoors';
      parts.add(w);
    }

    final shoes = slotFor['Shoes'];
    if (shoes != null) {
      parts.add('finished with the ${shoes.name.toLowerCase()}');
    }

    // Join into one warm sentence, capitalized, single period.
    final joined = parts.join(', ');
    return '${joined[0].toUpperCase()}${joined.substring(1)}.';
  }

  // === Complete-the-Look: gap detection ======================================
  // Given an assembled outfit, find the single highest-impact *finishing* piece
  // it's missing (belt / outerwear-layer / bag) for the occasion and weather.
  // Deterministic and explainable; returns null when the look is already
  // complete — we never invent a gap.

  /// The finishing slots this MVP reasons about.
  static MissingItem? findGap(
    List<Item> outfit, {
    String? occasion,
    String? weather,
  }) {
    if (outfit.isEmpty) return null;

    final f = formality(occasion);
    final cold = _cold(weather);
    final slots = outfit.map(slotOf).toSet();
    final hasSeparates = slots.contains('Tops') && slots.contains('Bottoms');
    final hasDress = slots.contains('Dress');
    // A core (separates or a dress) must exist — completing the core is the
    // recommender's job, not the finisher's.
    if (!hasSeparates && !hasDress) return null;

    final candidates = <MissingItem>[];

    // --- Outerwear / tailored layer ---
    if (!slots.contains('Outerwear')) {
      var need = 0.0;
      if (cold) need += 2.5;
      if (f >= 2) need += 1.5;
      if (need >= 2) {
        final coat = cold;
        candidates.add(MissingItem(
          slot: 'Outerwear',
          descriptor: ItemDescriptor(
            category: coat ? 'wool coat' : 'blazer',
            color: _pickNeutral(outfit, fallback: coat ? 'camel' : 'navy'),
            material: coat ? 'wool' : null,
            style: 'tailored',
          ),
          reason: cold
              ? "It's cold for ${_occ(occasion)} — a tailored coat keeps the look sharp and warm."
              : "This reads a little casual for ${_occ(occasion)} — a tailored blazer lifts it.",
          priceHint: coat ? const PriceHint(120, 400) : const PriceHint(80, 250),
          confidence: (need / 4).clamp(0, 1).toDouble(),
        ));
      }
    }

    // --- Belt (finishes tailored separates) ---
    if (hasSeparates && !_hasKeyword(outfit, const ['belt'])) {
      var need = 0.0;
      if (f >= 2) {
        need += 2.5;
      } else if (f == 1) {
        need += 1.0;
      }
      if (need >= 2) {
        candidates.add(MissingItem(
          slot: 'Belt',
          descriptor: ItemDescriptor(
            category: 'belt',
            color: _pickNeutral(outfit, fallback: 'tan'),
            material: 'leather',
            style: 'slim',
          ),
          reason: "Your ${_anchorName(outfit)} and ${_bottomName(outfit)} "
              "read a touch unfinished for ${_occ(occasion)} — a slim leather "
              "belt ties the waist together.",
          priceHint: const PriceHint(20, 70),
          confidence: (need / 3).clamp(0, 1).toDouble(),
        ));
      }
    }

    // --- Bag (finishes work / going-out looks) ---
    if (!_hasKeyword(
        outfit, const ['bag', 'tote', 'clutch', 'purse', 'backpack', 'satchel'])) {
      var need = 0.0;
      if (f >= 2) need += 1.8;
      if (f == 3) need += 0.6;
      if (need >= 1.8) {
        final evening = f >= 3;
        candidates.add(MissingItem(
          slot: 'Bag',
          descriptor: ItemDescriptor(
            category: evening ? 'clutch' : 'shoulder bag',
            color: _pickNeutral(outfit, fallback: 'black'),
            material: 'leather',
            style: evening ? 'evening' : 'structured',
          ),
          reason: "Finish the look for ${_occ(occasion)} with a "
              "${evening ? 'sleek clutch' : 'structured bag'} — it pulls the "
              "whole outfit together.",
          priceHint: const PriceHint(40, 180),
          confidence: (need / 3).clamp(0, 1).toDouble(),
        ));
      }
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    return candidates.first;
  }

  static bool _hasKeyword(List<Item> items, List<String> keywords) {
    return items.any((i) {
      final hay = '${i.name} ${i.category ?? ''}'.toLowerCase();
      return keywords.any(hay.contains);
    });
  }

  /// A neutral color to give the finishing piece: prefer the shoes' color when
  /// it's neutral (belts/bags echo footwear well), else any neutral in the
  /// look, else the fallback.
  static String _pickNeutral(List<Item> items, {required String fallback}) {
    Item? shoes;
    for (final i in items) {
      if (slotOf(i) == 'Footwear') {
        shoes = i;
        break;
      }
    }
    if (shoes?.color != null && isNeutral(shoes!.color)) {
      return shoes.color!.toLowerCase();
    }
    for (final i in items) {
      if (isNeutral(i.color)) return i.color!.toLowerCase();
    }
    return fallback;
  }

  static String _occ(String? occasion) =>
      (occasion == null || occasion.trim().isEmpty) ? 'today' : occasion.toLowerCase();

  static String _anchorName(List<Item> items) {
    for (final i in items) {
      final s = slotOf(i);
      if (s == 'Tops' || s == 'Dress') return i.name.toLowerCase();
    }
    return items.isEmpty ? 'top' : items.first.name.toLowerCase();
  }

  static String _bottomName(List<Item> items) {
    for (final i in items) {
      if (slotOf(i) == 'Bottoms') return i.name.toLowerCase();
    }
    return 'bottoms';
  }
}
