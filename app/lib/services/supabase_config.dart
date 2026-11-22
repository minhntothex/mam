// Build-time Supabase configuration via `--dart-define`.
// Keeps secrets out of source control and allows running 100% offline/local demo
// when SUPABASE_URL and SUPABASE_ANON_KEY are omitted.

abstract final class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
