import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/common_widgets/app_background.dart';
import 'package:peppercheck_flutter/common_widgets/app_scaffold.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class PaymentDashboardScreen extends ConsumerWidget {
  const PaymentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBackground(
      child: AppScaffold(
        title: t.nav.payments,
        currentIndex: 1, // Payments is index 1
        body: const SafeArea(child: Center(child: Text('Payment Dashboard'))),
      ),
    );
  }
}
