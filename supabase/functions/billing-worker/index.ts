// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import { createClient } from "@supabase/supabase-js"
import Stripe from "stripe"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY") ?? ""
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
const stripeApiVersion = "2024-11-20.acacia"
const stripeReturnUrl = Deno.env.get("STRIPE_RETURN_URL") // optional; only sent if provided
const applicationFeeRate = 0.2 // 20%

if (!stripeSecretKey) console.warn("Missing STRIPE_SECRET_KEY")
if (!supabaseUrl) console.warn("Missing SUPABASE_URL")
if (!supabaseServiceRoleKey) console.warn("Missing SUPABASE_SERVICE_ROLE_KEY")
if (!stripeReturnUrl) console.error("Missing STRIPE_RETURN_URL (required when use_stripe_sdk=true)")

const stripe = new Stripe(stripeSecretKey, { apiVersion: stripeApiVersion })
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

type BillingJob = {
  id: string
  referee_request_id: string
  status: string
  currency_code: string
  amount_minor: number
  payment_provider: string
  provider_payment_id: string | null
  attempt_count: number
}

type RefereeRequest = {
  id: string
  matching_strategy: string
  matched_referee_id: string | null
  task_id: string
}

type Task = {
  id: string
  tasker_id: string
}

type StripeAccountRow = {
  stripe_customer_id: string | null
  default_payment_method_id: string | null
  stripe_connect_account_id: string | null
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
  if (!stripeReturnUrl) {
    return jsonResponse({ error: "Missing STRIPE_RETURN_URL" }, 500)
  }

  let claimedJobId: string | null = null

  try {
    const payload = await req.json()
    const jobId = payload?.id as string | undefined
    if (!jobId) {
      return jsonResponse({ error: "Missing billing_job id" }, 400)
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

    const { price, taskerAccount, refereeAccount, refereeRequest, task } = context.data

    const amountMinor = price.amount_minor
    const feeAmount = Math.floor(amountMinor * applicationFeeRate)
    const currency = job.currency_code.toLowerCase()

    if (amountMinor !== job.amount_minor) {
      await supabase
        .from("billing_jobs")
        .update({ amount_minor: amountMinor, updated_at: new Date().toISOString() })
        .eq("id", job.id)
    }

    const paymentIntent = await stripe.paymentIntents.create(
      {
        amount: amountMinor,
        currency,
        customer: taskerAccount.stripe_customer_id!,
        payment_method: taskerAccount.default_payment_method_id!,
        off_session: true,
        confirm: true,
        use_stripe_sdk: true,
        ...(stripeReturnUrl ? { return_url: stripeReturnUrl } : {}),
        payment_method_options: {
          card: {
            request_three_d_secure: "automatic",
          },
        },
        on_behalf_of: refereeAccount.stripe_connect_account_id!,
        transfer_data: {
          destination: refereeAccount.stripe_connect_account_id!,
        },
        application_fee_amount: feeAmount,
        metadata: {
          billing_job_id: job.id,
          referee_request_id: refereeRequest.id,
          task_id: task.id,
          tasker_id: task.tasker_id,
          referee_id: refereeRequest.matched_referee_id ?? "",
          matching_strategy: refereeRequest.matching_strategy,
        },
      },
      { idempotencyKey: `billing_job_${job.id}` },
    )

    await supabase
      .from("billing_jobs")
      .update({
        provider_payment_id: paymentIntent.id,
        currency_code: paymentIntent.currency.toUpperCase(),
        amount_minor: paymentIntent.amount,
        last_error_code: null,
        last_error_message: null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", job.id)

    return jsonResponse({
      id: job.id,
      status: "processing",
      payment_intent_id: paymentIntent.id,
    })
  } catch (error) {
    if (claimedJobId) {
      const parsed = parseError(error)
      await markFailed(claimedJobId, parsed.code, parsed.message)
    }
    handleStripeOrSystemError(error)
    return jsonResponse({ error: "Failed to process billing job" }, 500)
  }
})

async function claimJob(jobId: string): Promise<BillingJob | null> {
  const { data, error } = await supabase.rpc("claim_billing_job", { p_job_id: jobId })
  if (error) {
    throw error
  }
  return Array.isArray(data) && data.length > 0 ? (data[0] as BillingJob) : null
}

async function fetchContext(job: BillingJob) {
  const refereeRequest = await selectSingle<RefereeRequest>(
    "task_referee_requests",
    "id, matching_strategy, matched_referee_id, task_id",
    { id: job.referee_request_id },
  )
  if (refereeRequest.error) return refereeRequest

  if (!refereeRequest.data.matched_referee_id) {
    return { ok: false, code: "missing_referee", message: "Referee not assigned" }
  }

  const task = await selectSingle<Task>("tasks", "id, tasker_id", { id: refereeRequest.data.task_id })
  if (task.error) return task

  const price = await selectSingle<{ amount_minor: number }>(
    "billing_prices",
    "amount_minor",
    { currency_code: job.currency_code, matching_strategy: refereeRequest.data.matching_strategy },
  )
  if (price.error) return price

  const taskerAccount = await selectSingle<StripeAccountRow>(
    "stripe_accounts",
    "stripe_customer_id, default_payment_method_id, stripe_connect_account_id",
    { profile_id: task.data.tasker_id },
  )
  if (taskerAccount.error) return taskerAccount

  const refereeAccount = await selectSingle<StripeAccountRow>(
    "stripe_accounts",
    "stripe_customer_id, default_payment_method_id, stripe_connect_account_id",
    { profile_id: refereeRequest.data.matched_referee_id },
  )
  if (refereeAccount.error) return refereeAccount

  if (!taskerAccount.data.stripe_customer_id || !taskerAccount.data.default_payment_method_id) {
    return { ok: false, code: "missing_tasker_payment_method", message: "Tasker payment method not set" }
  }
  if (!refereeAccount.data.stripe_connect_account_id) {
    return { ok: false, code: "missing_referee_connect_account", message: "Referee connect account not set" }
  }

  return {
    ok: true,
    data: {
      price: price.data,
      taskerAccount: taskerAccount.data,
      refereeAccount: refereeAccount.data,
      refereeRequest: refereeRequest.data,
      task: task.data,
    },
  } as const
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
    .from("billing_jobs")
    .update({
      status: "failed",
      last_error_code: code,
      last_error_message: message,
      updated_at: new Date().toISOString(),
    })
    .eq("id", jobId)
}

function handleStripeOrSystemError(error: unknown) {
  console.error("billing-worker error", { error })
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
