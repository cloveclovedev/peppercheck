// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIsimport "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from '@supabase/supabase-js'
import Stripe from 'stripe'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

export const handler = async (req: Request, dependencies?: {
  stripe?: Stripe
  supabaseAdmin?: ReturnType<typeof createClient>
}) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY') ?? ''
  const stripeWebhookSigningSecret = Deno.env.get('STRIPE_WEBHOOK_SIGNING_SECRET') ?? ''
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

  if (!stripeSecretKey || !stripeWebhookSigningSecret || !supabaseUrl || !supabaseServiceRoleKey) {
    console.error('Missing env vars')
    return new Response('Server config error', { status: 500 })
  }

  const stripe = dependencies?.stripe ?? new Stripe(stripeSecretKey, {
    apiVersion: '2025-11-17.clover',
  })

  const supabaseAdmin = dependencies?.supabaseAdmin ??
    createClient(supabaseUrl, supabaseServiceRoleKey)

  const signature = req.headers.get('Stripe-Signature')
  if (!signature) {
    return new Response('Missing signature', { status: 400 })
  }

  const body = await req.text()
  let event: Stripe.Event
  try {
    event = await stripe.webhooks.constructEventAsync(body, signature, stripeWebhookSigningSecret)
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error'
    console.error(`Webhook signature verification failed: ${message}`)
    return new Response(message, { status: 400 })
  }

  console.log(`Received event: ${event.type}`)

  try {
    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object as Stripe.Checkout.Session
        if (session.mode === 'subscription' && session.subscription) {
          await handleSubscriptionChange(session.subscription as string, stripe, supabaseAdmin)
        }
        break
      }
      case 'customer.subscription.updated':
      case 'customer.subscription.deleted': {
        const subscription = event.data.object as Stripe.Subscription
        await handleSubscriptionChange(subscription.id, stripe, supabaseAdmin)
        break
      }
      default:
        console.log(`Unhandled event type: ${event.type}`)
    }
  } catch (error) {
    console.error(`Error processing event: ${error}`)
    const message = error instanceof Error ? error.message : 'Unknown error'
    return new Response(`Error: ${message}`, { status: 500 })
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

async function handleSubscriptionChange(
  subscriptionId: string,
  stripe: Stripe,
  supabaseAdmin: ReturnType<typeof createClient>,
) {
  // Fetch subscription with expanded price info to get plan_id
  const subscriptionResponse = await stripe.subscriptions.retrieve(subscriptionId, {
    expand: ['items.data.price'],
  })
  const subscription = subscriptionResponse as Stripe.Subscription

  const userId = subscription.metadata.supabase_uid
  if (!userId) {
    console.error(`No supabase_uid in subscription metadata for ${subscriptionId}`)
    return
  }

  const price = subscription.items.data[0].price as Stripe.Price
  const planId = price.metadata?.app_plan_id

  // Fallback if price metadata is missing?
  // If we can't find plan_id, we can't insert into DB as it's NOT NULL.
  // But maybe logging error is enough.
  if (!planId) {
    console.error(`No app_plan_id in price metadata for price ${price.id}`)
    throw new Error('Missing plan mapping')
  }

  const status = subscription.status
  // Use any cast to bypass type definition issues if fields are missing in the referenced version
  const subAny = subscription as any
  const currentPeriodStart = new Date(subAny.current_period_start * 1000).toISOString()
  const currentPeriodEnd = new Date(subAny.current_period_end * 1000).toISOString()
  const cancelAtPeriodEnd = subscription.cancel_at_period_end

  // Upsert into user_subscriptions
  // Note: 'provider' is 'stripe'
  console.log(`Updating subscription for user ${userId}: plan=${planId}, status=${status}`)

  const { error } = await (supabaseAdmin.from('user_subscriptions') as any).upsert({
    user_id: userId,
    plan_id: planId,
    status: status,
    provider: 'stripe',
    stripe_subscription_id: subscription.id,
    current_period_start: currentPeriodStart,
    current_period_end: currentPeriodEnd,
    cancel_at_period_end: cancelAtPeriodEnd,
    updated_at: new Date().toISOString(),
  })

  if (error) {
    console.error('Failed to upsert user_subscription:', error)
    throw error
  }
}

if (import.meta.main) {
  Deno.serve((req) => handler(req))
}

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/handle-stripe-webhook' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/
