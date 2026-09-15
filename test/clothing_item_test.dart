import 'package:flutter_test/flutter_test.dart';
import 'package:vess/data/models/item.dart';

void main() {
  group('ClothingItem — rich schema', () {
    test('fromJson reads the rich columns', () {
      final it = ClothingItem.fromJson({
        'id': 'x',
        'name': 'Wool Overcoat',
        'image_url': 'p.jpg',
        'processed_image_url': 'p-cutout.png',
        'category': 'Outerwear',
        'sub_category': 'Overcoat',
        'occasions': ['Work', 'Smart'],
        'seasons': ['Winter'],
        'weather_tags': ['Cold', 'Rain'],
        'color_primary': 'Charcoal',
        'color_secondary': 'Black',
        'fabric_type': 'Wool',
        'status': 'reviewed',
      });
      expect(it.occasions, ['Work', 'Smart']);
      expect(it.weatherTags, ['Cold', 'Rain']);
      expect(it.primaryColor, 'Charcoal');
      expect(it.secondaryColor, 'Black');
      expect(it.fabric, 'Wool');
      expect(it.subCategory, 'Overcoat');
      expect(it.processedImageUrl, 'p-cutout.png');
      expect(it.imageUrl, 'p.jpg');
    });

    test('fromJson falls back to legacy single columns for old rows', () {
      final it = ClothingItem.fromJson({
        'id': 'y',
        'name': 'Old Shirt',
        'image_path': 'legacy.jpg',
        'category': 'Tops',
        'color': 'Ivory',
        'material': 'Cotton',
        'occasion': 'Work',
        'season': 'All',
        'status': 'reviewed',
      });
      expect(it.occasionTags, ['Work']);
      expect(it.seasonTags, ['All']);
      expect(it.primaryColor, 'Ivory');
      expect(it.fabric, 'Cotton');
      expect(it.imageUrl, 'legacy.jpg');
    });

    test('toJson/toInsert carry rich lists + legacy mirrors', () {
      const it = ClothingItem(
        id: 'z',
        name: 'Camel Trench',
        category: 'Outerwear',
        occasions: ['Smart', 'Work'],
        seasons: ['Spring'],
        weatherTags: ['Mild'],
        colorPrimary: 'Camel',
        fabricType: 'Cotton',
      );
      final j = it.toJson();
      expect(j['occasions'], ['Smart', 'Work']);
      expect(j['weather_tags'], ['Mild']);
      expect(j['color_primary'], 'Camel');
      // legacy mirror keys stay populated for single-value readers
      expect(j['occasion'], 'Smart');
      expect(j['color'], 'Camel');

      final ins = it.toInsert();
      expect(ins['occasions'], ['Smart', 'Work']);
      expect(ins['fabric_type'], 'Cotton');
      expect(ins.containsKey('user_id'), isFalse); // server-set
    });

    test('legacy const construction still resolves through getters', () {
      const it = ClothingItem(
        id: 'a', name: 'Loafers', category: 'Footwear',
        color: 'Cognac', occasion: 'Work', season: 'All', material: 'Leather',
      );
      expect(it.primaryColor, 'Cognac');
      expect(it.occasionTags, ['Work']);
      expect(it.fabric, 'Leather');
    });
  });
}
