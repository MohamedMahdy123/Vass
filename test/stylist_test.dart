import 'package:flutter_test/flutter_test.dart';
import 'package:vess/data/models/item.dart';
import 'package:vess/services/stylist_service.dart';
import 'package:vess/state/stylist_state.dart';

List<Item> _wardrobe() => const [
      Item(id: 'top-1', name: 'Oxford Shirt', category: 'Tops', color: 'Ivory', occasion: 'Work', favorite: true),
      Item(id: 'bot-1', name: 'Tailored Trousers', category: 'Bottoms', color: 'Charcoal', occasion: 'Work'),
      Item(id: 'sho-1', name: 'Leather Loafers', category: 'Footwear', color: 'Cognac', occasion: 'Work'),
      Item(id: 'out-1', name: 'Wool Overcoat', category: 'Outerwear', color: 'Taupe', season: 'Winter'),
    ];

void main() {
  group('StylistService (demo mode)', () {
    final s = StylistService();

    test('is not live without a backend', () {
      expect(s.isLive, isFalse);
    });

    test('answers an occasion question with a concrete look', () async {
      final reply = await s.ask('what should I wear to work?', _wardrobe());
      expect(reply.trim(), isNotEmpty);
      // Grounded in the real closet — names an actual piece.
      final mentionsReal = ['Oxford Shirt', 'Tailored Trousers', 'Leather Loafers']
          .any(reply.contains);
      expect(mentionsReal, isTrue);
    });

    test('surfaces favourites when asked', () async {
      final reply = await s.ask('show me my favourites', _wardrobe());
      expect(reply.contains('Oxford Shirt'), isTrue);
    });

    test('nudges to add pieces when the closet is empty', () async {
      final reply = await s.ask('what should I wear?', const []);
      expect(reply.toLowerCase().contains('empty'), isTrue);
    });
  });

  group('StylistState (demo mode)', () {
    test('send appends the user message and an AI reply, clears typing', () async {
      final st = StylistState();
      final before = st.messages.length;

      await st.send('what should I wear to work?', _wardrobe());

      expect(st.messages.length, before + 2);
      expect(st.messages[before].isAI, isFalse);
      expect(st.messages.last.isAI, isTrue);
      expect(st.typing, isFalse);
    });

    test('starter prompts hide once the user has spoken', () async {
      final st = StylistState();
      expect(st.showPrompts, isTrue);
      await st.send('hi', _wardrobe());
      expect(st.showPrompts, isFalse);
    });
  });
}
