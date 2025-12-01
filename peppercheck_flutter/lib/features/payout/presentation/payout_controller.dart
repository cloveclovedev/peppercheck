import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:peppercheck_flutter/features/payout/data/stripe_payout_repository.dart';
import 'package:peppercheck_flutter/features/payout/domain/payout_setup_status.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

part 'payout_controller.g.dart';

@riverpod
class PayoutController extends _$PayoutController {
  final _logger = Logger();
  AppLifecycleListener? _listener;

  @override
  FutureOr<PayoutSetupStatus> build() async {
    // Register AppLifecycleListener to refresh state when app resumes
    _listener = AppLifecycleListener(
      onResume: () {
        _logger.d('App resumed, refreshing payout setup status');
        ref.invalidateSelf();
      },
    );

    // Dispose listener when provider is disposed
    ref.onDispose(() {
      _listener?.dispose();
    });

    try {
      return await ref
          .read(stripePayoutRepositoryProvider)
          .fetchPayoutSetupStatus();
    } catch (e, stack) {
      _logger.e(
        'Failed to fetch payout setup status',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> setupPayout() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final url = await ref
            .read(stripePayoutRepositoryProvider)
            .createPayoutSetupSession();

        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Could not launch $url');
        }

        // Return current state, actual refresh happens on resume
        return state.value ?? const PayoutSetupStatus();
      } catch (e, stack) {
        _logger.e('Failed to setup payout', error: e, stackTrace: stack);
        rethrow;
      }
    });
  }
}
