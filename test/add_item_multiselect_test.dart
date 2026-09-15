import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vess/data/models/item.dart';
import 'package:vess/screens/add_item_screen.dart';
import 'package:vess/state/wardrobe_state.dart';
import 'package:vess/theme/app_theme.dart';
import 'package:vess/theme/tokens.dart';

void usePhoneSurface(WidgetTester tester) {
  // Tall surface so the whole form renders without scrolling (a ListView
  // doesn't build its off-screen children, and find.text ignores offstage).
  tester.binding.window.physicalSizeTestValue = const Size(394 * 3, 1800 * 3);
  tester.binding.window.devicePixelRatioTestValue = 3.0;
  addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
  addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
}

/// Seeds [item] into a real (demo-mode) WardrobeState, then mounts the edit
/// form on the stored copy. Returns the state and the stored item's id so the
/// caller can assert on the saved result.
Future<List<dynamic>> pumpEdit(WidgetTester tester, Item item) async {
  usePhoneSurface(tester);
  final w = WardrobeState();
  await w.load();
  await w.add(item);
  final stored = w.items.first; // demo add() assigns a local id
  await tester.pumpWidget(
    ChangeNotifierProvider<WardrobeState>.value(
      value: w,
      child: MaterialApp(
        theme: buildVessTheme(VessTokens.light, Brightness.light),
        home: AddItemScreen(existing: stored),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return [w, stored.id];
}

void main() {
  group('AddItemScreen — multi-select occasion / season / weather', () {
    testWidgets('pre-selects the item\'s existing tags', (tester) async {
      const item = Item(
        id: 'edit-1',
        name: 'Wool Coat',
        category: 'Outerwear',
        occasions: ['Work', 'Smart'],
        seasons: ['Winter'],
        weatherTags: ['Cold', 'Rain'],
      );
      await pumpEdit(tester, item);

      // The multi-select labels render, and the item's tags are on screen.
      expect(find.text('Occasion'), findsOneWidget);
      expect(find.text('Weather'), findsOneWidget);
      expect(find.text('Smart'), findsWidgets);
      expect(find.text('Rain'), findsWidgets);
    });

    testWidgets('all three groups render as multi-select', (tester) async {
      const item = Item(id: 'edit-0', name: 'Tee', category: 'Tops');
      await pumpEdit(tester, item);
      expect(find.text('Occasion'), findsOneWidget);
      expect(find.text('Season'), findsOneWidget);
      expect(find.text('Weather'), findsOneWidget);
    });

    testWidgets('toggling several chips saves them all as lists', (tester) async {
      const item = Item(
        id: 'edit-2',
        name: 'Linen Shirt',
        category: 'Tops',
        occasions: ['Casual'],
      );
      final res = await pumpEdit(tester, item);
      final w = res[0] as WardrobeState;
      final id = res[1] as String;

      // Add a second occasion and two weather tags.
      await tester.tap(find.text('Work'));
      await tester.tap(find.text('Hot'));
      await tester.tap(find.text('Warm'));
      await tester.pump();

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      final saved = w.byId(id);
      expect(saved.occasions, containsAll(<String>['Casual', 'Work']));
      expect(saved.weatherTags, containsAll(<String>['Hot', 'Warm']));
    });

    testWidgets('tapping an active chip removes it', (tester) async {
      const item = Item(
        id: 'edit-3',
        name: 'Trench',
        category: 'Outerwear',
        occasions: ['Work', 'Smart'],
      );
      final res = await pumpEdit(tester, item);
      final w = res[0] as WardrobeState;
      final id = res[1] as String;

      await tester.tap(find.text('Smart')); // deselect
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      final saved = w.byId(id);
      expect(saved.occasions, ['Work']);
      expect(saved.occasions, isNot(contains('Smart')));
    });
  });
}
