// Apple productId is '{planId}_monthly'; DB plan_id is '{planId}'.
// Mirrors handle-google-play-rtdn extractPlanId.
export function extractPlanId(productId: string): string {
  return productId.replace('_monthly', '')
}

// Maps Apple ASSN V2 notificationType (and subtype, when relevant) to the
// public.subscription_status enum. Returns null when status is not the right
// thing to update for this notification (DID_CHANGE_RENEWAL_STATUS toggles
// cancel_at_period_end only; TEST / PRICE_INCREASE are log-only;
// DID_CHANGE_RENEWAL_PREF carries a plan change but preserves status).
export function mapNotificationToStatus(
  notificationType: string,
  _subtype: string | undefined,
): string | null {
  switch (notificationType) {
    case 'SUBSCRIBED':
    case 'DID_RENEW':
      return 'active'
    case 'DID_FAIL_TO_RENEW':
      return 'past_due'
    case 'EXPIRED':
    case 'GRACE_PERIOD_EXPIRED':
    case 'REFUND':
    case 'REVOKE':
      return 'canceled'
    default:
      return null
  }
}
