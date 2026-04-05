import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/features/billing/domain/subscription.dart';
import 'package:peppercheck_flutter/features/billing/domain/subscription_display_state.dart';

void main() {
  group('SubscriptionDisplayState.fromSubscription', () {
    test('returns NotSubscribed when subscription is null', () {
      final state = SubscriptionDisplayState.fromSubscription(null);
      expect(state, isA<NotSubscribed>());
    });

    test('returns NotSubscribed when status is canceled', () {
      final sub = Subscription(
        status: 'canceled',
        planId: 'light',
        currentPeriodEnd: '2026-04-01T00:00:00Z',
      );
      final state = SubscriptionDisplayState.fromSubscription(sub);
      expect(state, isA<NotSubscribed>());
    });

    test('returns NotSubscribed when status is incomplete', () {
      final sub = Subscription(status: 'incomplete', planId: 'light');
      final state = SubscriptionDisplayState.fromSubscription(sub);
      expect(state, isA<NotSubscribed>());
    });

    test('returns NotSubscribed when status is incomplete_expired', () {
      final sub = Subscription(status: 'incomplete_expired', planId: 'light');
      final state = SubscriptionDisplayState.fromSubscription(sub);
      expect(state, isA<NotSubscribed>());
    });

    test('returns NotSubscribedWithPaymentIssue when status is unpaid', () {
      final sub = Subscription(status: 'unpaid', planId: 'standard');
      final state = SubscriptionDisplayState.fromSubscription(sub);
      expect(state, isA<NotSubscribedWithPaymentIssue>());
    });

    test('returns ActiveSubscription when status is active', () {
      final sub = Subscription(
        status: 'active',
        planId: 'light',
        currentPeriodEnd: '2026-05-01T00:00:00Z',
        cancelAtPeriodEnd: false,
      );
      final state = SubscriptionDisplayState.fromSubscription(sub);
      expect(state, isA<ActiveSubscription>());
      final active = state as ActiveSubscription;
      expect(active.planId, 'light');
      expect(active.periodEnd, DateTime.parse('2026-05-01T00:00:00Z'));
      expect(active.cancelAtPeriodEnd, false);
    });

    test('returns ActiveSubscription with cancelAtPeriodEnd=true', () {
      final sub = Subscription(
        status: 'active',
        planId: 'premium',
        currentPeriodEnd: '2026-05-01T00:00:00Z',
        cancelAtPeriodEnd: true,
      );
      final state = SubscriptionDisplayState.fromSubscription(sub);
      expect(state, isA<ActiveSubscription>());
      final active = state as ActiveSubscription;
      expect(active.planId, 'premium');
      expect(active.cancelAtPeriodEnd, true);
    });

    test('returns ActiveWithPaymentIssue when status is past_due', () {
      final sub = Subscription(
        status: 'past_due',
        planId: 'standard',
        currentPeriodEnd: '2026-05-01T00:00:00Z',
      );
      final state = SubscriptionDisplayState.fromSubscription(sub);
      expect(state, isA<ActiveWithPaymentIssue>());
      final active = state as ActiveWithPaymentIssue;
      expect(active.planId, 'standard');
      expect(active.periodEnd, DateTime.parse('2026-05-01T00:00:00Z'));
    });

    test('returns ActiveSubscription for trialing (future-proofing)', () {
      final sub = Subscription(
        status: 'trialing',
        planId: 'light',
        currentPeriodEnd: '2026-05-01T00:00:00Z',
      );
      final state = SubscriptionDisplayState.fromSubscription(sub);
      expect(state, isA<ActiveSubscription>());
    });

    test('returns ActiveSubscription for paused (future-proofing)', () {
      final sub = Subscription(
        status: 'paused',
        planId: 'light',
        currentPeriodEnd: '2026-05-01T00:00:00Z',
      );
      final state = SubscriptionDisplayState.fromSubscription(sub);
      expect(state, isA<ActiveSubscription>());
    });

    test('defaults cancelAtPeriodEnd to false when null', () {
      final sub = Subscription(
        status: 'active',
        planId: 'light',
        currentPeriodEnd: '2026-05-01T00:00:00Z',
        cancelAtPeriodEnd: null,
      );
      final state = SubscriptionDisplayState.fromSubscription(sub);
      final active = state as ActiveSubscription;
      expect(active.cancelAtPeriodEnd, false);
    });
  });
}
