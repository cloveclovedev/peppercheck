// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'poll_sleep_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The delay function [pollUntil] callers use, exposed as a provider purely so
/// widget and notifier tests can override it with a no-op and run the poll
/// without real time passing.

@ProviderFor(pollSleep)
const pollSleepProvider = PollSleepProvider._();

/// The delay function [pollUntil] callers use, exposed as a provider purely so
/// widget and notifier tests can override it with a no-op and run the poll
/// without real time passing.

final class PollSleepProvider
    extends
        $FunctionalProvider<
          Future<void> Function(Duration),
          Future<void> Function(Duration),
          Future<void> Function(Duration)
        >
    with $Provider<Future<void> Function(Duration)> {
  /// The delay function [pollUntil] callers use, exposed as a provider purely so
  /// widget and notifier tests can override it with a no-op and run the poll
  /// without real time passing.
  const PollSleepProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pollSleepProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pollSleepHash();

  @$internal
  @override
  $ProviderElement<Future<void> Function(Duration)> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Future<void> Function(Duration) create(Ref ref) {
    return pollSleep(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Future<void> Function(Duration) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Future<void> Function(Duration)>(
        value,
      ),
    );
  }
}

String _$pollSleepHash() => r'77dfac072a5430379d582745f7e88794b4711d5c';
