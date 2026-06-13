import { assertEquals } from '@std/assert'
import { extractPlanId, mapNotificationToStatus } from './helpers.ts'

Deno.test('extractPlanId strips _monthly suffix', () => {
  assertEquals(extractPlanId('light_monthly'), 'light')
  assertEquals(extractPlanId('standard_monthly'), 'standard')
  assertEquals(extractPlanId('premium_monthly'), 'premium')
})

Deno.test('extractPlanId is a no-op when suffix is absent', () => {
  assertEquals(extractPlanId('light'), 'light')
})

Deno.test('mapNotificationToStatus: SUBSCRIBED → active', () => {
  assertEquals(mapNotificationToStatus('SUBSCRIBED', 'INITIAL_BUY'), 'active')
  assertEquals(mapNotificationToStatus('SUBSCRIBED', 'RESUBSCRIBE'), 'active')
})

Deno.test('mapNotificationToStatus: DID_RENEW → active (with or without subtype)', () => {
  assertEquals(mapNotificationToStatus('DID_RENEW', undefined), 'active')
  assertEquals(mapNotificationToStatus('DID_RENEW', 'BILLING_RECOVERY'), 'active')
})

Deno.test('mapNotificationToStatus: DID_FAIL_TO_RENEW → past_due (with or without GRACE_PERIOD)', () => {
  assertEquals(mapNotificationToStatus('DID_FAIL_TO_RENEW', 'GRACE_PERIOD'), 'past_due')
  assertEquals(mapNotificationToStatus('DID_FAIL_TO_RENEW', undefined), 'past_due')
})

Deno.test('mapNotificationToStatus: terminal types → canceled', () => {
  assertEquals(mapNotificationToStatus('EXPIRED', undefined), 'canceled')
  assertEquals(mapNotificationToStatus('GRACE_PERIOD_EXPIRED', undefined), 'canceled')
  assertEquals(mapNotificationToStatus('REFUND', undefined), 'canceled')
  assertEquals(mapNotificationToStatus('REVOKE', undefined), 'canceled')
})

Deno.test('mapNotificationToStatus: types handled separately return null', () => {
  assertEquals(mapNotificationToStatus('TEST', undefined), null)
  assertEquals(mapNotificationToStatus('PRICE_INCREASE', undefined), null)
  assertEquals(mapNotificationToStatus('DID_CHANGE_RENEWAL_STATUS', 'AUTO_RENEW_DISABLED'), null)
  assertEquals(mapNotificationToStatus('DID_CHANGE_RENEWAL_STATUS', 'AUTO_RENEW_ENABLED'), null)
  assertEquals(mapNotificationToStatus('DID_CHANGE_RENEWAL_PREF', undefined), null)
})
