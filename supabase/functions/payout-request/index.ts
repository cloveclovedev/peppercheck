// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import { createClient } from "@supabase/supabase-js"

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""

if (!supabaseUrl) console.warn("Missing SUPABASE_URL")
if (!supabaseServiceRoleKey) console.warn("Missing SUPABASE_SERVICE_ROLE_KEY")

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

const jsonHeaders = { "Content-Type": "application/json" }

type PayoutRequestBody = {
  amount_minor?: number
  currency_code?: string
}

type PayoutJobRow = {
  id: string
  status: string
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: allowHeaders() })
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405)
  }

  const authHeader = req.headers.get("Authorization")
  if (!authHeader) {
    return jsonResponse({ error: "Unauthorized" }, 401)
  }

  let userId: string
  try {
    const { data, error } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""))
    if (error || !data.user) {
      return jsonResponse({ error: "Unauthorized" }, 401)
    }
    userId = data.user.id
  } catch (error) {
    console.error("Failed to validate auth token", error)
    return jsonResponse({ error: "Unauthorized" }, 401)
  }

  let body: PayoutRequestBody
  try {
    body = await req.json()
  } catch {
    return jsonResponse({ error: "Invalid JSON" }, 400)
  }

  const amountMinor = body.amount_minor ?? 0
  const currencyCode = (body.currency_code ?? "JPY").toUpperCase()

  if (!Number.isFinite(amountMinor) || amountMinor <= 0) {
    return jsonResponse({ error: "amount_minor must be a positive integer" }, 400)
  }

  // Check stripe_accounts for payouts_enabled and connect account presence
  const { data: account, error: accountError } = await supabase
    .from("stripe_accounts")
    .select("stripe_connect_account_id, payouts_enabled")
    .eq("profile_id", userId)
    .maybeSingle()

  if (accountError) {
    console.error("Failed to fetch stripe_accounts", accountError)
    return jsonResponse({ error: "Failed to verify payout eligibility" }, 500)
  }

  if (!account || !account.stripe_connect_account_id) {
    return jsonResponse({ error: "Stripe Connect account not set" }, 400)
  }
  if (account.payouts_enabled === false) {
    return jsonResponse({ error: "Payouts are not enabled" }, 400)
  }

  // Prevent duplicates (pending/processing)
  const { data: existing, error: existingError } = await supabase
    .from("payout_jobs")
    .select("id, status")
    .eq("user_id", userId)
    .in("status", ["pending", "processing"])
    .limit(1)

  if (existingError) {
    console.error("Failed to check existing payout_jobs", existingError)
    return jsonResponse({ error: "Failed to check existing payout requests" }, 500)
  }

  if (existing && existing.length > 0) {
    return jsonResponse({ error: "A payout request is already in progress" }, 409)
  }

  const insertPayload = {
    user_id: userId,
    status: "pending",
    currency_code: currencyCode,
    amount_minor: Math.trunc(amountMinor),
    payment_provider: "stripe",
    attempt_count: 0,
  }

  const { data: inserted, error: insertError } = await supabase
    .from("payout_jobs")
    .insert(insertPayload)
    .select("id, status")
    .single()

  if (insertError || !inserted) {
    console.error("Failed to insert payout_job", insertError)
    return jsonResponse({ error: "Failed to create payout request" }, 500)
  }

  return jsonResponse(inserted)
})

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...jsonHeaders, ...allowHeaders() },
  })
}

function allowHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  }
}
