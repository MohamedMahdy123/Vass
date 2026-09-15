import 'package:flutter_test/flutter_test.dart';
import 'package:vess/data/models/item.dart';
import 'package:vess/data/models/missing_item.dart';
import 'package:vess/services/complete_the_look_service.dart';
import 'package:vess/state/complete_the_look_state.dart';

Item _i(String name, String category, {String? color, String? occasion}) =>
    Item(id: name, name: name, category: category, color: color, occasion: occasion, status: ItemStatus.reviewed);

List<Item> _workLook() => [
      _i('Oxford Shirt', 'Tops', color: 'Ivory', occasion: 'Work'),
      _i('Tailored Trousers', 'Bottoms', color: 'Charcoal', occasion: 'Work'),
      _i('Leather Loafers', 'Footwear', color: 'Cognac', occasion: 'Work'),
    ];

void main() {
  group('CompleteTheLookService (mock offers)', () {
    test('returns three offers priced within the gap band', () async {
      const gap = MissingItem(
        slot: 'Belt',
        descriptor: ItemDescriptor(category: 'belt', color: 'tan', material: 'leather', style: 'slim'),
        reason: 'ties the waist together',
        priceHint: PriceHint(20, 70),
        confidence: 0.8,
      );
      final offers = await CompleteTheLookService().offersFor(gap);
      expect(offers.length, 3);
      for (final o in offers) {
        expect(o.priceCents, inInclusiveRange(20 * 100, 70 * 100));
        expect(o.url, contains('http'));
        expect(o.isMock, isTrue);
        expect(o.brand.trim(), isNotEmpty);
      }
    });
  });

  group('CompleteTheLookState', () {
    test('gap with no owned match → shows shoppable offers', () async {
      final s = CompleteTheLookState();
      final look = _workLook();
      await s.analyze(look, look, occasion: 'Work', weather: 'Mild');

      expect(s.hasSuggestion, isTrue);
      expect(s.gap!.slot, 'Belt');
      expect(s.closetMatch, isNull);
      expect(s.offers.length, 3);
    });

    test('closet-first: an owned belt wins over shopping', () async {
      final s = CompleteTheLookState();
      final look = _workLook();
      final wardrobe = [
        ...look,
        _i('Leather Belt', 'Accessories', color: 'Tan', occasion: 'Work'),
      ];
      await s.analyze(look, wardrobe, occasion: 'Work', weather: 'Mild');

      expect(s.hasSuggestion, isTrue);
      expect(s.closetMatch, isNotNull);
      expect(s.closetMatch!.name, 'Leather Belt');
      expect(s.offers, isEmpty);
    });

    test('a complete look → no suggestion', () async {
      final s = CompleteTheLookState();
      final look = [
        ..._workLook(),
        _i('Leather Belt', 'Accessories', color: 'Tan', occasion: 'Work'),
        _i('Structured Bag', 'Accessories', color: 'Black', occasion: 'Work'),
        _i('Wool Blazer', 'Outerwear', color: 'Navy', occasion: 'Work'),
      ];
      await s.analyze(look, look, occasion: 'Work', weather: 'Mild');
      expect(s.hasSuggestion, isFalse);
      expect(s.gap, isNull);
    });
  });
}
