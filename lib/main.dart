import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/supabase_service.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'state/app_state.dart';
import 'state/complete_the_look_state.dart';
import 'state/outfit_state.dart';
import 'state/recommendation_state.dart';
import 'state/stylist_state.dart';
import 'state/tryon_state.dart';
import 'state/wardrobe_state.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No-op in demo mode; connects to the project when keys are supplied.
  await SupabaseService.init();
  runApp(const VessApp());
}

class VessApp extends StatelessWidget {
  const VessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => WardrobeState()),
        ChangeNotifierProvider(create: (_) => RecommendationState()),
        ChangeNotifierProvider(create: (_) => TryOnState()),
        ChangeNotifierProvider(create: (_) => StylistState()),
        ChangeNotifierProvider(create: (_) => CompleteTheLookState()),
        ChangeNotifierProvider(create: (_) => OutfitState()),
      ],
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'Vess',
            debugShowCheckedModeBanner: false,
            themeMode: state.themeMode,
            theme: buildVessTheme(VessTokens.light, Brightness.light),
            darkTheme: buildVessTheme(VessTokens.dark, Brightness.dark),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
