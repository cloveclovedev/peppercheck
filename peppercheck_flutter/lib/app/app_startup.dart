import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:peppercheck_flutter/app/config/app_environment.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> appStartup(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.useDeviceLocale();

  // Initialize Google Sign-In
  // serverClientId is auto-detected from google-services.json via com.google.gms.google-services plugin
  await GoogleSignIn.instance.initialize();

  // Initialize Supabase
  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
  );

  // Future: Add other initialization logic here (e.g., Stripe, Logger)
}
