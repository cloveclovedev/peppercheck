import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:logger/logger.dart';
import 'package:peppercheck_flutter/features/billing/data/stripe_billing_repository.dart';
import 'package:peppercheck_flutter/features/billing/domain/default_billing_method.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'billing_controller.g.dart';

@riverpod
class BillingController extends _$BillingController {
  final _logger = Logger();

  @override
  FutureOr<DefaultBillingMethod?> build() async {
    try {
      return await ref
          .read(stripeBillingRepositoryProvider)
          .fetchDefaultBillingMethod();
    } catch (e, stack) {
      _logger.e(
        'Failed to fetch default billing method',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> setupPaymentMethod() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final repository = ref.read(stripeBillingRepositoryProvider);

        // 1. Get Setup Session from Backend
        final session = await repository.createBillingSetupSession();

        // 2. Initialize Payment Sheet
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            customFlow: false,
            merchantDisplayName: 'Peppercheck',
            customerId: session.customerId,
            setupIntentClientSecret: session.setupIntentClientSecret,
            customerEphemeralKeySecret: session.ephemeralKeySecret,
            style: ThemeMode.system,
          ),
        );

        // 3. Present Payment Sheet
        await Stripe.instance.presentPaymentSheet();

        // 4. Refresh Default Payment Method
        return repository.fetchDefaultBillingMethod();
      } catch (e, stack) {
        _logger.e(
          'Failed to setup payment method',
          error: e,
          stackTrace: stack,
        );
        rethrow;
      }
    });
  }
}
