// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "@supabase/supabase-js"
import Stripe from "stripe"

const stripeApiKey = Deno.env.get("STRIPE_SECRET_KEY") ?? ""
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? ""
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
const stripeApiVersion = "2024-11-20.acacia"

if (!stripeApiKey) {
  console.error("Missing STRIPE_SECRET_KEY")
}
if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
  console.error("Missing Supabase environment variables")
}

const stripe = new Stripe(stripeApiKey, {
  apiVersion: stripeApiVersion,
})

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  }

  try {
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: { Authorization: authHeader },
      },
    })
    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser()

    if (userError || !user) {
      console.error("Failed to authenticate user", userError?.message)
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    const serviceClient = createClient(supabaseUrl, supabaseServiceRoleKey)

    let { data: stripeAccount, error: accountError } = await serviceClient
      .from("stripe_accounts")
      .select("*")
      .eq("profile_id", user.id)
      .maybeSingle()

    if (accountError) {
      console.error("Failed to fetch stripe account", accountError.message)
      return new Response(
        JSON.stringify({ error: "Failed to fetch stripe account" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    if (!stripeAccount) {
      const { data: insertedAccount, error: insertError } = await serviceClient
        .from("stripe_accounts")
        .insert({ profile_id: user.id })
        .select()
        .single()

      if (insertError) {
        console.error("Failed to create stripe account record", insertError.message)
        return new Response(
          JSON.stringify({ error: "Failed to create stripe account record" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        )
      }
      stripeAccount = insertedAccount
    }

    if (!stripeAccount.stripe_customer_id) {
      const customer = await stripe.customers.create({
        metadata: {
          profile_id: user.id,
        },
      })

      const { data: updatedAccount, error: updateError } = await serviceClient
        .from("stripe_accounts")
        .update({ stripe_customer_id: customer.id })
        .eq("profile_id", user.id)
        .select()
        .single()

      if (updateError) {
        console.error("Failed to persist stripe customer id", updateError.message)
        return new Response(
          JSON.stringify({ error: "Failed to update stripe account" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        )
      }

      stripeAccount = updatedAccount
    }

    const customerId = stripeAccount.stripe_customer_id as string

    const setupIntent = await stripe.setupIntents.create({
      customer: customerId,
      payment_method_types: ["card"],
      usage: "off_session",
    })

    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: customerId },
      { apiVersion: stripeApiVersion },
    )

    const responsePayload = {
      customerId,
      setupIntentClientSecret: setupIntent.client_secret,
      ephemeralKeySecret: ephemeralKey.secret,
    }

    return new Response(
      JSON.stringify(responsePayload),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (error) {
    console.error("Unexpected error in billing-setup function", error)
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  }
})

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/billing-setup' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/
