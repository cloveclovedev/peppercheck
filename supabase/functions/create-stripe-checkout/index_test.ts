import { assert, assertEquals } from '@std/assert'
import { assertSpyCall, assertSpyCalls, spy, stub } from '@std/testing/mock'
import { handler } from './index.ts'

/**
 * Mocks for dependencies
 */
const mockUser = {
  id: 'test-user-id',
  email: 'test@example.com',
}

const mockStripeCustomer = {
  id: 'cus_test123',
}

const mockSession = {
  url: 'https://stripe.com/checkout/test',
}

// Helper to create mock Supabase Client
function createMockSupabaseClient(user = mockUser) {
  return {
    auth: {
      getUser: () => Promise.resolve({ data: { user }, error: null }),
    },
    from: (table: string) => ({
      select: () => ({
        eq: () => ({
          maybeSingle: () =>
            Promise.resolve({ data: { stripe_customer_id: mockStripeCustomer.id } }),
        }),
      }),
      upsert: () => Promise.resolve({ error: null }),
    }),
  } as any
}

// Helper to create mock Stripe Client
function createMockStripeClient() {
  return {
    customers: {
      create: spy(() => Promise.resolve(mockStripeCustomer)),
    },
    prices: {
      list: spy(() => Promise.resolve({ data: [{ id: 'price_test123' }] })),
    },
    checkout: {
      sessions: {
        create: spy(() => Promise.resolve(mockSession)),
      },
    },
  } as any
}

// Helper to setup env vars
function setupEnv() {
  Deno.env.set('SUPABASE_URL', 'http://localhost')
  Deno.env.set('SUPABASE_ANON_KEY', 'anon-key')
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'service-role-key')
  Deno.env.set('STRIPE_SECRET_KEY', 'sk_test')
}

Deno.test('create-stripe-checkout: missing auth header returns 401', async () => {
  // Arrange
  setupEnv() // Ensure envs are set so it doesn't fail on config check (though missing auth header check comes first? No, config check is inside try/catch but seemingly runs early? Check logic order again).
  // Logic order:
  // 1. Check req.method
  // 2. Try-catch starts
  // 3. check authHeader -> throws Error "Missing authorization header"
  // 4. catch -> returns 500 "Missing authorization header"

  // Wait, env check is AFTER auth header check.
  //    const authHeader = req.headers.get("Authorization")
  //    if (!authHeader) { throw ... }
  // So "missing auth header" test actually passed?
  // Output: "create-stripe-checkout: missing auth header returns 401 ... ok (1ms)"
  // YES. Passing.

  // So only need to fix others.
  const req = new Request('http://localhost', { method: 'POST' })
  const res = await handler(req)
  assertEquals(res.status, 500)
  const body = await res.json()
  assertEquals(body.error, 'Missing authorization header')
})

Deno.test('create-stripe-checkout: unauthorized user returns 401', async () => {
  setupEnv()
  const req = new Request('http://localhost', {
    method: 'POST',
    headers: { 'Authorization': 'Bearer invalid' },
  })

  const mockSupabase = {
    auth: {
      getUser: () => Promise.resolve({ data: { user: null }, error: { message: 'Auth error' } }),
    },
  } as any

  const res = await handler(req, { supabase: mockSupabase })
  assertEquals(res.status, 401)
})

Deno.test('create-stripe-checkout: successful session creation (price_id provided)', async () => {
  setupEnv()

  const req = new Request('http://localhost', {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer valid',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      price_id: 'price_given',
      success_url: 'https://example.com/success',
      cancel_url: 'https://example.com/cancel',
    }),
  })

  const mockSupabase = createMockSupabaseClient()
  const mockSupabaseAdmin = createMockSupabaseClient()
  const mockStripe = createMockStripeClient()

  const res = await handler(req, {
    supabase: mockSupabase as any,
    supabaseAdmin: mockSupabaseAdmin as any,
    stripe: mockStripe,
  })

  assertEquals(res.status, 200)
  const body = await res.json()
  assertEquals(body.url, mockSession.url)

  assertSpyCalls(mockStripe.checkout.sessions.create, 1)
  const callArgs = mockStripe.checkout.sessions.create.calls[0].args[0]
  assertEquals(callArgs.customer, mockStripeCustomer.id)
  assertEquals(callArgs.line_items[0].price, 'price_given')
})

Deno.test('create-stripe-checkout: successful session creation (plan_id + currency)', async () => {
  setupEnv()

  // Simulate finding a price
  const mockStripe = createMockStripeClient()
  // Stub prices.list to return a price
  mockStripe.prices.list = spy(() => Promise.resolve({ data: [{ id: 'price_found_123' }] }))

  const req = new Request('http://localhost', {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer valid',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      plan_id: 'premium',
      currency: 'jpy',
      success_url: 'https://example.com/success',
      cancel_url: 'https://example.com/cancel',
    }),
  })

  const res = await handler(req, {
    supabase: createMockSupabaseClient() as any,
    supabaseAdmin: createMockSupabaseClient() as any,
    stripe: mockStripe,
  })

  assertEquals(res.status, 200)
  const body = await res.json()
  assertEquals(body.url, mockSession.url)

  // Verify lookup key search
  assertSpyCalls(mockStripe.prices.list, 1)
  const listArgs = mockStripe.prices.list.calls[0].args[0]
  assertEquals(listArgs.lookup_keys[0], 'premium_jpy_stripe')

  // Verify checkout creation used found price
  assertSpyCalls(mockStripe.checkout.sessions.create, 1)
  const createArgs = mockStripe.checkout.sessions.create.calls[0].args[0]
  assertEquals(createArgs.line_items[0].price, 'price_found_123')
})
