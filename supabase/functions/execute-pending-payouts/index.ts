import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import { createClient } from "@supabase/supabase-js"
import Stripe from "stripe"

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY") ?? ""

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

  // Verify service role authorization (internal call from pg_cron via pg_net)
  const authHeader = req.headers.get("Authorization")
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return new Response(
      JSON.stringify({ error: "Missing authorization" }),
      { status: 401, headers: jsonHeaders },
    )
  }

  const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

  try {
    // Fetch pending payouts
    const { data: payouts, error: fetchError } = await supabase
      .from("reward_payouts")
      .select("id, user_id, points_amount, currency, currency_amount")
      .eq("status", "pending")
      .order("created_at", { ascending: true })

    if (fetchError) {
      console.error("Failed to fetch pending payouts:", fetchError)
      return new Response(
        JSON.stringify({ error: "Failed to fetch payouts" }),
        { status: 500, headers: jsonHeaders },
      )
    }

    if (!payouts || payouts.length === 0) {
      return new Response(
        JSON.stringify({ message: "No pending payouts", processed: 0 }),
        { status: 200, headers: jsonHeaders },
      )
    }

    let successCount = 0
    let failCount = 0

    for (const payout of payouts) {
      try {
        // Get Connect account ID for this user
        // profiles.id = auth.users.id = stripe_accounts.profile_id
        const { data: stripeAccount, error: accountError } = await supabase
          .from("stripe_accounts")
          .select("stripe_connect_account_id")
          .eq("profile_id", payout.user_id)
          .single()

        if (accountError || !stripeAccount?.stripe_connect_account_id) {
          throw new Error(
            `No Connect account for user ${payout.user_id}: ${accountError?.message ?? "missing"}`,
          )
        }

        // Create Stripe Transfer with idempotency key
        const transfer = await stripe.transfers.create(
          {
            amount: payout.currency_amount,
            currency: payout.currency.toLowerCase(),
            destination: stripeAccount.stripe_connect_account_id,
            description: `Peppercheck reward payout - ${payout.points_amount} points`,
            metadata: {
              payout_id: payout.id,
              user_id: payout.user_id,
            },
          },
          {
            idempotencyKey: `payout-${payout.id}`,
          },
        )

        // Mark payout as success
        await supabase
          .from("reward_payouts")
          .update({
            status: "success",
            stripe_transfer_id: transfer.id,
          })
          .eq("id", payout.id)

        // Deduct wallet balance and create ledger entry
        const { error: deductError } = await supabase.rpc(
          "deduct_reward_for_payout",
          {
            p_user_id: payout.user_id,
            p_amount: payout.points_amount,
            p_payout_id: payout.id,
          },
        )

        if (deductError) {
          // Transfer succeeded but deduct failed — needs manual reconciliation
          console.error(
            `CRITICAL: Deduct failed for payout ${payout.id} (transfer ${transfer.id}):`,
            deductError,
          )
        }

        successCount++
      } catch (error) {
        const errorMessage =
          error instanceof Error ? error.message : String(error)
        console.error(`Payout ${payout.id} failed:`, errorMessage)

        // Mark payout as failed
        await supabase
          .from("reward_payouts")
          .update({
            status: "failed",
            error_message: errorMessage.substring(0, 500),
          })
          .eq("id", payout.id)

        // Notify user of failed payout
        await supabase.rpc("notify_event", {
          p_user_id: payout.user_id,
          p_template_key: "notification_payout_failed",
          p_template_args: null,
          p_data: { payout_id: payout.id },
        })

        failCount++
      }
    }

    return new Response(
      JSON.stringify({
        processed: successCount + failCount,
        success: successCount,
        failed: failCount,
      }),
      { status: 200, headers: jsonHeaders },
    )
  } catch (error) {
    console.error("execute-pending-payouts error:", error)
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: jsonHeaders },
    )
  }
})
