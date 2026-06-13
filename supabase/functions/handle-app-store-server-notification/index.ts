import 'jsr:@supabase/functions-js@^2/edge-runtime.d.ts'
import { createClient } from '@supabase/supabase-js'
import { Environment, SignedDataVerifier } from '@apple/app-store-server-library'
import { extractPlanId, mapNotificationToStatus } from './helpers.ts'

const DEFAULT_BUNDLE_ID = 'dev.cloveclove.peppercheck'

// Apple's PUBLIC root CA certificates (bundled in ./certs/, downloaded from
// https://www.apple.com/certificateauthority/). NOT secrets — these are the
// same trust anchors every macOS / iOS device ships with. The SignedDataVerifier
// uses them to validate the JWS x5c chain on incoming ASSN V2 payloads.
async function loadAppleRootCAs(): Promise<Uint8Array[]> {
  const baseUrl = new URL('./certs/', import.meta.url)
  const files = [
    'AppleRootCA-G2.cer',
    'AppleRootCA-G3.cer',
    'AppleComputerRootCertificate.cer',
  ]
  return await Promise.all(
    files.map((f) => Deno.readFile(new URL(f, baseUrl))),
  )
}

let cachedVerifier: SignedDataVerifier | null = null

async function getVerifier(): Promise<SignedDataVerifier> {
  if (cachedVerifier) return cachedVerifier
  const env = Deno.env.get('APPLE_ENVIRONMENT') === 'Production'
    ? Environment.PRODUCTION
    : Environment.SANDBOX
  const rootCAs = await loadAppleRootCAs()
  // Deno returns Uint8Array; SDK types expect Node Buffer — structurally compatible at runtime
  // deno-lint-ignore no-explicit-any
  const rootCAsAsBuffer = rootCAs as any
  cachedVerifier = new SignedDataVerifier(
    rootCAsAsBuffer,
    true, // enableOnlineChecks (OCSP)
    env,
    Deno.env.get('APPLE_BUNDLE_ID') ?? DEFAULT_BUNDLE_ID,
  )
  return cachedVerifier
}

interface DispatchInput {
  notificationType: string | undefined
  subtype: string | undefined
  // deno-lint-ignore no-explicit-any
  transactionInfo: any
  // deno-lint-ignore no-explicit-any
  renewalInfo: any
  userId: string
  // deno-lint-ignore no-explicit-any
  supabaseAdmin: any
}

async function upsertSubscription(
  input: DispatchInput,
  status: string,
): Promise<void> {
  const { transactionInfo, renewalInfo, userId, supabaseAdmin } = input
  const { error } = await supabaseAdmin.from('user_subscriptions').upsert({
    user_id: userId,
    plan_id: extractPlanId(transactionInfo.productId),
    status,
    provider: 'apple',
    apple_original_transaction_id: transactionInfo.originalTransactionId,
    current_period_start: new Date(transactionInfo.purchaseDate).toISOString(),
    current_period_end: new Date(transactionInfo.expiresDate).toISOString(),
    cancel_at_period_end: renewalInfo ? renewalInfo.autoRenewStatus === 0 : false,
    updated_at: new Date().toISOString(),
  })
  if (error) throw error
}

async function resetPoints(input: DispatchInput): Promise<void> {
  const { transactionInfo, userId, supabaseAdmin } = input
  const planId = extractPlanId(transactionInfo.productId)
  const { data: planData, error: planError } = await supabaseAdmin
    .from('subscription_plans')
    .select('monthly_points')
    .eq('id', planId)
    .single()
  if (planError || !planData) {
    throw new Error(`Plan not found: ${planId}`)
  }
  if (planData.monthly_points <= 0) return
  const invoiceId = `apple:${transactionInfo.transactionId}`
  const { data: granted, error } = await supabaseAdmin.rpc(
    'reset_subscription_points',
    {
      p_user_id: userId,
      p_amount: planData.monthly_points,
      p_invoice_id: invoiceId,
    },
  )
  if (error) throw error
  if (granted) {
    console.log(`Reset points to ${planData.monthly_points} for user ${userId}`)
  } else {
    console.log(`Points already reset for ${invoiceId} (idempotent)`)
  }
}

async function deactivateTrial(input: DispatchInput): Promise<void> {
  const { userId, supabaseAdmin } = input
  const { error } = await supabaseAdmin.rpc('deactivate_trial_points', {
    p_user_id: userId,
  })
  if (error) {
    // Best-effort; subscription activation already succeeded.
    console.error(`Failed to deactivate trial points for user ${userId}:`, error)
  }
}

async function dispatch(input: DispatchInput): Promise<void> {
  const { notificationType, subtype, userId, supabaseAdmin } = input

  if (!notificationType) return

  if (notificationType === 'TEST' || notificationType === 'PRICE_INCREASE') {
    return
  }

  if (notificationType === 'DID_CHANGE_RENEWAL_STATUS') {
    const cancelAtPeriodEnd = subtype === 'AUTO_RENEW_DISABLED'
    const { error } = await supabaseAdmin
      .from('user_subscriptions')
      .update({
        cancel_at_period_end: cancelAtPeriodEnd,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId)
    if (error) throw error
    return
  }

  if (notificationType === 'SUBSCRIBED') {
    await upsertSubscription(input, 'active')
    await resetPoints(input)
    if (subtype === 'INITIAL_BUY') {
      await deactivateTrial(input)
    }
    return
  }

  if (notificationType === 'DID_RENEW') {
    await upsertSubscription(input, 'active')
    await resetPoints(input)
    return
  }

  if (notificationType === 'DID_CHANGE_RENEWAL_PREF') {
    await upsertSubscription(input, 'active')
    return
  }

  const mappedStatus = mapNotificationToStatus(notificationType, subtype)
  if (mappedStatus) {
    await upsertSubscription(input, mappedStatus)
  }
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

  try {
    const body = await req.json()
    const verifier = await getVerifier()

    const decoded = await verifier.verifyAndDecodeNotification(body.signedPayload)
    const { notificationType, subtype, data } = decoded
    console.log(
      `ASSN: env=${data?.environment ?? '-'} type=${notificationType} subtype=${subtype ?? '-'}`,
    )

    if (!data?.signedTransactionInfo) {
      return new Response(JSON.stringify({ received: true }), { status: 200 })
    }
    const transactionInfo = await verifier.verifyAndDecodeTransaction(
      data.signedTransactionInfo,
    )
    const renewalInfo = data.signedRenewalInfo
      ? await verifier.verifyAndDecodeRenewalInfo(data.signedRenewalInfo)
      : null

    const userId = transactionInfo.appAccountToken
    if (!userId) {
      console.error('appAccountToken missing — skipping')
      return new Response(JSON.stringify({ received: true }), { status: 200 })
    }

    await dispatch({
      notificationType,
      subtype,
      transactionInfo,
      renewalInfo,
      userId,
      supabaseAdmin,
    })

    return new Response(JSON.stringify({ received: true }), { status: 200 })
  } catch (err) {
    console.error('Error processing ASSN:', err)
    // Always 200 — Apple retries non-2xx for up to 3 days, max 5 times.
    // Failed processing is investigated via logs, not retried automatically.
    return new Response(JSON.stringify({ error: 'processing failed' }), { status: 200 })
  }
})
