import { assert, assertEquals } from '@std/assert'
import { assertSpyCall, assertSpyCalls, spy } from '@std/testing/mock'
import { handler } from './index.ts'

// Helpers
function createMockStripeClient() {
  return {
    webhooks: {
      constructEventAsync: spy(() =>
        Promise.resolve({
          type: 'checkout.session.completed',
          data: { object: { mode: 'subscription', subscription: 'sub_123' } },
        })
      ),
    },
    subscriptions: {
      retrieve: spy(() =>
        Promise.resolve({
          id: 'sub_123',
          metadata: { supabase_uid: 'user_123' },
          items: { data: [{ price: { id: 'price_123', metadata: { app_plan_id: 'premium' } } }] },
          status: 'active',
          current_period_start: 1700000000,
          current_period_end: 1702592000,
          cancel_at_period_end: false,
        })
      ),
    },
  } as any
}

function createMockSupabaseAdmin() {
  return {
    from: (table: string) => ({
      upsert: spy(() => Promise.resolve({ error: null })),
    }),
  } as any
}

function setupEnv() {
  Deno.env.set('STRIPE_SECRET_KEY', 'sk_test')
  Deno.env.set('STRIPE_WEBHOOK_SIGNING_SECRET', 'whsec_test')
  Deno.env.set('SUPABASE_URL', 'http://localhost')
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'service_key')
}

Deno.test('handle-stripe-webhook: missing signature returns 400', async () => {
  setupEnv()
  const req = new Request('http://localhost', { method: 'POST' })

  // Pass mocks to avoid instantiating real clients which might cause leaks
  const mockStripe = {} as any
  const mockSupabase = {} as any

  const res = await handler(req, { stripe: mockStripe, supabaseAdmin: mockSupabase })
  assertEquals(res.status, 400)
  assertEquals(await res.text(), 'Missing signature')
})

Deno.test('handle-stripe-webhook: successful checkout session', async () => {
  setupEnv()
  const req = new Request('http://localhost', {
    method: 'POST',
    headers: { 'Stripe-Signature': 't=123,v1=sig' },
    body: JSON.stringify({}), // Body doesn't matter as mock constructEvent ignores it
  })

  const mockStripe = createMockStripeClient()
  const mockSupabaseWithSpy = createMockSupabaseAdmin()
  // Re-assign spy to strict variable to assert it
  const upsertSpy = mockSupabaseWithSpy.from('user_subscriptions').upsert
  // Note: mockSupabaseAdmin.from() returns a NEW object every time in my simple mock above?
  // Yes. So I need to structure the mock differently to capture the spy.

  // Improved mock structure for this test
  const upsertSpyFixed = spy(() => Promise.resolve({ error: null }))
  const mockSupabaseFixed = {
    from: () => ({ upsert: upsertSpyFixed }),
  } as any

  const res = await handler(req, { stripe: mockStripe, supabaseAdmin: mockSupabaseFixed })
  assertEquals(res.status, 200)

  // Verify Stripe retrieval
  assertSpyCalls(mockStripe.subscriptions.retrieve, 1)
  assertEquals(mockStripe.subscriptions.retrieve.calls[0].args[0], 'sub_123')

  // Verify DB upsert
  assertSpyCalls(upsertSpyFixed, 1)
})

Deno.test('handle-stripe-webhook: updates subscription on customer.subscription.updated', async () => {
  setupEnv()
  const req = new Request('http://localhost', {
    method: 'POST',
    headers: { 'Stripe-Signature': 't=123,v1=sig' },
    body: 'dummy',
  })

  const mockStripe = createMockStripeClient()
  // Override event type
  mockStripe.webhooks.constructEventAsync = spy(() =>
    Promise.resolve({
      type: 'customer.subscription.updated',
      data: { object: { id: 'sub_123' } }, // data.object IS the subscription for this event
      // Note: The handler casts data.object to Subscription immediatley.
    })
  )

  const upsertSpy = spy(() => Promise.resolve({ error: null }))
  const mockSupabase = {
    from: () => ({ upsert: upsertSpy }),
  } as any

  const res = await handler(req, { stripe: mockStripe, supabaseAdmin: mockSupabase })
  assertEquals(res.status, 200)

  assertSpyCalls(upsertSpy, 1)
  const arg = (upsertSpy.calls[0] as any).args[0]
  assertEquals(arg.user_id, 'user_123')
  assertEquals(arg.plan_id, 'premium')
  assertEquals(arg.status, 'active')
})
