/// Build-time environment configuration supplied via `--dart-define-from-file`.
///
/// Never embed a Supabase `service_role` or secret key in the Flutter client.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
  static const String siteUrl = String.fromEnvironment(
    'SITE_URL',
    defaultValue: 'https://www.promptindo.app',
  );

  static String get normalizedSiteUrl => _stripTrailingSlash(siteUrl);

  static String get normalizedApiBaseUrl => _stripTrailingSlash(
    apiBaseUrl.isNotEmpty ? apiBaseUrl : siteUrl,
  );

  static void validate() {
    if (supabaseUrl.trim().isEmpty || supabaseAnonKey.trim().isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL or SUPABASE_ANON_KEY. '
        'Run with --dart-define-from-file=env/dev.json.',
      );
    }
  }

  static String _stripTrailingSlash(String raw) {
    final trimmed = raw.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
