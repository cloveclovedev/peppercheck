import 'dart:async';

import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:peppercheck_flutter/features/profile/data/profile_repository.dart';
import 'package:peppercheck_flutter/features/profile/presentation/providers/current_profile_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'timezone_controller.g.dart';

@Riverpod(keepAlive: true)
class TimezoneController extends _$TimezoneController {
  @override
  FutureOr<void> build() async {
    // Watch the current profile to trigger check when profile loads or changes
    final profileAsync = ref.watch(currentProfileProvider);

    // If profile is loading or error, or null (not logged in), do nothing
    if (profileAsync is! AsyncData || profileAsync.value == null) {
      return;
    }

    final profile = profileAsync.value!;

    await _checkAndUpdateTimezone(profile.id, profile.timezone);
  }

  Future<void> _checkAndUpdateTimezone(
    String userId,
    String? dbTimezone,
  ) async {
    try {
      final String deviceTimezone = await FlutterTimezone.getLocalTimezone();

      if (deviceTimezone != dbTimezone) {
        ref
            .read(loggerProvider)
            .i(
              'Timezone mismatch. Device: $deviceTimezone, DB: $dbTimezone. Updating...',
            );
        await ref
            .read(profileRepositoryProvider)
            .updateTimezone(userId, deviceTimezone);

        // Invalidate profile provider to fetch fresh data
        ref.invalidate(currentProfileProvider);
      }
    } catch (e, st) {
      ref
          .read(loggerProvider)
          .e('Failed to check/update timezone', error: e, stackTrace: st);
    }
  }
}
