import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vess/data/mock_data.dart';
import 'package:vess/screens/shell.dart';
import 'package:vess/state/app_state.dart';
import 'package:vess/state/complete_the_look_state.dart';
import 'package:vess/state/recommendation_state.dart';
import 'package:vess/state/stylist_state.dart';
import 'package:vess/state/tryon_state.dart';
import 'package:vess/state/wardrobe_state.dart';
import 'package:vess/theme/app_theme.dart';
import 'package:vess/theme/tokens.dart';

/// Renders at the phone size the design targets (394×850), so these tests
/// exercise the real layout rather than the 800×600 test default.
void usePhoneSurface(WidgetTester tester) {
  tester.binding.window.physicalSizeTestValue = const Size(394 * 3, 850 * 3);
  tester.binding.window.devicePixelRatioTestValue = 3.0;
  addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
  addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
}

/// Mounts a screen inside the theme + providers the real app supplies.
Widget wrap(Widget child, AppState state) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: state),
      ChangeNotifierProvider(create: (_) => WardrobeState()),
      ChangeNotifierProvider(create: (_) => RecommendationState()),
      ChangeNotifierProvider(create: (_) => TryOnState()),
      ChangeNotifierProvider(create: (_) => StylistState()),
      ChangeNotifierProvider(create: (_) => CompleteTheLookState()),
    ],
    child: MaterialApp(
      theme: buildVessTheme(VessTokens.light, Brightness.light),
      home: child,
    ),
  );
}

void main() {
  group('AppState', () {
    test('category filter narrows the closet', () {
      final s = AppState();
      expect(s.visibleCloset.length, kCloset.length);

      s.setCategory('Tops');
      expect(s.visibleCloset.every((i) => i.cat == 'Tops'), isTrue);
      expect(s.visibleCloset.length, 4);
    });

    test('toggling a favourite updates the wishlist', () {
      final s = AppState();
      final before = s.wishlist.length;

      // Item 2 (Oxford Shirt) starts un-favourited.
      s.toggleFav(2);
      expect(s.wishlist.length, before + 1);

      s.toggleFav(2);
      expect(s.wishlist.length, before);
    });

    test('aiFill fills every slot and clear empties them', () {
      final s = AppState();
      expect(s.outfitCount, 0);

      s.aiFill();
      expect(s.outfitCount, AppState.slots.length);
      // Each slot gets a piece from its own category.
      expect(s.outfit['Top']!.cat, 'Tops');
      expect(s.outfit['Shoes']!.cat, 'Footwear');

      s.clearOutfit();
      expect(s.outfitCount, 0);
    });

    test('aiFill keeps a piece the user already picked', () {
      final s = AppState();
      final chosen = s.optionsFor('Top').last;
      s.pick('Top', chosen);

      s.aiFill();
      expect(s.outfit['Top'], same(chosen));
    });

    test('sending a message appends the reply and clears typing', () async {
      final s = AppState();
      final before = s.messages.length;

      await s.send('What should I wear?');

      expect(s.messages.length, before + 2);
      expect(s.messages[before].isAI, isFalse);
      expect(s.messages.last.isAI, isTrue);
      expect(s.typing, isFalse);
    });
  });

  group('Shell', () {
    testWidgets('opens on Home and switches tabs', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(wrap(const Shell(), AppState()));
      await tester.pumpAndSettle();

      // Home is the daily recommendation hero; its occasion rail is Home-only.
      expect(find.text('Everyday'), findsOneWidget);

      // Tabs are keyed: "Closet" also appears as a card label on Home.
      await tester.tap(find.byKey(const ValueKey('tab-Closet')));
      await tester.pumpAndSettle();
      expect(find.text('Digital closet'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tab-Stylist')));
      await tester.pumpAndSettle();
      expect(find.text('Your stylist'), findsOneWidget);
    });

    // Closet filtering is now covered against the real WardrobeState in
    // wardrobe_test.dart; the Closet tab is no longer backed by AppState.

    testWidgets('dark mode toggle repaints the app', (tester) async {
      usePhoneSurface(tester);
      final state = AppState();
      await tester.pumpWidget(wrap(const Shell(initialIndex: 4), state));
      await tester.pumpAndSettle();

      expect(state.isDark, isFalse);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(state.isDark, isTrue);
    });
  });
}
