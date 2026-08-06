import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/core/async/progressive_poller.dart';

void main() {
  test('returns as soon as isDone accepts a value', () async {
    var calls = 0;
    final result = await pollUntil<int>(
      fetch: () async {
        calls++;
        return calls;
      },
      isDone: (v) => v >= 3,
      schedule: const [Duration.zero, Duration.zero, Duration.zero],
      sleep: (_) async {},
    );

    expect(result, 3);
    expect(calls, 3);
  });

  test('does not sleep at all when the first fetch is already done', () async {
    final slept = <Duration>[];
    final result = await pollUntil<int>(
      fetch: () async => 1,
      isDone: (_) => true,
      schedule: const [Duration(seconds: 1)],
      sleep: (d) async => slept.add(d),
    );

    expect(result, 1);
    expect(slept, isEmpty);
  });

  test(
    'stops after the schedule is exhausted and returns the last value',
    () async {
      var calls = 0;
      final result = await pollUntil<int>(
        fetch: () async {
          calls++;
          return calls;
        },
        isDone: (_) => false,
        schedule: const [Duration.zero, Duration.zero],
        sleep: (_) async {},
      );

      // One immediate fetch plus one per scheduled delay.
      expect(calls, 3);
      expect(result, 3);
    },
  );

  test('follows the schedule delays in order', () async {
    final slept = <Duration>[];
    await pollUntil<int>(
      fetch: () async => 0,
      isDone: (_) => false,
      schedule: const [Duration(seconds: 1), Duration(seconds: 2)],
      sleep: (d) async => slept.add(d),
    );

    expect(slept, const [Duration(seconds: 1), Duration(seconds: 2)]);
  });

  test('cancellation stops further polling', () async {
    final token = CancellationToken();
    var calls = 0;
    final result = await pollUntil<int>(
      fetch: () async {
        calls++;
        if (calls == 2) token.cancel();
        return calls;
      },
      isDone: (_) => false,
      schedule: const [Duration.zero, Duration.zero, Duration.zero],
      cancel: token,
      sleep: (_) async {},
    );

    expect(calls, 2);
    expect(result, 2);
  });

  test('a token cancelled while sleeping skips the next fetch', () async {
    final token = CancellationToken();
    var calls = 0;
    await pollUntil<int>(
      fetch: () async {
        calls++;
        return calls;
      },
      isDone: (_) => false,
      schedule: const [Duration.zero, Duration.zero],
      cancel: token,
      sleep: (_) async => token.cancel(),
    );

    expect(calls, 1);
  });

  test('the default schedule is the progressive one', () {
    expect(kDefaultProgressiveSchedule, const [
      Duration(seconds: 1),
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 2),
      Duration(seconds: 3),
    ]);
  });
}
