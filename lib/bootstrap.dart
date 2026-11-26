import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/app.dart';
import 'package:kitatemani/core/config/env.dart';
import 'package:kitatemani/core/services/local_preferences_service.dart';
import 'package:kitatemani/core/supabase/supabase_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  var supabaseReady = false;
  if (Env.useSupabase) {
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseAnonKey,
      );
      supabaseReady = true;
    } on Object {
      supabaseReady = false;
    }
  }

  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } on Object {
    prefs = null;
  }

  runApp(
    ProviderScope(
      overrides: [
        supabaseInitializedProvider.overrideWithValue(supabaseReady),
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const KitaTemaniApp(),
    ),
  );
}
