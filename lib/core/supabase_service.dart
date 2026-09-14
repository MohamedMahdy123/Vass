import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';

/// Thin wrapper around the Supabase singleton so the rest of the app doesn't
/// depend on it being initialized. In demo mode (no keys) [isReady] is false
/// and [client] must not be used.
class SupabaseService {
  static bool _ready = false;
  static bool get isReady => _ready;

  static Future<void> init() async {
    if (!Config.isConfigured) return;
    await Supabase.initialize(
      url: Config.supabaseUrl,
      anonKey: Config.supabaseAnonKey,
    );
    _ready = true;
  }

  static SupabaseClient get client => Supabase.instance.client;
}
