// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from '@supabase/supabase-js'
import { google } from 'googleapis'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const { productId, purchaseToken, type = 'subscription' } = await req.json()

    if (!productId || !purchaseToken) {
      throw new Error('Missing productId or purchaseToken')
    }

    // Load Service Account Credentials
    const serviceAccountJson = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON')
    if (!serviceAccountJson) {
      throw new Error('Missing GOOGLE_SERVICE_ACCOUNT_JSON')
    }
    const credentials = JSON.parse(serviceAccountJson)

    // Authenticate Google Client
    const auth = new google.auth.GoogleAuth({
      credentials,
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    })
    const androidPublisher = google.androidpublisher({ version: 'v3', auth })
    const packageName = 'dev.cloveclove.peppercheck'

    let subscriptionData = null

    if (type === 'subscription') {
      // Verify Subscription
      const res = await androidPublisher.purchases.subscriptions.get({
        packageName,
        subscriptionId: productId,
        token: purchaseToken,
      })

      const purchase = res.data

      // Check expiry (expiryTimeMillis is string)
      const expiryTime = parseInt(purchase.expiryTimeMillis ?? '0')
      const now = Date.now()
      const isActive = expiryTime > now

      // Map to our status
      let status = 'canceled'
      if (isActive) {
        status = 'active'
        // Handle autoRenewing etc if needed for more granular status
      }

      // Upsert to DB
      // We need user_id from Auth header (handled by Supabase Functions usually,
      // but if called from App, user is authenticated)
      const authHeader = req.headers.get('Authorization')
      if (!authHeader) throw new Error('Missing Authorization header')
      const token = authHeader.replace('Bearer ', '')
      const { data: { user }, error: userError } = await supabase.auth.getUser(token)
      if (userError || !user) throw new Error('Invalid User Token')

      // Upsert
      const { error: dbError } = await supabase
        .from('user_subscriptions')
        .upsert({
          user_id: user.id,
          plan_id: productId, // Assuming productId maps to subscription_plans.id (e.g. 'light')?
          // OR we need a mapping if IDs differ.
          // For now assuming 1:1 or logic handles it.
          status: status,
          provider: 'google',
          google_purchase_token: purchaseToken,
          current_period_start: new Date(parseInt(purchase.startTimeMillis ?? '0')).toISOString(),
          current_period_end: new Date(expiryTime).toISOString(),
          cancel_at_period_end: !purchase.autoRenewing,
          updated_at: new Date().toISOString(),
        })

      if (dbError) throw new Error(`DB Error: ${dbError.message}`)

      subscriptionData = { status, expiryTime: new Date(expiryTime).toISOString() }
    } else {
      throw new Error(`Unsupported purchase type: ${type}`)
    }

    return new Response(
      JSON.stringify(subscriptionData),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message || 'Unknown error' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/verify-google-purchase' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/
