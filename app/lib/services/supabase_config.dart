// Build-time Supabase configuration via `--dart-define`.
// Keeps secrets out of source control and allows running 100% offline/local mode
// when SUPABASE_URL and SUPABASE_ANON_KEY are omitted.

abstract final class SupabaseConfig {
  static const String _rawUrl = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get url => normalizeUrl(_rawUrl);

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Normalizes a configured Supabase project URL to its base origin so an
  /// accidental `/rest/v1/`, `/auth/v1/`, or trailing slash never breaks
  /// Auth/PostgREST/Edge Function paths.
  static String normalizeUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return trimmed;
    return uri.origin;
  }
}
