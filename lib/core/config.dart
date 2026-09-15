/// App configuration.
///
/// Secrets are passed at build/run time via `--dart-define`, never committed:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// The anon key is safe to ship in the app — it only grants what Row Level
/// Security allows. The Anthropic key lives ONLY in the Edge Functions and is
/// never referenced here.
class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Optional Hugging Face token for the free try-on engine. A signed-in HF
  /// token gets a much larger ZeroGPU quota than anonymous requests, making the
  /// free engine usable for real testing. Supply it only in a local/testing
  /// build — a token shipped in a public app is exposed:
  ///
  ///   flutter run --dart-define=HF_TOKEN=hf_xxx
  static const hfToken = String.fromEnvironment('HF_TOKEN');

  /// When keys aren't provided the app runs in local demo mode (the original
  /// mock prototype), so it's always runnable. Real auth + data switch on the
  /// moment these are supplied.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
