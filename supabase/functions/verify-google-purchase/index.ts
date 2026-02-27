import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from '@supabase/supabase-js'
import { importPKCS8, SignJWT } from 'jose'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

/** Exchange a Google service account credential for an OAuth2 access token. */
async function getGoogleAccessToken(
  credentials: { client_email: string; private_key: string },
  scope: string,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const privateKey = await importPKCS8(credentials.private_key, 'RS256')

  const jwt = await new SignJWT({
    iss: credentials.client_email,
    scope,
    aud: 'https://oauth2.googleapis.com/token',
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey)

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  if (!res.ok) {
    const body = await res.text()
    throw new Error(`Google token exchange failed (${res.status}): ${body}`)
  }

  const data = await res.json()
  return data.access_token
}

interface SubscriptionPurchase {
  startTimeMillis?: string
  expiryTimeMillis?: string
  autoRenewing?: boolean
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

    const packageName = 'dev.cloveclove.peppercheck'

    if (type !== 'subscription') {
      throw new Error(`Unsupported purchase type: ${type}`)
    }

    // Get OAuth2 access token from service account
    const accessToken = await getGoogleAccessToken(
      credentials,
      'https://www.googleapis.com/auth/androidpublisher',
    )

    // Call Android Publisher API directly
    const apiUrl =
      `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/subscriptions/${productId}/tokens/${purchaseToken}`

    const apiRes = await fetch(apiUrl, {
      headers: { Authorization: `Bearer ${accessToken}` },
    })

    if (!apiRes.ok) {
      const body = await apiRes.text()
      throw new Error(`Google Play API error (${apiRes.status}): ${body}`)
    }

    const purchase: SubscriptionPurchase = await apiRes.json()

    // Check expiry
    const expiryTime = parseInt(purchase.expiryTimeMillis ?? '0')
    const isActive = expiryTime > Date.now()
    const status = isActive ? 'active' : 'canceled'

    // Get authenticated user
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Missing Authorization header')
    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: userError } = await supabase.auth.getUser(token)
    if (userError || !user) throw new Error('Invalid User Token')

    // Upsert subscription
    const { error: dbError } = await supabase
      .from('user_subscriptions')
      .upsert({
        user_id: user.id,
        plan_id: productId,
        status,
        provider: 'google',
        google_purchase_token: purchaseToken,
        current_period_start: new Date(parseInt(purchase.startTimeMillis ?? '0')).toISOString(),
        current_period_end: new Date(expiryTime).toISOString(),
        cancel_at_period_end: !purchase.autoRenewing,
        updated_at: new Date().toISOString(),
      })

    if (dbError) throw new Error(`DB Error: ${dbError.message}`)

    const subscriptionData = { status, expiryTime: new Date(expiryTime).toISOString() }

    return new Response(
      JSON.stringify(subscriptionData),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error'
    return new Response(
      JSON.stringify({ error: message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
