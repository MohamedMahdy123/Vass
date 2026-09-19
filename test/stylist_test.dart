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

    test('answers an occasion question with a concrete look + action', () async {
      final reply = await s.ask('what should I wear to work?', _wardrobe());
      expect(reply.text.trim(), isNotEmpty);
      // Grounded in the real closet — names an actual piece.
      final mentionsReal = ['Oxford Shirt', 'Tailored Trousers', 'Leather Loafers']
          .any(reply.text.contains);
      expect(mentionsReal, isTrue);
      // Actionable: a "see this look" card that deep-links to the composed look.
      expect(reply.action?.type, StylistActionType.viewOutfit);
      expect(reply.action!.itemIds, isNotEmpty);
    });

    test('surfaces favourites when asked', () async {
      final reply = await s.ask('show me my favourites', _wardrobe());
      expect(reply.text.contains('Oxford Shirt'), isTrue);
    });

    test('routes "my outfits" to the saved-looks gallery', () async {
      final reply = await s.ask('show me my outfits', _wardrobe());
      expect(reply.action?.type, StylistActionType.openOutfits);
    });

    test('routes a named item to its detail', () async {
      final reply = await s.ask('show me my Wool Overcoat', _wardrobe());
      expect(reply.action?.type, StylistActionType.openItem);
      expect(reply.action?.itemId, 'out-1');
    });

    test('greets warmly instead of dumping a canned line', () async {
      final reply = await s.ask('HI', _wardrobe());
      expect(reply.text.toLowerCase(), contains('stylist'));
      // A greeting should NOT force an outfit card.
      expect(reply.action?.type, isNot(StylistActionType.viewOutfit));
    });

    test('builds a look for a typo-filled request (never the canned dump)', () async {
      // "I have a date tomorrow and I don't know what I should wear" — mangled.
      final reply = await s.ask(
          'i have data towmmer and i dont know what i should waer', _wardrobe());
      expect(reply.action?.type, StylistActionType.viewOutfit);
      expect(reply.action!.itemIds, isNotEmpty);
      // "data" ~ "date" (edit distance 1) → styled as a Smart look.
      expect(reply.action!.occasion, 'Smart');
    });

    test('always answers a vague message with a real look', () async {
      final reply = await s.ask('idk help', _wardrobe());
      expect(reply.action?.type, StylistActionType.viewOutfit);
      expect(reply.text, isNot(contains('Ask me')));
    });

    test('nudges to add pieces when the closet is empty', () async {
      final reply = await s.ask('what should I wear?', const []);
      expect(reply.text.toLowerCase().contains('empty'), isTrue);
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
