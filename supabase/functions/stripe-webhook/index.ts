// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import { createClient } from "@supabase/supabase-js"
import Stripe from "stripe"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY") ?? ""
const stripeWebhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? ""
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
const stripeApiVersion = "2024-11-20.acacia"

if (!stripeSecretKey || !stripeWebhookSecret) {
  console.warn("Stripe secrets are missing. Please set STRIPE_SECRET_KEY and STRIPE_WEBHOOK_SECRET.")
}
if (!supabaseUrl || !supabaseServiceRoleKey) {
  console.warn("Supabase service credentials missing. Please set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY.")
}

const stripe = new Stripe(stripeSecretKey, {
  apiVersion: stripeApiVersion,
})

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

const jsonHeaders = { "Content-Type": "application/json" }

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: jsonHeaders },
    )
  }

  const body = await req.text()
  const signature = req.headers.get("Stripe-Signature")

  if (!signature || !stripeWebhookSecret) {
    return new Response(
      JSON.stringify({ error: "Missing Stripe signature or webhook secret" }),
      { status: 400, headers: jsonHeaders },
    )
  }

  let event: Stripe.Event
  try {
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      stripeWebhookSecret,
    )
  } catch (error) {
    const message = error instanceof Error ? error.message : "Invalid Stripe signature"
    console.error("Failed to construct Stripe event:", message)
    return new Response(
      JSON.stringify({ error: "Invalid signature" }),
      { status: 400, headers: jsonHeaders },
    )
  }

  try {
    switch (event.type) {
      case "setup_intent.succeeded":
        await handleSetupIntentSucceeded(event.data.object as Stripe.SetupIntent)
        break
      default:
        // Ignore other events for now
        break
    }
  } catch (error) {
    console.error("Error handling Stripe webhook event:", error)
    return new Response(
      JSON.stringify({ error: "Failed to process webhook" }),
      { status: 500, headers: jsonHeaders },
    )
  }

  return new Response(JSON.stringify({ received: true }), { headers: jsonHeaders })
})

async function handleSetupIntentSucceeded(setupIntent: Stripe.SetupIntent) {
  const customerId = extractCustomerId(setupIntent)
  const paymentMethodId = setupIntent.payment_method

  if (!customerId || !paymentMethodId) {
    console.warn("SetupIntent missing customer or payment method", setupIntent.id)
    return
  }

  const paymentMethod = await fetchPaymentMethod(paymentMethodId)
  if (!paymentMethod) {
    console.warn("Unable to fetch payment method", paymentMethodId)
    return
  }

  if (paymentMethod.type !== "card" || !paymentMethod.card) {
    console.warn("Payment method is not a card; skipping update", paymentMethod.id)
    return
  }

  const updatePayload = {
    default_payment_method_id: paymentMethod.id,
    pm_brand: paymentMethod.card.brand,
    pm_last4: paymentMethod.card.last4,
    pm_exp_month: paymentMethod.card.exp_month,
    pm_exp_year: paymentMethod.card.exp_year,
    updated_at: new Date().toISOString(),
  }

  const { error, count } = await supabase
    .from("stripe_accounts")
    .update(updatePayload)
    .eq("stripe_customer_id", customerId)
    .select("profile_id", { count: "exact", head: true })

  if (error) {
    console.error("Failed to update stripe_accounts record", error.message)
    throw error
  }

  if (count === 0) {
    console.warn(`No stripe_accounts row updated for customer ${customerId}`)
  }
}

function extractCustomerId(
  setupIntent: Stripe.SetupIntent,
): string | null {
  if (typeof setupIntent.customer === "string") {
    return setupIntent.customer
  }
  if (setupIntent.customer && "id" in setupIntent.customer) {
    return setupIntent.customer.id
  }
  return null
}

async function fetchPaymentMethod(
  paymentMethodRef: string | Stripe.PaymentMethod | null,
): Promise<Stripe.PaymentMethod | null> {
  if (!paymentMethodRef) {
    return null
  }
  if (typeof paymentMethodRef !== "string") {
    return paymentMethodRef
  }
  return await stripe.paymentMethods.retrieve(paymentMethodRef)
}

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Forward Stripe events locally:

     stripe listen --forward-to http://127.0.0.1:54321/functions/v1/stripe-webhook

  3. Trigger a test event from Stripe CLI, for example:

     stripe trigger setup_intent.succeeded

  Make sure STRIPE_SECRET_KEY and STRIPE_WEBHOOK_SECRET are set in the function environment.

*/
