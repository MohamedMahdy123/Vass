import 'package:flutter_test/flutter_test.dart';
import 'package:vess/data/models/item.dart';
import 'package:vess/services/wardrobe_gaps.dart';

/// A formal-capable set of separates with NO finishing pieces (no outerwear,
/// belt, or bag) — every completeable look should surface a gap to shop.
List<Item> _bareEssentials() => const [
      Item(id: 'top-1', name: 'Oxford Shirt', category: 'Tops', color: 'Ivory', occasion: 'Work', season: 'All', status: ItemStatus.reviewed),
      Item(id: 'bot-1', name: 'Tailored Trousers', category: 'Bottoms', color: 'Charcoal', occasion: 'Work', season: 'All', status: ItemStatus.reviewed),
      Item(id: 'sho-1', name: 'Leather Loafers', category: 'Footwear', color: 'Black', occasion: 'Work', season: 'All', status: ItemStatus.reviewed),
    ];

void main() {
  group('WardrobeGaps.detect', () {
    test('surfaces shopping gaps when finishing pieces are missing', () {
      final gaps = WardrobeGaps.detect(_bareEssentials());
      expect(gaps, isNotEmpty);
      // Every returned gap is a real finishing slot with a reason + price band.
      for (final g in gaps) {
        expect(const ['Outerwear', 'Belt', 'Bag'], contains(g.slot));
        expect(g.reason.trim(), isNotEmpty);
        expect(g.priceHint.max, greaterThanOrEqualTo(g.priceHint.min));
      }
      // No duplicate slot+category entries.
      final keys = gaps.map((g) => '${g.slot}|${g.descriptor.category}').toList();
      expect(keys.toSet().length, keys.length);
    });

    test('returns nothing once the wardrobe owns those finishing pieces', () {
      final complete = [
        ..._bareEssentials(),
        const Item(id: 'out-1', name: 'Wool Overcoat', category: 'Outerwear', color: 'Camel', occasion: 'Work', season: 'Winter', status: ItemStatus.reviewed),
        const Item(id: 'blt-1', name: 'Leather Belt', category: 'Accessories', color: 'Tan', occasion: 'Work', season: 'All', status: ItemStatus.reviewed),
        const Item(id: 'bag-1', name: 'Structured Bag', category: 'Accessories', color: 'Black', occasion: 'Work', season: 'All', status: ItemStatus.reviewed),
      ];
      expect(WardrobeGaps.detect(complete), isEmpty);
    });

    test('a too-small wardrobe yields no gaps', () {
      expect(WardrobeGaps.detect(const []), isEmpty);
    });
  });
}
