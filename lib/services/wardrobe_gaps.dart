import '../data/models/item.dart';
import '../data/models/missing_item.dart';
import 'outfit_engine.dart';

/// Wardrobe-level gap detection for the Shopping screen.
///
/// Builds representative looks across occasions/weathers from the real closet,
/// runs the per-look finishing-piece detector ([OutfitEngine.findGap]), drops
/// any gap the wardrobe can already fill, and returns the distinct remaining
/// gaps ranked by confidence. Deterministic and offline — no network.
class WardrobeGaps {
  const WardrobeGaps._();

  static const _occasions = ['Work', 'Smart', 'Casual', 'Formal'];
  static const _weathers = <String?>[null, 'Cold'];

  static List<MissingItem> detect(List<Item> wardrobe) {
    if (wardrobe.length < 3) return const [];
    final byId = {for (final i in wardrobe) i.id: i};
    final found = <String, MissingItem>{};
    var seed = 0;
    for (final occasion in _occasions) {
      for (final weather in _weathers) {
        final look = OutfitEngine.build(
          wardrobe,
          occasion: occasion,
          weather: weather,
          seed: seed++,
        );
        if (look == null) continue;
        final items =
            look.itemIds.map((id) => byId[id]).whereType<Item>().toList();
        final gap =
            OutfitEngine.findGap(items, occasion: occasion, weather: weather);
        if (gap == null) continue;
        if (owns(wardrobe, gap)) continue; // already covered — not a shop need
        final key = '${gap.slot}|${gap.descriptor.category}';
        final existing = found[key];
        if (existing == null || gap.confidence > existing.confidence) {
          found[key] = gap;
        }
      }
    }
    return found.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
  }

  /// True when the wardrobe already owns a piece for this finishing slot.
  static bool owns(List<Item> wardrobe, MissingItem gap) {
    bool matches(Item i) {
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

    return wardrobe.any(matches);
  }
}
