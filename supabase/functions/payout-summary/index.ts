// Setup type definitions for built-in Supabase Runtime APIs
import '@supabase/functions-js/edge-runtime.d.ts'

import { createClient } from '@supabase/supabase-js'
import Stripe from 'stripe'

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY') ?? ''
const stripeApiVersion = '2025-10-29.clover'

if (!supabaseUrl) console.warn('Missing SUPABASE_URL')
if (!supabaseServiceRoleKey) console.warn('Missing SUPABASE_SERVICE_ROLE_KEY')
if (!stripeSecretKey) console.warn('Missing STRIPE_SECRET_KEY')

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)
const stripe = new Stripe(stripeSecretKey, { apiVersion: stripeApiVersion })

const jsonHeaders = { 'Content-Type': 'application/json' }

type PayoutSummary = {
  available_minor: number
  pending_minor: number
  incoming_pending_minor: number
  currency_code: string
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: allowHeaders() })
  }

  if (req.method !== 'GET') {
    return jsonResponse({ error: 'Method not allowed' }, 405)
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return jsonResponse({ error: 'Unauthorized' }, 401)
  }

  let userId: string
  try {
    const { data, error } = await supabase.auth.getUser(authHeader.replace('Bearer ', ''))
    if (error || !data.user) {
      return jsonResponse({ error: 'Unauthorized' }, 401)
    }
    userId = data.user.id
  } catch (error) {
    console.error('Failed to validate auth token', error)
    return jsonResponse({ error: 'Unauthorized' }, 401)
  }

  // Sum pending/processing payouts
  const { data: pendingRows, error: pendingError } = await supabase
    .from('payout_jobs')
    .select('amount_minor')
    .eq('user_id', userId)
    .in('status', ['pending', 'processing'])

  if (pendingError) {
    console.error('Failed to fetch pending payout_jobs', pendingError)
    return jsonResponse({ error: 'Failed to fetch payout summary' }, 500)
  }

  const pendingMinor = pendingRows?.reduce((sum, row) => sum + (row.amount_minor ?? 0), 0) ?? 0

  // Fetch available balance from Stripe connected account
  const { data: account, error: accountError } = await supabase
    .from('stripe_accounts')
    .select('stripe_connect_account_id')
    .eq('profile_id', userId)
    .maybeSingle()

  if (accountError) {
    console.error('Failed to fetch stripe_accounts', accountError)
    return jsonResponse({ error: 'Failed to fetch payout summary' }, 500)
  }

  let availableMinor = 0
  let incomingPendingMinor = 0
  let currencyCode = 'JPY'

  if (account?.stripe_connect_account_id && stripeSecretKey) {
    try {
      const balance = await stripe.balance.retrieve({
        stripeAccount: account.stripe_connect_account_id,
      })
      const currency = currencyCode.toLowerCase()
      const available = balance.available.find((b) => b.currency === currency)
      const pending = balance.pending.find((b) => b.currency === currency)
      availableMinor = available?.amount ?? 0
      incomingPendingMinor = pending?.amount ?? 0
      // optional: include pending from Stripe as well; we keep DB pending as separate field
      currencyCode = (available?.currency ?? currencyCode).toUpperCase()
      // if no available entry but pending exists, keep currency from pending
      if (!available && pending) {
        currencyCode = pending.currency.toUpperCase()
      }
    } catch (error) {
      console.error('Failed to fetch Stripe balance', error)
    }
  }

  const summary: PayoutSummary = {
    available_minor: Math.max(availableMinor, 0), // clamp negative to zero
    pending_minor: pendingMinor,
    incoming_pending_minor: incomingPendingMinor,
    currency_code: currencyCode,
  }

  return jsonResponse(summary)
})

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...jsonHeaders, ...allowHeaders() },
  })
}

function allowHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
  }
}
