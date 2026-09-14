import 'package:flutter_test/flutter_test.dart';
import 'package:vess/data/models/item.dart';
import 'package:vess/data/models/outfit.dart';
import 'package:vess/services/outfit_engine.dart';
import 'package:vess/state/recommendation_state.dart';

/// A small, realistic wardrobe covering the core slots.
List<Item> _wardrobe() => const [
      Item(id: 'top-1', name: 'Oxford Shirt', category: 'Tops', color: 'Ivory', occasion: 'Work', season: 'All', status: ItemStatus.reviewed),
      Item(id: 'top-2', name: 'Emerald Knit', category: 'Tops', color: 'Emerald', occasion: 'Casual', season: 'Winter', status: ItemStatus.reviewed),
      Item(id: 'bot-1', name: 'Tailored Trousers', category: 'Bottoms', color: 'Charcoal', occasion: 'Work', season: 'All', status: ItemStatus.reviewed),
      Item(id: 'bot-2', name: 'Straight Jeans', category: 'Bottoms', color: 'Indigo', occasion: 'Casual', season: 'All', status: ItemStatus.reviewed),
      Item(id: 'sho-1', name: 'Leather Loafers', category: 'Footwear', color: 'Cognac', occasion: 'Work', season: 'All', status: ItemStatus.reviewed),
      Item(id: 'out-1', name: 'Wool Overcoat', category: 'Outerwear', color: 'Taupe', occasion: 'Work', season: 'Winter', status: ItemStatus.reviewed),
      Item(id: 'acc-1', name: 'Cashmere Scarf', category: 'Accessories', color: 'Sage', occasion: 'Casual', season: 'Winter', status: ItemStatus.reviewed),
      Item(id: 'dre-1', name: 'Linen Dress', category: 'Dresses', color: 'Bone', occasion: 'Smart', season: 'Summer', status: ItemStatus.reviewed),
    ];

void main() {
  group('OutfitEngine.slotOf', () {
    test('maps free-text categories to normalized slots', () {
      expect(OutfitEngine.slotOf(const Item(id: '1', name: 'x', category: 'Tops')), 'Tops');
      expect(OutfitEngine.slotOf(const Item(id: '2', name: 'x', category: 'Bottoms')), 'Bottoms');
      expect(OutfitEngine.slotOf(const Item(id: '3', name: 'x', category: 'Footwear')), 'Footwear');
      expect(OutfitEngine.slotOf(const Item(id: '4', name: 'x', category: 'Outerwear')), 'Outerwear');
      expect(OutfitEngine.slotOf(const Item(id: '5', name: 'x', category: 'Linen Dress')), 'Dress');
      expect(OutfitEngine.slotOf(const Item(id: '6', name: 'x', category: 'Accessories')), 'Accessories');
      // Unknown → Tops, so an untagged piece still lands somewhere sensible.
      expect(OutfitEngine.slotOf(const Item(id: '7', name: 'x', category: 'Mystery')), 'Tops');
    });
  });

  group('OutfitEngine.build', () {
    test('builds a complete, coherent look with a real reason', () {
      final o = OutfitEngine.build(_wardrobe(), occasion: 'Work', weather: 'Mild');
      expect(o, isNotNull);

      final slots = o!.itemIds
          .map((id) => _wardrobe().firstWhere((i) => i.id == id))
          .map(OutfitEngine.slotOf)
          .toSet();
      // A look is either separates+shoes or dress+shoes.
      final hasCore = (slots.contains('Tops') && slots.contains('Bottoms')) ||
          slots.contains('Dress');
      expect(hasCore, isTrue);
      expect(slots.contains('Footwear'), isTrue);

      // The "why" is concrete and non-empty.
      expect(o.reason.trim(), isNotEmpty);
      expect(o.reason.endsWith('.'), isTrue);
      expect(o.title, isNotEmpty);
    });

    test('only chooses from the wardrobe it was given', () {
      final w = _wardrobe();
      final o = OutfitEngine.build(w, occasion: 'Work')!;
      for (final id in o.itemIds) {
        expect(w.any((i) => i.id == id), isTrue, reason: 'invented item $id');
      }
    });

    test('excludes disliked items', () {
      final o = OutfitEngine.build(
        _wardrobe(),
        occasion: 'Casual',
        dislikedIds: {'top-1', 'top-2', 'dre-1'},
      );
      // With every top and the dress disliked, no coherent core remains.
      expect(o, isNull);
    });

    test('adds outerwear when cold, drops it when warm', () {
      final cold = OutfitEngine.build(_wardrobe(), occasion: 'Work', weather: 'Cold')!;
      final coldSlots =
          cold.itemIds.map((id) => _wardrobe().firstWhere((i) => i.id == id)).map(OutfitEngine.slotOf);
      expect(coldSlots.contains('Outerwear'), isTrue);

      final warm = OutfitEngine.build(_wardrobe(), occasion: 'Casual', weather: 'Warm')!;
      final warmSlots =
          warm.itemIds.map((id) => _wardrobe().firstWhere((i) => i.id == id)).map(OutfitEngine.slotOf);
      expect(warmSlots.contains('Outerwear'), isFalse);
    });

    test('returns null when a wardrobe cannot form a look', () {
      const onlyAccessories = [
        Item(id: 'a1', name: 'Scarf', category: 'Accessories'),
        Item(id: 'a2', name: 'Hat', category: 'Accessories'),
      ];
      expect(OutfitEngine.build(onlyAccessories), isNull);
    });
  });

  group('RecommendationState (demo mode)', () {
    test('generate produces today\'s look; not-enough-items yields none', () async {
      final s = RecommendationState();
      expect(s.isLive, isFalse);

      await s.generate(const []); // empty wardrobe
      expect(s.hasOutfit, isFalse);

      await s.generate(_wardrobe());
      expect(s.hasOutfit, isTrue);
      expect(s.todayItems, isNotEmpty);
    });

    test('accept clears the current look', () async {
      final s = RecommendationState();
      await s.generate(_wardrobe());
      expect(s.hasOutfit, isTrue);

      await s.accept(_wardrobe());
      expect(s.hasOutfit, isFalse);
    });

    test('reject steers away from the rejected anchor and offers another look',
        () async {
      final s = RecommendationState();
      s.setOccasion('Work');
      await s.generate(_wardrobe());
      final firstAnchor = s.todayItems
          .firstWhere((i) => OutfitEngine.slotOf(i) == 'Tops' ||
              OutfitEngine.slotOf(i) == 'Dress')
          .id;

      await s.reject(_wardrobe());
      // Still offering something...
      expect(s.hasOutfit, isTrue);
      // ...and not the piece we just rejected.
      final stillHasAnchor = s.todayItems.any((i) => i.id == firstAnchor);
      expect(stillHasAnchor, isFalse);
    });
  });

  group('OutfitSuggestion', () {
    test('round-trips through toInsert / fromMap', () {
      const o = OutfitSuggestion(
        title: 'The Quiet Professional',
        itemIds: ['a', 'b'],
        reason: 'Because it works.',
        occasion: 'Work',
        status: OutfitStatus.accepted,
      );
      final row = o.toInsert();
      expect(row['title'], 'The Quiet Professional');
      expect(row['status'], 'accepted');

      final back = OutfitSuggestion.fromMap(
        {'id': 'x', 'title': row['title'], 'reason': row['reason'], 'status': row['status']},
        ['a', 'b'],
      );
      expect(back.id, 'x');
      expect(back.status, OutfitStatus.accepted);
      expect(back.itemIds, ['a', 'b']);
    });
  });
}
