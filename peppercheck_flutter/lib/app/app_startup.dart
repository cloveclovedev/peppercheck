import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

Future<void> appStartup() async {
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.useDeviceLocale();
  // Future: Add other initialization logic here (e.g., Supabase, Stripe, Logger)
}
