import 'package:flutter/foundation.dart';

import '../data/models/item.dart';

/// A saved look — the members plus the tags and score shown in "My Outfits".
class SavedOutfit {
  const SavedOutfit({
    required this.id,
    required this.title,
    required this.items,
    required this.tags,
    required this.score,
    this.occasion,
  });

  final String id;
  final String title;
  final List<Item> items;

  /// Style/context chips, e.g. ['Casual', 'Warm'].
  final List<String> tags;

  /// The Vess AI Score (0–100).
  final int score;
  final String? occasion;
}

/// The result of analysing a composed outfit — a local, explainable heuristic
/// so it works in demo mode without an AI key. Real Sonnet analysis can replace
/// [text] when a key is configured, but the scores stay deterministic.
class OutfitAnalysis {
  const OutfitAnalysis({
    required this.colorHarmony,
    required this.score,
    required this.styleTags,
    required this.text,
  });

  /// 0–100 colour-harmony percentage.
  final int colorHarmony;

  /// 0–100 overall Vess AI Score.
  final int score;

  /// e.g. ['Warm Weather Fit', 'Casual Elegance'].
  final List<String> styleTags;
  final String text;
}

/// Neutral colour names — a wardrobe of neutrals always reads as harmonious.
const _neutrals = {
  'black', 'white', 'grey', 'gray', 'ivory', 'sand', 'charcoal', 'camel',
  'beige', 'cream', 'tan', 'khaki', 'navy', 'denim', 'ash', 'taupe', 'bone',
  'chalk', 'onyx', 'espresso', 'mocha', 'cognac', 'brown', 'stone', 'silver',
};

/// Drives the Outfit Canvas, saved looks ("My Outfits") and the Outfit
/// Analysis. Demo-first: saved looks live in memory (seeded so the gallery is
/// never empty); a live backend can layer persistence on top later.
class OutfitState extends ChangeNotifier {
  /// Canvas slots, in layering order (back → front for the stacked preview).
  static const slots = ['Bottom', 'Top', 'Outerwear', 'Shoes', 'Accessory'];
  static const slotCategory = {
    'Bottom': 'Bottoms',
    'Top': 'Tops',
    'Outerwear': 'Outerwear',
    'Shoes': 'Footwear',
    'Accessory': 'Accessories',
  };

  final Map<String, Item> _canvas = {};
  final List<SavedOutfit> _saved = [];
  bool _seeded = false;

  Map<String, Item> get canvas => Map.unmodifiable(_canvas);
  List<Item> get canvasItems =>
      [for (final s in slots) if (_canvas[s] != null) _canvas[s]!];
  bool get isEmpty => _canvas.isEmpty;
  int get count => _canvas.length;

  List<SavedOutfit> get saved => List.unmodifiable(_saved);

  // ---- canvas editing ----------------------------------------------------

  void place(Item item) {
    final slot = _slotFor(item.category);
    if (slot == null) return;
    _canvas[slot] = item;
    notifyListeners();
  }

  void removeSlot(String slot) {
    if (_canvas.remove(slot) != null) notifyListeners();
  }

  void removeItem(Item item) {
    _canvas.removeWhere((_, v) => v.id == item.id);
    notifyListeners();
  }

  void clearCanvas() {
    if (_canvas.isEmpty) return;
    _canvas.clear();
    notifyListeners();
  }

  String? _slotFor(String? category) {
    for (final e in slotCategory.entries) {
      if (e.value == category) return e.key;
    }
    return null;
  }

  // ---- saved outfits -----------------------------------------------------

  /// Seed a couple of example looks the first time (demo mode) so "My Outfits"
  /// isn't empty. Pulls real wardrobe items by category.
  void seedFrom(List<Item> wardrobe) {
    if (_seeded || wardrobe.isEmpty) return;
    _seeded = true;
    // Pick the nth item of a category (wraps), so seeded looks use different
    // pieces instead of all sharing the first of each category.
    List<Item> pool(String cat) => wardrobe.where((i) => i.category == cat).toList();
    Item? pick(String cat, int n) {
      final p = pool(cat);
      return p.isEmpty ? null : p[n % p.length];
    }

    void add(String title, String occasion, List<Item?> picks) {
      final items = picks.whereType<Item>().toList();
      if (items.length < 2) return;
      final a = analyze(items);
      _saved.add(SavedOutfit(
        id: 'seed-${_saved.length}',
        title: title,
        items: items,
        tags: [occasion, ...a.styleTags.take(1)],
        score: a.score,
        occasion: occasion,
      ));
    }

    add('Street Refined', 'Casual',
        [pick('Outerwear', 0), pick('Tops', 0), pick('Bottoms', 0), pick('Footwear', 0)]);
    add('Weekend Casual', 'Casual',
        [pick('Tops', 1), pick('Bottoms', 1), pick('Footwear', 1), pick('Accessories', 0)]);
    add('Smart Layers', 'Work',
        [pick('Outerwear', 1), pick('Tops', 2), pick('Bottoms', 0), pick('Footwear', 2)]);
    add('Day Out', 'Casual',
        [pick('Tops', 3), pick('Bottoms', 1), pick('Footwear', 3)]);
    add('Evening Ease', 'Smart',
        [pick('Dresses', 0), pick('Footwear', 1), pick('Accessories', 0)]);
    if (_saved.isNotEmpty) notifyListeners();
  }

