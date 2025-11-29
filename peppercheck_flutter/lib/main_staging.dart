import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/app.dart';
import 'package:peppercheck_flutter/app/app_startup.dart';
import 'package:peppercheck_flutter/app/config/app_environment.dart';

void main() async {
  await appStartup(AppConfig.staging);
  runApp(const ProviderScope(child: MyApp()));
}
