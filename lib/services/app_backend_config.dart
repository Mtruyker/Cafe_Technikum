import 'app_backend_local.dart' as local;

class AppBackendConfig {
  const AppBackendConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  factory AppBackendConfig.fromEnvironment() {
    const envSupabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: '',
    );
    const envSupabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: '',
    );

    return AppBackendConfig(
      supabaseUrl: envSupabaseUrl.trim().isNotEmpty
          ? envSupabaseUrl
          : local.supabaseUrl,
      supabaseAnonKey: envSupabaseAnonKey.trim().isNotEmpty
          ? envSupabaseAnonKey
          : local.supabaseAnonKey,
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  String get missingConfigurationMessage {
    return 'Supabase не настроен. Заполните '
        'lib/services/app_backend_local.dart '
        'или передайте '
        '--dart-define=SUPABASE_URL=... '
        '--dart-define=SUPABASE_ANON_KEY=...';
  }
}
