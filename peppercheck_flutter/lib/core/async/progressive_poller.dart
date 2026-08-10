import 'dart:async';

/// Progressively spaced retry delays, reused from the IAP entitlement poller:
/// quick at first, then backing off, and bounded — a server-side job either
/// lands within a few seconds or the screen falls back to a manual refresh.
const kDefaultProgressiveSchedule = <Duration>[
  Duration(seconds: 1),
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 2),
  Duration(seconds: 3),
];

/// A one-shot cancellation flag handed to [pollUntil], so an owner that goes
/// away (a disposed provider, a popped screen) can stop the loop.
class CancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

Future<void> _defaultSleep(Duration duration) => Future<void>.delayed(duration);

/// Fetches immediately, then re-fetches after each delay in [schedule] until
/// [isDone] accepts a value, the schedule runs out, or [cancel] is triggered.
/// Returns the last value fetched either way, so a caller that ran out of
/// attempts still sees the freshest state.
///
/// Provider-neutral by design: [sleep] is injectable so tests run without real
/// time, and nothing here touches Riverpod.
Future<T> pollUntil<T>({
  required Future<T> Function() fetch,
  required bool Function(T) isDone,
  List<Duration> schedule = kDefaultProgressiveSchedule,
  CancellationToken? cancel,
  Future<void> Function(Duration) sleep = _defaultSleep,
}) async {
  T value = await fetch();
  if (isDone(value) || (cancel?.isCancelled ?? false)) return value;

  for (final delay in schedule) {
    if (cancel?.isCancelled ?? false) return value;
    await sleep(delay);
    if (cancel?.isCancelled ?? false) return value;
    value = await fetch();
    if (isDone(value)) return value;
  }
  return value;
}
