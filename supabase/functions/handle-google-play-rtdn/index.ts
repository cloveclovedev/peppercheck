import 'jsr:@supabase/functions-js@^2/edge-runtime.d.ts'
import { createClient } from 'jsr:@supabase/supabase-js@2'
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

// RTDN notification types
// https://developer.android.com/google/play/billing/rtdn-reference
const NOTIFICATION_TYPE = {
  RECOVERED: 1,
  RENEWED: 2,
  CANCELED: 3,
  PURCHASED: 4,
  ON_HOLD: 5,
  IN_GRACE_PERIOD: 6,
  RESTARTED: 7,
  PRICE_CHANGE_CONFIRMED: 8,
  DEFERRED: 9,
  PAUSED: 10,
  PAUSE_SCHEDULE_CHANGED: 11,
  REVOKED: 12,
  EXPIRED: 13,
} as const

// Google Play product IDs are '{planId}_monthly', DB plan IDs are '{planId}'
function extractPlanId(productId: string): string {
  return productId.replace('_monthly', '')
}

// Map notification types to subscription_status enum values in DB
function mapSubscriptionStatus(notificationType: number): string | null {
  switch (notificationType) {
    case NOTIFICATION_TYPE.PURCHASED:
    case NOTIFICATION_TYPE.RENEWED:
    case NOTIFICATION_TYPE.RECOVERED:
    case NOTIFICATION_TYPE.RESTARTED:
      return 'active'
    case NOTIFICATION_TYPE.IN_GRACE_PERIOD:
      return 'past_due'
    case NOTIFICATION_TYPE.ON_HOLD:
      return 'unpaid'
    case NOTIFICATION_TYPE.EXPIRED:
    case NOTIFICATION_TYPE.REVOKED:
      return 'canceled'
    case NOTIFICATION_TYPE.CANCELED:
      return null // Handled separately: only sets cancel_at_period_end
    case NOTIFICATION_TYPE.PAUSED:
      return 'paused'
    default:
      return null
  }
}

