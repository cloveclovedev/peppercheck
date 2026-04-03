import 'package:peppercheck_flutter/features/billing/domain/subscription.dart';

sealed class SubscriptionDisplayState {
  const SubscriptionDisplayState();

  factory SubscriptionDisplayState.fromSubscription(
    Subscription? subscription,
  ) {
    if (subscription == null) {
      return const NotSubscribed();
    }

    return switch (subscription.status) {
      'active' || 'trialing' || 'paused' => ActiveSubscription(
        planId: subscription.planId ?? '',
        periodEnd: _parsePeriodEnd(subscription.currentPeriodEnd),
        cancelAtPeriodEnd: subscription.cancelAtPeriodEnd ?? false,
      ),
      'past_due' => ActiveWithPaymentIssue(
        planId: subscription.planId ?? '',
        periodEnd: _parsePeriodEnd(subscription.currentPeriodEnd),
      ),
      'unpaid' => const NotSubscribedWithPaymentIssue(),
      _ =>
        const NotSubscribed(), // canceled, incomplete, incomplete_expired, unknown
    };
  }

  static DateTime _parsePeriodEnd(String? periodEnd) {
    if (periodEnd == null) {
      throw StateError(
        'currentPeriodEnd must not be null for active subscriptions',
      );
    }
    return DateTime.parse(periodEnd);
  }
}

class NotSubscribed extends SubscriptionDisplayState {
  const NotSubscribed();
}

class NotSubscribedWithPaymentIssue extends SubscriptionDisplayState {
  const NotSubscribedWithPaymentIssue();
}

class ActiveSubscription extends SubscriptionDisplayState {
  final String planId;
  final DateTime periodEnd;
  final bool cancelAtPeriodEnd;

  const ActiveSubscription({
    required this.planId,
    required this.periodEnd,
    required this.cancelAtPeriodEnd,
  });
}

class ActiveWithPaymentIssue extends SubscriptionDisplayState {
  final String planId;
  final DateTime periodEnd;

  const ActiveWithPaymentIssue({required this.planId, required this.periodEnd});
}
