import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/core/config/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfigState {
  const SupabaseConfigState({
    required this.url,
    required this.anonKey,
    required this.useDummyData,
    required this.isInitialized,
  });

  final String url;
  final String anonKey;
  final bool useDummyData;
  final bool isInitialized;
}

final supabaseInitializedProvider = Provider<bool>((ref) => false);

final supabaseConfigProvider = Provider<SupabaseConfigState>((ref) {
  final initialized = ref.watch(supabaseInitializedProvider);
  return SupabaseConfigState(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    useDummyData: !initialized,
    isInitialized: initialized,
  );
});

/// Returns active [SupabaseClient] when initialized; otherwise null (triggers local persistence fallback).
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  final initialized = ref.watch(supabaseInitializedProvider);
  if (!initialized) return null;
  try {
    return Supabase.instance.client;
  } on Object {
    return null;
  }
});
