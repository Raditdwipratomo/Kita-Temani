import 'package:kitatemani/core/config/flavor.dart';

abstract final class Env {
  static const String _flavorRaw = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'dev',
  );

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static const bool forceDummyData = bool.fromEnvironment(
    'USE_DUMMY_DATA',
    defaultValue: false,
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.trim().isNotEmpty &&
      supabaseAnonKey.trim().isNotEmpty &&
      !supabaseUrl.contains('example.supabase.co');

  /// Uses live Supabase backend whenever valid credentials are configured
  /// and offline/dummy override is not forced.
  static bool get useSupabase => isSupabaseConfigured && !forceDummyData;

  /// Backward-compatible alias indicating offline/local-only mode.
  static bool get useDummyData => !useSupabase;

  static AppFlavor get flavor => AppFlavor.fromString(_flavorRaw);
}