async function handleSubscriptionNotification(
  notificationType: number,
  purchaseToken: string,
  supabaseAdmin: ReturnType<typeof createClient>,
): Promise<void> {
  // Always fetch current state — notifications are signals, not data
  const subscription = await fetchSubscriptionV2(purchaseToken)

  const userId = subscription.externalAccountIdentifiers?.obfuscatedExternalAccountId
  if (!userId) {
    console.error('No obfuscatedExternalAccountId found in subscription response')
    return
  }

  const lineItem = subscription.lineItems?.[0]
  if (!lineItem) {
    console.error('No line items in subscription response')
    return
  }

  const planId = extractPlanId(lineItem.productId)

  // Handle CANCELED separately: only update cancel_at_period_end, keep status active until expiry
  if (notificationType === NOTIFICATION_TYPE.CANCELED) {
    console.log(`Processing CANCELED for user=${userId}: setting cancel_at_period_end`)
    const { error } = await supabaseAdmin
      .from('user_subscriptions')
      .update({
        cancel_at_period_end: true,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId)

    if (error) {
      console.error('Failed to update cancel_at_period_end:', error)
      throw error
    }
    console.log(`Marked cancel_at_period_end for user ${userId}`)
    return
  }

  const status = mapSubscriptionStatus(notificationType)
  if (!status) {
    console.log(`Notification type ${notificationType} does not require status update, skipping`)
    return
  }

  console.log(
    `Processing notification type=${notificationType} for user=${userId} plan=${planId} status=${status}`,
  )

  // Upsert subscription for all other notification types
  // deno-lint-ignore no-explicit-any
  const { error: upsertError } = await (supabaseAdmin.from('user_subscriptions') as any).upsert({
    user_id: userId,
    plan_id: planId,
    status: status,
    provider: 'google',
    google_purchase_token: purchaseToken,
    current_period_start: subscription.startTime
      ? new Date(subscription.startTime).toISOString()
      : new Date().toISOString(),
    current_period_end: new Date(lineItem.expiryTime).toISOString(),
    cancel_at_period_end: !lineItem.autoRenewingPlan,
    updated_at: new Date().toISOString(),
  })

  if (upsertError) {
    console.error('Failed to upsert user_subscription:', upsertError)
    throw upsertError
  }

  // Grant points on PURCHASED or RENEWED
  if (
    notificationType === NOTIFICATION_TYPE.PURCHASED ||
    notificationType === NOTIFICATION_TYPE.RENEWED
  ) {
    // deno-lint-ignore no-explicit-any
    const plansTable = supabaseAdmin.from('subscription_plans') as any
    const { data: planData, error: planError } = await plansTable
      .select('monthly_points')
      .eq('id', planId)
      .single()

    if (planError || !planData) {
      console.error(`Failed to fetch plan data for ${planId}:`, planError?.message)
      throw new Error(`Plan not found: ${planId}`)
    }

    if (planData.monthly_points > 0) {
      // Idempotency key: google:{purchaseToken}:{expiryTime}
      // Using expiryTime ensures each renewal period gets a unique key
      // (purchaseToken stays the same for the life of the subscription)
      const invoiceId = `google:${purchaseToken}:${lineItem.expiryTime}`
      const { data: granted, error: rpcError } = await supabaseAdmin.rpc(
        'grant_subscription_points',
        {
          p_user_id: userId,
          p_amount: planData.monthly_points,
          p_invoice_id: invoiceId,
        },
      )

      if (rpcError) {
        console.error(`grant_subscription_points failed:`, rpcError)
        throw rpcError
      }

      if (granted) {
        console.log(`Granted ${planData.monthly_points} points to user ${userId}`)
      } else {
        console.log(`Points already granted for ${invoiceId}, skipping (idempotent)`)
      }
    }
  }

  // Deactivate trial points on PURCHASED (best-effort)
  if (notificationType === NOTIFICATION_TYPE.PURCHASED) {
    const { error: trialError } = await supabaseAdmin.rpc('deactivate_trial_points', {
      p_user_id: userId,
    })
    if (trialError) {
      console.error(`Failed to deactivate trial points for user ${userId}:`, trialError)
      // Don't throw — subscription activation is primary
    } else {
      console.log(`Trial points deactivated for user ${userId}`)
    }
  }
}

async function fetchSubscriptionV2(purchaseToken: string): Promise<SubscriptionV2> {
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

  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

  try {
    const body = await req.json()

    // Parse Pub/Sub push envelope
    const messageData = body.message?.data
    if (!messageData) {
      console.error('No message.data in Pub/Sub envelope')
      return new Response(JSON.stringify({ received: true }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    // Decode base64 notification data
    const decoded = atob(messageData)
    const notification = JSON.parse(decoded)

    console.log(
      `RTDN: package=${notification.packageName}, event_time=${notification.eventTimeMillis}`,
    )

    // Handle test notification
    if (notification.testNotification) {
      console.log('Received test notification, version:', notification.testNotification.version)
      return new Response(JSON.stringify({ received: true, test: true }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    // Handle subscription notification
    if (notification.subscriptionNotification) {
      const { notificationType, purchaseToken } = notification.subscriptionNotification
      console.log(`Subscription notification: type=${notificationType}, token=${purchaseToken}`)

      await handleSubscriptionNotification(notificationType, purchaseToken, supabaseAdmin)
    } else {
      console.log('Received non-subscription notification, skipping')
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    // Errors from handleSubscriptionNotification bubble up here intentionally.
    // Unlike Stripe webhooks (which return 500 for retries), Pub/Sub retries
    // on any non-2xx with exponential backoff — always return 200 to prevent
    // infinite retry loops. Failed operations are logged for manual investigation.
    console.error('Error processing RTDN:', error)
    return new Response(JSON.stringify({ error: 'processing failed' }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  }
})
