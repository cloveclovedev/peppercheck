// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import { createClient } from "@supabase/supabase-js"
import Stripe from "stripe"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY") ?? ""
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
const stripeApiVersion = "2024-11-20.acacia"

if (!stripeSecretKey) console.warn("Missing STRIPE_SECRET_KEY")
if (!supabaseUrl) console.warn("Missing SUPABASE_URL")
if (!supabaseServiceRoleKey) console.warn("Missing SUPABASE_SERVICE_ROLE_KEY")

const stripe = new Stripe(stripeSecretKey, { apiVersion: stripeApiVersion })
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

type PayoutJob = {
  id: string
  user_id: string
  status: string
  currency_code: string
  amount_minor: number
  payment_provider: string
  provider_payout_id: string | null
  attempt_count: number
}

type StripeAccountRow = {
  stripe_connect_account_id: string | null
  payouts_enabled: boolean | null
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405)
  }

  if (!stripeSecretKey || !supabaseUrl || !supabaseServiceRoleKey) {
    return jsonResponse({ error: "Server not configured" }, 500)
  }

  let claimedJobId: string | null = null

  try {
    const payload = await req.json().catch(() => null)
    const jobId = payload?.id as string | undefined
    if (!jobId) {
      return jsonResponse({ error: "Missing payout_job id" }, 400)
    }

    const job = await claimJob(jobId)
    if (!job) {
      return jsonResponse({ error: "Job not found or not pending" }, 409)
    }

    claimedJobId = job.id

    const context = await fetchContext(job)
    if (!context.ok) {
      await markFailed(job.id, context.code, context.message)
      return jsonResponse({ error: context.message }, 400)
    }

    const { account } = context.data

  const amountMinor = job.amount_minor
  const currency = job.currency_code.toLowerCase()

  // Create a payout from the connected account balance to its external bank account.
  const payout = await stripe.payouts.create(
    {
      amount: amountMinor,
      currency,
      metadata: {
        payout_job_id: job.id,
        user_id: job.user_id,
      },
    },
    {
      idempotencyKey: `payout_job_${job.id}`,
      stripeAccount: account.stripe_connect_account_id!, // act on behalf of the connected account
    },
  )

  await supabase
    .from("payout_jobs")
    .update({
      provider_payout_id: payout.id,
      currency_code: payout.currency.toUpperCase(),
      amount_minor: payout.amount,
      last_error_code: null,
      last_error_message: null,
      updated_at: new Date().toISOString(),
    })
    .eq("id", job.id)

  return jsonResponse({
    id: job.id,
    status: "processing",
    payout_id: payout.id,
  })
  } catch (error) {
    if (claimedJobId) {
      const parsed = parseError(error)
      await markFailed(claimedJobId, parsed.code, parsed.message)
    }
    handleStripeOrSystemError(error)
    return jsonResponse({ error: "Failed to process payout job" }, 500)
  }
})

async function claimJob(jobId: string): Promise<PayoutJob | null> {
  const { data, error } = await supabase.rpc("claim_payout_job", { p_job_id: jobId })
  if (error) {
    throw error
  }
  return Array.isArray(data) && data.length > 0 ? (data[0] as PayoutJob) : null
}

async function fetchContext(job: PayoutJob) {
  if (!job.amount_minor || job.amount_minor <= 0) {
    return { ok: false, code: "invalid_amount", message: "Payout amount must be greater than 0" }
  }

  const account = await selectSingle<StripeAccountRow>(
    "stripe_accounts",
    "stripe_connect_account_id, payouts_enabled",
    { profile_id: job.user_id },
  )
  if (!account.ok) return account

  if (!account.data.stripe_connect_account_id) {
    return { ok: false, code: "missing_connect_account", message: "Stripe Connect account not set" }
  }
  if (account.data.payouts_enabled === false) {
    return { ok: false, code: "payouts_disabled", message: "Payouts are not enabled" }
  }

  return { ok: true, data: { account: account.data } } as const
}

async function selectSingle<T>(
  table: string,
  columns: string,
  filters: Record<string, unknown>,
): Promise<{ ok: true; data: T } | { ok: false; code: string; message: string; error?: unknown }> {
  let query = supabase.from(table).select(columns).limit(1)
  for (const [key, value] of Object.entries(filters)) {
    if (value === null || value === undefined) {
      return { ok: false, code: `missing_${table}`, message: `Required ${table} not found` }
    }
    query = query.eq(key, value as never)
  }
  const { data, error } = await query.single()
  if (error || !data) {
    return { ok: false, code: `missing_${table}`, message: `Required ${table} not found`, error }
  }
  return { ok: true, data: data as T }
}

async function markFailed(jobId: string, code: string, message: string) {
  await supabase
    .from("payout_jobs")
    .update({
      status: "failed",
      last_error_code: code,
      last_error_message: message,
      updated_at: new Date().toISOString(),
    })
    .eq("id", jobId)
}

function handleStripeOrSystemError(error: unknown) {
  console.error("payout-worker error", { error })
}

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

function parseError(error: unknown): { code: string; message: string } {
  const fallback = { code: "processing_error", message: "Unexpected error" }
  if (typeof error === "string") return { code: "processing_error", message: error }
  if (error && typeof error === "object") {
    const anyErr = error as { code?: string; message?: string }
    return {
      code: anyErr.code ?? fallback.code,
      message: anyErr.message ?? fallback.message,
    }
  }
  return fallback
}
