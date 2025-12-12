import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from '@supabase/supabase-js'
import Stripe from 'stripe'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

export const handler = async (req: Request, dependencies?: {
  stripe?: Stripe
  supabase?: ReturnType<typeof createClient>
  supabaseAdmin?: ReturnType<typeof createClient>
}) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('Missing authorization header')
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY') ?? ''

    if (!stripeSecretKey || !supabaseUrl || !supabaseServiceRoleKey) {
      console.error('Missing env vars (SUPABASE_URL, SERVICE_ROLE, STRIPE_SECRET)')
      throw new Error('Server configuration error')
    }

    // 1. Authenticate User
    const supabase = dependencies?.supabase ??
      createClient(supabaseUrl, supabaseAnonKey, {
        global: { headers: { Authorization: authHeader } },
      }) as any

    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 2. Resolve Stripe Customer (Use Service Role)
    const supabaseAdmin = dependencies?.supabaseAdmin ??
      createClient(supabaseUrl, supabaseServiceRoleKey)
    const stripe = dependencies?.stripe ?? new Stripe(stripeSecretKey, {
      apiVersion: '2025-11-17.clover',
    })

    let { data: stripeAccount } = await (supabaseAdmin
      .from('stripe_accounts') as any)
      .select('stripe_customer_id')
      .eq('profile_id', user.id)
      .maybeSingle()

    // If no account record or no customer_id, create/update
    if (!stripeAccount?.stripe_customer_id) {
      console.log(`Creating Stripe Customer for user ${user.id}`)
      const customer = await stripe.customers.create({
        email: user.email,
        metadata: { supabase_uid: user.id },
      })

      // Upsert into stripe_accounts
      const { error: upsertError } = await (supabaseAdmin
        .from('stripe_accounts') as any)
        .upsert(
          {
            profile_id: user.id,
            stripe_customer_id: customer.id,
          },
          { onConflict: 'profile_id' },
        )

      if (upsertError) {
        console.error('Failed to save stripe_customer_id:', upsertError)
        throw new Error('Database error saving customer info')
      }
      stripeAccount = {
        stripe_customer_id: customer.id,
      }
    }

    const customerId = stripeAccount.stripe_customer_id

    // 3. Resolve Price ID
    const { price_id, plan_id, currency, success_url, cancel_url, mode = 'subscription' } =
      await req.json()

    if (!success_url || !cancel_url) {
      return new Response(JSON.stringify({ error: 'Missing success_url or cancel_url' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    let finalPriceId = price_id
    if (!finalPriceId) {
      if (!plan_id || !currency) {
        return new Response(
          JSON.stringify({ error: 'Must provide price_id OR (plan_id and currency)' }),
          {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          },
        )
      }

      // Lookup by key
      const lookupKey = `${plan_id}_${currency}_stripe`
      console.log(`Looking up price for key: ${lookupKey}`)
      const prices = await stripe.prices.list({
        lookup_keys: [lookupKey],
        limit: 1,
        active: true,
      })

      if (prices.data.length === 0) {
        return new Response(
          JSON.stringify({ error: `Price not found for plan: ${plan_id} (${currency})` }),
          {
            status: 404,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          },
        )
      }
      finalPriceId = prices.data[0].id
    }

    // 4. Create Checkout Session
    console.log(
      `Creating Checkout Session: customer=${customerId}, price=${finalPriceId}, mode=${mode}`,
    )

    // Additional params based on mode
    const subscriptionData = mode === 'subscription'
      ? {
        metadata: { supabase_uid: user.id },
      }
      : undefined

    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      line_items: [
        {
          price: finalPriceId,
          quantity: 1,
        },
      ],
      mode: mode,
      success_url: success_url,
      cancel_url: cancel_url,
      // allow_promotion_codes: true, // Optional but good
      metadata: {
        supabase_uid: user.id, // Metadata on Session
        plan_id: plan_id || null, // Useful for webhook tracking
      },
      subscription_data: subscriptionData,
    })

    return new Response(
      JSON.stringify({ url: session.url }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    )
  } catch (error) {
    console.error('Error in create-stripe-checkout:', error)
    const message = error instanceof Error ? error.message : 'Unknown error'
    return new Response(
      JSON.stringify({ error: message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    )
  }
}

if (import.meta.main) {
  Deno.serve((req) => handler(req))
}
