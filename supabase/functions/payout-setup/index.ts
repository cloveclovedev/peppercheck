// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import { createClient } from "@supabase/supabase-js"
import Stripe from "stripe"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY") ?? ""
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? ""
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
const stripeOnboardingReturnUrl = Deno.env.get("STRIPE_ONBOARDING_RETURN_URL") ?? ""
const stripeOnboardingRefreshUrl = Deno.env.get("STRIPE_ONBOARDING_REFRESH_URL") ?? ""

if (!stripeSecretKey) {
  console.warn("STRIPE_SECRET_KEY is not set.")
}
if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
  console.warn("Supabase environment variables are missing.")
}
if (!stripeOnboardingReturnUrl || !stripeOnboardingRefreshUrl) {
  console.warn("Stripe onboarding URLs are missing.")
}

const stripe = new Stripe(stripeSecretKey, {
  apiVersion: "2024-11-20.acacia",
})

const jsonHeaders = { "Content-Type": "application/json" }

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: jsonHeaders },
    )
  }

  const authHeader = req.headers.get("Authorization")
  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: "Missing authorization header" }),
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
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: jsonHeaders },
      )
    }

    const serviceClient = createClient(supabaseUrl, supabaseServiceRoleKey)

    let stripeAccountRow = await getOrCreateStripeAccountRow(serviceClient, user.id)

    let connectAccountId = stripeAccountRow.stripe_connect_account_id
    let connectAccount: Stripe.Account

    if (!connectAccountId) {
      connectAccount = await createConnectAccount(user)
      const updated = await updateStripeAccountRow(serviceClient, user.id, {
        stripe_connect_account_id: connectAccount.id,
        charges_enabled: connectAccount.charges_enabled,
        payouts_enabled: connectAccount.payouts_enabled,
        connect_requirements: connectAccount.requirements,
      })
      stripeAccountRow = updated ?? stripeAccountRow
      connectAccountId = connectAccount.id
    } else {
      connectAccount = await stripe.accounts.retrieve(connectAccountId)
      const updated = await updateStripeAccountRow(serviceClient, user.id, {
        charges_enabled: connectAccount.charges_enabled,
        payouts_enabled: connectAccount.payouts_enabled,
        connect_requirements: connectAccount.requirements,
      })
      stripeAccountRow = updated ?? stripeAccountRow
    }

    if (!stripeOnboardingReturnUrl || !stripeOnboardingRefreshUrl) {
      return new Response(
        JSON.stringify({ error: "Onboarding URLs are not configured" }),
        { status: 500, headers: jsonHeaders },
      )
    }

    const accountLink = await stripe.accountLinks.create({
      account: connectAccountId!,
      refresh_url: stripeOnboardingRefreshUrl,
      return_url: stripeOnboardingReturnUrl,
      type: "account_onboarding",
    })

    return new Response(
      JSON.stringify({ url: accountLink.url }),
      { headers: jsonHeaders },
    )
  } catch (error) {
    console.error("Failed to create Stripe Connect onboarding link", error)
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: jsonHeaders },
    )
  }
})

async function getOrCreateStripeAccountRow(
  client: ReturnType<typeof createClient>,
  profileId: string,
) {
  let { data, error } = await client
    .from("stripe_accounts")
    .select("*")
    .eq("profile_id", profileId)
    .maybeSingle()

  if (error) {
    throw new Error(`Failed to fetch stripe_accounts row: ${error.message}`)
  }

  if (!data) {
    const { data: inserted, error: insertError } = await client
      .from("stripe_accounts")
      .insert({ profile_id: profileId })
      .select("*")
      .single()

    if (insertError || !inserted) {
      throw new Error(`Failed to insert stripe_accounts row: ${insertError?.message}`)
    }
    return inserted
  }

  return data
}

async function updateStripeAccountRow(
  client: ReturnType<typeof createClient>,
  profileId: string,
  payload: Record<string, unknown>,
) {
  const { data, error } = await client
    .from("stripe_accounts")
    .update(payload)
    .eq("profile_id", profileId)
    .select("*")
    .single()

  if (error) {
    console.error("Failed to update stripe_accounts row", error.message)
    return null
  }
  return data
}

async function createConnectAccount(user: {
  id: string
  email?: string | null
}) {
  return await stripe.accounts.create({
    type: "express",
    business_type: "individual",
    email: user.email ?? undefined,
    capabilities: {
      transfers: { requested: true },
      card_payments: { requested: true },
    },
    metadata: {
      profile_id: user.id,
    },
  })
}

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/payout-setup' \
    --header 'Authorization: Bearer <your access token>' \
    --header 'Content-Type: application/json'

*/
