import 'package:flutter/foundation.dart';

import '../data/models/item.dart';
import '../data/models/missing_item.dart';
import '../data/models/product_offer.dart';
import '../services/complete_the_look_service.dart';
import '../services/outfit_engine.dart';

/// Drives the "Complete the look" loop for the current outfit: detect the gap,
/// try to fill it from the user's own closet first, and only otherwise fetch
/// shoppable offers. Derived state — call [analyze] whenever the shown outfit
/// changes.
class CompleteTheLookState extends ChangeNotifier {
  CompleteTheLookState({CompleteTheLookService? service})
      : _service = service ?? CompleteTheLookService();

  final CompleteTheLookService _service;

  String _key = '';
  bool _loading = false;
  MissingItem? _gap;
  Item? _closetMatch;
  List<ProductOffer> _offers = const [];

  MissingItem? get gap => _gap;
  Item? get closetMatch => _closetMatch;
  List<ProductOffer> get offers => List.unmodifiable(_offers);
  bool get loading => _loading;

  /// True when there's something to show (a gap was found).
  bool get hasSuggestion => _gap != null;

  /// Analyze [outfit] for a finishing gap. Idempotent per outfit/occasion, so
  /// it's safe to call from a build post-frame.
  Future<void> analyze(
    List<Item> outfit,
    List<Item> wardrobe, {
    String? occasion,
    String? weather,
  }) async {
    final key = '$occasion|${outfit.map((i) => i.id).join(",")}';
    if (key == _key) return;
    _key = key;

    final gap = OutfitEngine.findGap(outfit, occasion: occasion, weather: weather);
    _gap = gap;
    _closetMatch = null;
    _offers = const [];
    _loading = false;
    if (gap == null) {
      notifyListeners();
      return;
    }

    // Closet-first: recommend an owned piece before any shop link.
    _closetMatch = _matchInCloset(gap, wardrobe, outfit);
    if (_closetMatch != null) {
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();
    try {
      _offers = await _service.offersFor(gap);
    } catch (_) {
      _offers = const [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    _key = '';
    _loading = false;
    _gap = null;
    _closetMatch = null;
    _offers = const [];
    notifyListeners();
  }

  Item? _matchInCloset(MissingItem gap, List<Item> wardrobe, List<Item> outfit) {
    final inOutfit = outfit.map((i) => i.id).toSet();
    bool isMatch(Item i) {
      if (inOutfit.contains(i.id)) return false;
      final hay = '${i.name} ${i.category ?? ''}'.toLowerCase();
      switch (gap.slot) {
        case 'Outerwear':
          return OutfitEngine.slotOf(i) == 'Outerwear';
        case 'Belt':
          return hay.contains('belt');
        case 'Bag':
          return const ['bag', 'tote', 'clutch', 'purse', 'backpack', 'satchel']
              .any(hay.contains);
      }
      return false;
    }

    // Prefer a colour-compatible match, but any owned piece beats buying.
    Item? fallback;
    for (final i in wardrobe) {
      if (!isMatch(i)) continue;
      fallback ??= i;
      if (gap.descriptor.color == null ||
          (i.color != null &&
              i.color!.toLowerCase() == gap.descriptor.color!.toLowerCase()) ||
          OutfitEngine.isNeutral(i.color)) {
        return i;
      }
    }
    return fallback;
  }
}
