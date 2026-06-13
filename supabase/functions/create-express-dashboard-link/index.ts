// supabase/functions/create-express-dashboard-link/index.ts
import 'jsr:@supabase/functions-js@^2/edge-runtime.d.ts'

import { createClient } from '@supabase/supabase-js'
import Stripe from 'stripe'

const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY') ?? ''
const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

if (!stripeSecretKey) {
  console.warn('STRIPE_SECRET_KEY is not set.')
}
if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
  console.warn('Supabase environment variables are missing.')
}

const stripe = new Stripe(stripeSecretKey, {
  apiVersion: '2025-11-17.clover',
})

const jsonHeaders = { 'Content-Type': 'application/json' }

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { status: 405, headers: jsonHeaders },
    )
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: 'Missing authorization header' }),
      { status: 401, headers: jsonHeaders },
    )
  }

  try {
    const supabaseAuthClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: { Authorization: authHeader },
      },
    })
    const {
      data: { user },
      error: authError,
    } = await supabaseAuthClient.auth.getUser()

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: jsonHeaders },
      )
    }

    const serviceClient = createClient(supabaseUrl, supabaseServiceRoleKey)

    const { data: stripeAccount, error: lookupError } = await serviceClient
      .from('stripe_accounts')
      .select('stripe_connect_account_id')
      .eq('profile_id', user.id)
      .maybeSingle()

    if (lookupError) {
      console.error('Failed to look up stripe_accounts row', lookupError)
      return new Response(
        JSON.stringify({ error: 'Internal server error' }),
        { status: 500, headers: jsonHeaders },
      )
    }

    const connectAccountId = stripeAccount?.stripe_connect_account_id as
      | string
      | null
      | undefined
    if (!connectAccountId) {
      return new Response(
        JSON.stringify({ error: 'Connect account not set up' }),
        { status: 404, headers: jsonHeaders },
      )
    }

    const loginLink = await stripe.accounts.createLoginLink(connectAccountId)

    return new Response(
      JSON.stringify({ url: loginLink.url }),
      { headers: jsonHeaders },
    )
  } catch (error) {
    console.error('Failed to create Stripe Express dashboard link', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: jsonHeaders },
    )
  }
})
