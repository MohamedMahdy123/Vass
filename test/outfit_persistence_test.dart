import 'package:flutter_test/flutter_test.dart';
import 'package:vess/data/models/item.dart';
import 'package:vess/state/outfit_state.dart';

/// A minimal wardrobe with the slots the canvas needs to form a look.
List<Item> _wardrobe() => const [
      Item(id: 'top-1', name: 'Oxford Shirt', category: 'Tops', color: 'Ivory', occasion: 'Work', season: 'All', status: ItemStatus.reviewed),
      Item(id: 'bot-1', name: 'Tailored Trousers', category: 'Bottoms', color: 'Charcoal', occasion: 'Work', season: 'All', status: ItemStatus.reviewed),
      Item(id: 'sho-1', name: 'Leather Loafers', category: 'Footwear', color: 'Cognac', occasion: 'Work', season: 'All', status: ItemStatus.reviewed),
    ];

void _composeLook(OutfitState s, List<Item> w) {
  for (final i in w) {
    s.place(i);
  }
}

void main() {
  group('OutfitState persistence (demo / offline)', () {
    // With no Supabase configured, _isLive is false: save/load/remove must all
    // work in memory and never touch (or throw from) the backend.

    test('load seeds demo looks when offline so the gallery is never empty', () async {
      final s = OutfitState();
      await s.load(_wardrobe());
      expect(s.saved, isNotEmpty);
    });

    test('load with an empty wardrobe is a no-op', () async {
      final s = OutfitState();
      await s.load(const []);
      expect(s.saved, isEmpty);
    });

    test('saveCanvas keeps the look in memory with a local id', () {
      final s = OutfitState();
      final w = _wardrobe();
      _composeLook(s, w);
      final id = s.saveCanvas();
      expect(id, isNotNull);
      expect(id!, startsWith('look-'));
      expect(s.saved.any((o) => o.id == id), isTrue);
      // The saved look carries the composed pieces and a computed score.
      final look = s.saved.firstWhere((o) => o.id == id);
      expect(look.items.length, 3);
      expect(look.score, greaterThan(0));
    });

    test('saveCanvas on an empty canvas returns null', () {
      final s = OutfitState();
      expect(s.saveCanvas(), isNull);
    });

    test('removeSaved drops the look and never throws for a local id', () {
      final s = OutfitState();
      _composeLook(s, _wardrobe());
      final id = s.saveCanvas()!;
      s.removeSaved(id);
      expect(s.saved.any((o) => o.id == id), isFalse);
    });
  });
}
