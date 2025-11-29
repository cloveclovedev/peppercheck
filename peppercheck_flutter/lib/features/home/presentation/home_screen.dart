import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t.home.title)),
      body: Center(child: Text(t.home.title)),
    );
  }
}
