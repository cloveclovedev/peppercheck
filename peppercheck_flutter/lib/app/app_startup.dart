import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

Future<void> appStartup() async {
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.useDeviceLocale();

  // Initialize Google Sign-In
  // serverClientId is auto-detected from google-services.json via com.google.gms.google-services plugin
  await GoogleSignIn.instance.initialize();

  // Future: Add other initialization logic here (e.g., Supabase, Stripe, Logger)
}
