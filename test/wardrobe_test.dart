import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vess/data/models/item.dart';
import 'package:vess/screens/closet_screen.dart';
import 'package:vess/state/wardrobe_state.dart';
import 'package:vess/theme/app_theme.dart';
import 'package:vess/theme/tokens.dart';
import 'package:vess/widgets/item_image.dart';

void usePhoneSurface(WidgetTester tester) {
  tester.binding.window.physicalSizeTestValue = const Size(394 * 3, 850 * 3);
  tester.binding.window.devicePixelRatioTestValue = 3.0;
  addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
  addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
}

Item draft(String name, {String category = 'Tops', String? color}) =>
    Item(id: '', name: name, category: category, color: color, status: ItemStatus.reviewed);

void main() {
  group('WardrobeState (demo mode)', () {
    test('seeds a starter closet on first load', () async {
      final w = WardrobeState();
      expect(w.count, 0);
      await w.load();
      expect(w.count, greaterThan(8));
      expect(w.isLive, isFalse);
    });

    test('category filter narrows the view', () async {
      final w = WardrobeState();
      await w.load();
      final total = w.count;

      w.setCategory('Bottoms');
      expect(w.visibleItems.every((i) => i.category == 'Bottoms'), isTrue);
      expect(w.visibleItems.length, lessThan(total));

      w.setCategory('All');
      expect(w.visibleItems.length, total);
    });

    test('add inserts a new item at the front', () async {
      final w = WardrobeState();
      await w.load();
      final before = w.count;

      await w.add(draft('Test Jacket', category: 'Outerwear'));
      expect(w.count, before + 1);
      expect(w.items.first.name, 'Test Jacket');
      expect(w.items.first.id, isNotEmpty);
    });

    test('toggleFavorite flips the flag', () async {
      final w = WardrobeState();
      await w.load();
      final id = w.items.first.id;
      final was = w.byId(id).favorite;

      await w.toggleFavorite(id);
      expect(w.byId(id).favorite, !was);
    });

    test('remove deletes the item', () async {
      final w = WardrobeState();
      await w.load();
      final id = w.items.first.id;
      final before = w.count;

      await w.remove(id);
      expect(w.count, before - 1);
      expect(w.items.any((i) => i.id == id), isFalse);
    });
  });

  group('swatchColor', () {
    test('maps known palette names and is deterministic for unknowns', () {
      expect(swatchColor('Charcoal'), const Color(0xFF33343A));
      expect(swatchColor('Emerald'), const Color(0xFF178C64));
      // Unknown but stable.
      expect(swatchColor('Zorblax'), equals(swatchColor('zorblax')));
      // Empty falls back to a neutral.
      expect(swatchColor(''), const Color(0xFFB8B0A2));
    });
  });

  testWidgets('Closet shows the seeded wardrobe and filters by chip', (tester) async {
    usePhoneSurface(tester);
    final state = WardrobeState();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildVessTheme(VessTokens.light, Brightness.light),
          home: const Scaffold(body: ClosetScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Digital closet'), findsOneWidget);
    // A seeded piece renders.
    expect(find.text('Ribbed Wool Sweater'), findsOneWidget);

    // The chip rail scrolls horizontally; "Dresses" is last and off-screen.
    final chip = find.byKey(const ValueKey('cat-Dresses'));
    await tester.dragUntilVisible(
      chip,
      find.byKey(const ValueKey('cat-rail')),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();

    // Filter to Dresses — the sweater should disappear.
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('Ribbed Wool Sweater'), findsNothing);
    expect(find.text('Linen Dress'), findsOneWidget);
  });
}
