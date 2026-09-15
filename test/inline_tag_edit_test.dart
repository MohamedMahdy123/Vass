import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vess/data/models/item.dart';
import 'package:vess/screens/item_detail_screen.dart';
import 'package:vess/state/wardrobe_state.dart';
import 'package:vess/theme/app_theme.dart';
import 'package:vess/theme/tokens.dart';

void useTallSurface(WidgetTester tester) {
  tester.binding.window.physicalSizeTestValue = const Size(394 * 3, 2600 * 3);
  tester.binding.window.devicePixelRatioTestValue = 3.0;
  addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
  addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
}

Future<List<dynamic>> pumpDetail(WidgetTester tester, Item item) async {
  useTallSurface(tester);
  final w = WardrobeState();
  await w.load();
  await w.add(item);
  final stored = w.items.first; // demo add() assigns a local id
  await tester.pumpWidget(
    ChangeNotifierProvider<WardrobeState>.value(
      value: w,
      child: MaterialApp(
        theme: buildVessTheme(VessTokens.light, Brightness.light),
        home: ItemDetailScreen(itemId: stored.id),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return [w, stored.id];
}

void main() {
  group('ItemDetailScreen — inline tag editing', () {
    testWidgets('adds a tag by expanding the group and tapping a chip',
        (tester) async {
      const item = Item(
        id: 'x',
        name: 'Wool Coat',
        category: 'Outerwear',
        color: 'Charcoal',
        occasions: ['Work'],
      );
      final res = await pumpDetail(tester, item);
      final w = res[0] as WardrobeState;
      final id = res[1] as String;

      // Occasions is the first group → its Edit is the first one.
      await tester.tap(find.text('Edit').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Smart')); // now selectable
      await tester.pumpAndSettle();

      expect(w.byId(id).occasionTags, containsAll(<String>['Work', 'Smart']));
    });

    testWidgets('removes a tag by tapping an active chip', (tester) async {
      const item = Item(
        id: 'y',
        name: 'Trench',
        category: 'Outerwear',
        color: 'Camel',
        occasions: ['Work', 'Smart'],
      );
      final res = await pumpDetail(tester, item);
      final w = res[0] as WardrobeState;
      final id = res[1] as String;

      await tester.tap(find.text('Edit').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Smart')); // deselect
      await tester.pumpAndSettle();

      expect(w.byId(id).occasionTags, ['Work']);
    });

    testWidgets('empty group shows an Add affordance', (tester) async {
      const item = Item(id: 'z', name: 'Tee', category: 'Tops', color: 'White');
      await pumpDetail(tester, item);
      expect(find.text('Add occasions'), findsOneWidget);
      expect(find.text('Add weather'), findsOneWidget);
    });
  });

  group('ItemDetailScreen — inline single-value attrs', () {
    testWidgets('changes Category via the chip picker', (tester) async {
      const item = Item(id: 'c1', name: 'Blazer', category: 'Tops', color: 'Navy');
      final res = await pumpDetail(tester, item);
      final w = res[0] as WardrobeState;
      final id = res[1] as String;

      // The Category row's edit pencil is the first attr editor.
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Outerwear'));
      await tester.pumpAndSettle();

      expect(w.byId(id).category, 'Outerwear');
    });

    testWidgets('edits a free-text attr (Fabric) and saves', (tester) async {
      const item = Item(id: 'f1', name: 'Shirt', category: 'Tops', color: 'White');
      final res = await pumpDetail(tester, item);
      final w = res[0] as WardrobeState;
      final id = res[1] as String;

      // Open the Fabric editor: label rows are Category, Type, Colour, Accent,
      // Fabric, Pattern → pencil index 4.
      final pencils = find.byIcon(Icons.edit_outlined);
      await tester.tap(pencils.at(4));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Linen');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(w.byId(id).fabric, 'Linen');
    });

    testWidgets('clearing a free-text attr sets it to null', (tester) async {
      const item = Item(
        id: 'p1',
        name: 'Tee',
        category: 'Tops',
        color: 'White',
        pattern: 'Striped',
      );
      final res = await pumpDetail(tester, item);
      final w = res[0] as WardrobeState;
      final id = res[1] as String;

      // Pattern is the last attr editor (index 5).
      await tester.tap(find.byIcon(Icons.edit_outlined).at(5));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(w.byId(id).pattern, isNull);
    });
  });
}
