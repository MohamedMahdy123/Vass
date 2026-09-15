import 'package:flutter_test/flutter_test.dart';
import 'package:vess/data/models/item.dart';
import 'package:vess/services/outfit_engine.dart';

Item _i(String name, String category, {String? color, String? occasion, String? season}) =>
    Item(id: name, name: name, category: category, color: color, occasion: occasion, season: season, status: ItemStatus.reviewed);

void main() {
  group('OutfitEngine.findGap', () {
    test('work separates with no belt → suggests a belt, echoing shoe colour', () {
      final outfit = [
        _i('Oxford Shirt', 'Tops', color: 'Ivory', occasion: 'Work'),
        _i('Tailored Trousers', 'Bottoms', color: 'Charcoal', occasion: 'Work'),
        _i('Leather Loafers', 'Footwear', color: 'Cognac', occasion: 'Work'),
      ];
      final gap = OutfitEngine.findGap(outfit, occasion: 'Work', weather: 'Mild');
      expect(gap, isNotNull);
      expect(gap!.slot, 'Belt');
      expect(gap.descriptor.category, 'belt');
      expect(gap.descriptor.color, 'cognac'); // matched the loafers
      expect(gap.query.toLowerCase(), contains('belt'));
      expect(gap.reason.trim(), isNotEmpty);
      expect(gap.confidence, inInclusiveRange(0, 1));
    });

    test('cold casual with no outerwear → suggests a coat', () {
      final outfit = [
        _i('Ribbed Sweater', 'Tops', color: 'Ash', occasion: 'Casual', season: 'Winter'),
        _i('Straight Jeans', 'Bottoms', color: 'Indigo', occasion: 'Casual'),
        _i('White Sneakers', 'Footwear', color: 'White', occasion: 'Casual'),
      ];
      final gap = OutfitEngine.findGap(outfit, occasion: 'Casual', weather: 'Cold');
      expect(gap, isNotNull);
      expect(gap!.slot, 'Outerwear');
      expect(gap.query.toLowerCase(), contains('coat'));
    });

    test('dress-led work look → suggests a bag (belt not applicable)', () {
      final outfit = [
        _i('Linen Dress', 'Dresses', color: 'Bone', occasion: 'Smart'),
        _i('Black Heels', 'Footwear', color: 'Black', occasion: 'Smart'),
      ];
      final gap = OutfitEngine.findGap(outfit, occasion: 'Work', weather: 'Mild');
      expect(gap, isNotNull);
      expect(gap!.slot, 'Bag');
    });

    test('a complete work look → no gap invented', () {
      final outfit = [
        _i('Oxford Shirt', 'Tops', color: 'Ivory', occasion: 'Work'),
        _i('Tailored Trousers', 'Bottoms', color: 'Charcoal', occasion: 'Work'),
        _i('Leather Loafers', 'Footwear', color: 'Cognac', occasion: 'Work'),
        _i('Leather Belt', 'Accessories', color: 'Tan', occasion: 'Work'),
        _i('Structured Tote Bag', 'Accessories', color: 'Black', occasion: 'Work'),
        _i('Wool Blazer', 'Outerwear', color: 'Navy', occasion: 'Work'),
      ];
      expect(OutfitEngine.findGap(outfit, occasion: 'Work'), isNull);
    });

    test('an easy everyday look → no gap (casual is forgiving)', () {
      final outfit = [
        _i('Cotton Tee', 'Tops', color: 'Sand', occasion: 'Casual'),
        _i('Straight Jeans', 'Bottoms', color: 'Indigo', occasion: 'Casual'),
        _i('Sneakers', 'Footwear', color: 'White', occasion: 'Casual'),
      ];
      expect(OutfitEngine.findGap(outfit, occasion: 'Everyday', weather: 'Mild'), isNull);
    });

    test('empty or core-less input yields no gap', () {
      expect(OutfitEngine.findGap(const [], occasion: 'Work'), isNull);
      final onlyShoes = [_i('Loafers', 'Footwear', color: 'Brown')];
      expect(OutfitEngine.findGap(onlyShoes, occasion: 'Work'), isNull);
    });
  });
}
