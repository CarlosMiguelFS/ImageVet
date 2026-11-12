// ImagiVet — Feito por Carlos Miguel Fernandes dos Santos.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/supabase_config.dart';
import 'data/game_backend.dart';
import 'state/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AuthService auth;
  GameBackend? backend;
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.publishableKey);
    auth = SupabaseAuthService();
    backend = SupabaseGameBackend();
  } else {
    auth = LocalAuthService();
  }
  await auth.init();

  runApp(ImagiVetApp(auth: auth, backend: backend));
}
