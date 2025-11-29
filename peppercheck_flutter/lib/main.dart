import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/app.dart';
import 'package:peppercheck_flutter/app/app_startup.dart';

void main() async {
  await appStartup();
  runApp(const ProviderScope(child: MyApp()));
}
