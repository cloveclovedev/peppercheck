import 'jsr:@supabase/functions-js@^2/edge-runtime.d.ts'
import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from 'jose'

const GOOGLE_JWKS = createRemoteJWKSet(
  new URL('https://www.googleapis.com/oauth2/v3/certs'),
)

async function verifyPubSubOidcToken(req: Request): Promise<boolean> {
  const expectedAudience = Deno.env.get('GOOGLE_PUBSUB_AUDIENCE')
  const expectedEmail = Deno.env.get('GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL')

  if (!expectedAudience || !expectedEmail) {
    console.error('Missing GOOGLE_PUBSUB_AUDIENCE or GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL env vars')
    return false
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) return false

  const token = authHeader.slice(7)

  try {
    const { payload } = await jwtVerify(token, GOOGLE_JWKS, {
      audience: expectedAudience,
      issuer: 'https://accounts.google.com',
    })

    if (!payload.email_verified) return false
    if (payload.email !== expectedEmail) return false

    return true
  } catch (err) {
    console.error('OIDC token verification failed:', err)
    return false
  }
}

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

const PACKAGE_NAME = 'dev.cloveclove.peppercheck'

interface SubscriptionV2 {
  subscriptionState: string
  startTime?: string
  lineItems?: Array<{
    productId: string
    expiryTime: string
    autoRenewingPlan?: Record<string, unknown>
  }>
  externalAccountIdentifiers?: {
    obfuscatedExternalAccountId?: string
    obfuscatedExternalProfileId?: string
  }
  acknowledgementState?: string
}

async function _fetchSubscriptionV2(purchaseToken: string): Promise<SubscriptionV2> {
  const serviceAccountJson = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON')
  if (!serviceAccountJson) throw new Error('Missing GOOGLE_SERVICE_ACCOUNT_JSON')

  const credentials = JSON.parse(serviceAccountJson)
  const accessToken = await getGoogleAccessToken(
    credentials,
    'https://www.googleapis.com/auth/androidpublisher',
  )

  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE_NAME}/purchases/subscriptionsv2/tokens/${purchaseToken}`

  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  })

  if (!res.ok) {
    const body = await res.text()
    throw new Error(`subscriptionsv2.get failed (${res.status}): ${body}`)
  }

  return res.json()
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  // Verify OIDC token from Pub/Sub
  const isAuthentic = await verifyPubSubOidcToken(req)
  if (!isAuthentic) {
    console.error('OIDC verification failed, rejecting request')
    return new Response('Unauthorized', { status: 401 })
  }

  try {
    const body = await req.json()
    console.log('Received authenticated Pub/Sub message:', JSON.stringify(body))
    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('Error processing RTDN:', error)
    return new Response(JSON.stringify({ error: 'processing failed' }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  }
})
