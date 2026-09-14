import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vess/screens/login_screen.dart';
import 'package:vess/services/auth_service.dart';
import 'package:vess/state/app_state.dart';
import 'package:vess/state/recommendation_state.dart';
import 'package:vess/state/tryon_state.dart';
import 'package:vess/state/wardrobe_state.dart';
import 'package:vess/theme/app_theme.dart';
import 'package:vess/theme/tokens.dart';

/// Renders at the phone size the design targets.
void usePhoneSurface(WidgetTester tester) {
  tester.binding.window.physicalSizeTestValue = const Size(394 * 3, 850 * 3);
  tester.binding.window.devicePixelRatioTestValue = 3.0;
  addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
  addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
}

void main() {
  group('AuthService (demo mode)', () {
    test('signs in and out locally when Supabase is not configured', () async {
      final auth = AuthService();
      expect(auth.isConfigured, isFalse);
      expect(auth.isSignedIn, isFalse);

      await auth.signIn('anyone@vess.app', 'whatever');
      expect(auth.isSignedIn, isTrue);

      await auth.signOut();
      expect(auth.isSignedIn, isFalse);
    });

    test('sign-up also signs the user in locally', () async {
      final auth = AuthService();
      await auth.signUp('new@vess.app', 'secret', name: 'Maya');
      expect(auth.isSignedIn, isTrue);
    });
  });

  testWidgets('Login screen signs in and lands on Home', (tester) async {
    usePhoneSurface(tester);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthService()),
          ChangeNotifierProvider(create: (_) => AppState()),
          ChangeNotifierProvider(create: (_) => WardrobeState()),
          ChangeNotifierProvider(create: (_) => RecommendationState()),
          ChangeNotifierProvider(create: (_) => TryOnState()),
        ],
        child: MaterialApp(
          theme: buildVessTheme(VessTokens.light, Brightness.light),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);

    // Demo mode accepts any credentials and routes into the app shell.
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    // Landed on Home — the daily recommendation hero (its occasion rail).
    expect(find.text('Everyday'), findsOneWidget);
  });
}
