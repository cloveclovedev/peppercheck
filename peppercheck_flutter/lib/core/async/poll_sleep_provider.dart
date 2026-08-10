import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'poll_sleep_provider.g.dart';

/// The delay function [pollUntil] callers use, exposed as a provider purely so
/// widget and notifier tests can override it with a no-op and run the poll
/// without real time passing.
@Riverpod(keepAlive: true)
Future<void> Function(Duration) pollSleep(Ref ref) =>
    (duration) => Future<void>.delayed(duration);