  /// Save the current canvas as a look. Returns the new id (or null if empty).
  String? saveCanvas({String? title}) {
    final items = canvasItems;
    if (items.isEmpty) return null;
    final a = analyze(items);
    final occasion = _dominant(items.expand((i) => i.occasionTags)) ?? 'Casual';
    final id = 'look-${DateTime.now().microsecondsSinceEpoch}';
    _saved.insert(
      0,
      SavedOutfit(
        id: id,
        title: title ?? _titleFor(items, occasion),
        items: items,
        tags: [occasion, ...a.styleTags.take(1)],
        score: a.score,
        occasion: occasion,
      ),
    );
    notifyListeners();
    return id;
  }

  void removeSaved(String id) {
    _saved.removeWhere((o) => o.id == id);
    notifyListeners();
  }

  // ---- analysis (local heuristic) ----------------------------------------

  /// Analyse the current canvas.
  OutfitAnalysis get analysis => analyze(canvasItems);

  /// Analyse an arbitrary set of items. Deterministic and explainable.
  OutfitAnalysis analyze(List<Item> items) {
    if (items.isEmpty) {
      return const OutfitAnalysis(
        colorHarmony: 0, score: 0, styleTags: [], text: 'Add pieces to see how they work together.');
    }

    // Colour harmony: neutrals are always safe; each extra strong hue costs a
    // little, but a single accent on neutrals reads as intentional.
    final colors = items
        .map((i) => (i.primaryColor ?? '').toLowerCase().trim())
        .where((c) => c.isNotEmpty)
        .toList();
    final strong = colors.where((c) => !_neutrals.contains(c)).toSet();
    var harmony = 96 - (strong.length <= 1 ? 0 : (strong.length - 1) * 9);
    if (colors.isEmpty) harmony = 80;
    harmony = harmony.clamp(64, 97);

    // Completeness: a top + bottom (or a dress) with shoes reads as a full look.
    final cats = items.map((i) => i.category).toSet();
    final hasCore = (cats.contains('Tops') && cats.contains('Bottoms')) ||
        cats.contains('Dresses');
    final hasShoes = cats.contains('Footwear');
    final completeness =
        (hasCore ? 60 : 30) + (hasShoes ? 25 : 0) + (items.length >= 3 ? 15 : 0);

    final score = ((harmony * 0.6) + (completeness.clamp(0, 100) * 0.4)).round();

    // Style tags.
    final tags = <String>[];
    final weather = _dominant(items.expand((i) => i.weatherTags));
    if (weather != null) {
      const warm = {'hot', 'warm', 'mild'};
      tags.add(warm.contains(weather.toLowerCase())
          ? 'Warm Weather Fit'
          : 'Cool Weather Fit');
    }
    final occ = _dominant(items.expand((i) => i.occasionTags));
    if (occ != null) {
      final o = occ.toLowerCase();
      tags.add(o.contains('formal') || o.contains('smart')
          ? 'Refined Tailoring'
          : (o.contains('work')
              ? 'Workwear Ready'
              : 'Casual Elegance'));
    }
    if (tags.isEmpty) tags.add('Everyday Ease');

    return OutfitAnalysis(
      colorHarmony: harmony,
      score: score.clamp(0, 100),
      styleTags: tags,
      text: _analysisText(items, harmony, strong, weather, occ),
    );
  }

  String _analysisText(List<Item> items, int harmony, Set<String> strong,
      String? weather, String? occ) {
    final anchor = items.first.name;
    final layered = items.any((i) => i.category == 'Outerwear');
    final palette = strong.isEmpty
        ? 'an all-neutral palette that reads clean and intentional'
        : (strong.length == 1
            ? 'a neutral base lifted by one considered accent'
            : 'a few colours in play — keep one as the hero');
    final layer = layered
        ? 'The layered piece adds structure and dresses it up a notch'
        : 'A single clean layer keeps it easy to move in';
    final tail = <String>[];
    if (weather != null) tail.add('best for ${weather.toLowerCase()} days');
    if (occ != null) tail.add('tuned for ${occ.toLowerCase()}');
    final tailStr = tail.isEmpty ? '.' : ' — ${tail.join(', ')}.';
    return 'Built around the $anchor, this look leans on $palette. $layer$tailStr';
  }

  String? _dominant(Iterable<String> values) {
    final counts = <String, int>{};
    for (final v in values) {
      final k = v.trim();
      if (k.isEmpty) continue;
      counts[k] = (counts[k] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _titleFor(List<Item> items, String occasion) {
    final anchor = items.firstWhere(
      (i) => i.category == 'Outerwear' || i.category == 'Dresses',
      orElse: () => items.first,
    );
    return '$occasion · ${anchor.name}';
  }
}
