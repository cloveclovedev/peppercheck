import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:peppercheck_flutter/app/config/app_environment.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

Future<void> appStartup(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.useDeviceLocale();

  // Load environment variables
  await dotenv.load(fileName: config.envFile);

  // On iOS Simulator, localhost is 127.0.0.1, but on Android Emulator it is 10.0.2.2.
  // .env.debug usually contains 10.0.2.2. We replace it globally at runtime for iOS.
  if (Platform.isIOS) {
    dotenv.env.forEach((key, value) {
      if (value.contains('10.0.2.2')) {
        dotenv.env[key] = value.replaceAll('10.0.2.2', '127.0.0.1');
      }
    });
  }

  // Initialize Stripe
  Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';

  // Initialize Google Sign-In
  // serverClientId is auto-detected from google-services.json via com.google.gms.google-services plugin
  await GoogleSignIn.instance.initialize();

  // Initialize Supabase
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    throw Exception('SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env');
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
}
