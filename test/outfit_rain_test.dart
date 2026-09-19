import 'package:flutter_test/flutter_test.dart';
import 'package:vess/data/models/item.dart';
import 'package:vess/data/models/outfit.dart';
import 'package:vess/services/outfit_engine.dart';

void main() {
  // A warm-weather wardrobe with a light rain shell available.
  final wardrobe = <Item>[
    const Item(id: 'top', name: 'Linen Shirt', category: 'Tops', color: 'White', season: 'Summer', status: ItemStatus.reviewed),
    const Item(id: 'bot', name: 'Chino Shorts', category: 'Bottoms', color: 'Sand', season: 'Summer', status: ItemStatus.reviewed),
    const Item(id: 'sho', name: 'Canvas Sneakers', category: 'Footwear', color: 'White', season: 'All', status: ItemStatus.reviewed),
    const Item(id: 'rain', name: 'Rain Shell', category: 'Outerwear', color: 'Navy', fabricType: 'Waterproof', season: 'All', status: ItemStatus.reviewed),
  ];

  String? outerId(OutfitSuggestion? o, List<Item> w) {
    if (o == null) return null;
    for (final id in o.itemIds) {
      final it = w.firstWhere((i) => i.id == id);
      if (OutfitEngine.slotOf(it) == 'Outerwear') return id;
    }
    return null;
  }

  test('warm + dry → no outerwear', () {
    final look = OutfitEngine.build(wardrobe, occasion: 'Casual', weather: 'Warm');
    expect(outerId(look, wardrobe), isNull);
  });

  test('warm + rain → includes the rain shell + umbrella nudge', () {
    final look =
        OutfitEngine.build(wardrobe, occasion: 'Casual', weather: 'Warm rain');
    expect(outerId(look, wardrobe), 'rain'); // layer added despite being warm
    expect(look!.reason.toLowerCase(), contains('umbrella'));
  });
}
