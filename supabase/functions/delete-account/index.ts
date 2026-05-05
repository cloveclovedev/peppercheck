import 'jsr:@supabase/functions-js@^2/edge-runtime.d.ts'

import { createClient } from '@supabase/supabase-js'
import Stripe from 'stripe'
import { DeleteObjectsCommand, ListObjectsV2Command, S3Client } from '@aws-sdk/client-s3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const jsonHeaders = { ...corsHeaders, 'Content-Type': 'application/json' }

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { status: 405, headers: jsonHeaders },
    )
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
  const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY') ?? ''

  try {
    // 1. Authenticate user
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: jsonHeaders },
      )
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    })
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: jsonHeaders },
      )
    }

    const userId = user.id

    // Parse request body
    let force = false
    try {
      const body = await req.json()
      force = body.force === true
    } catch {
      // No body or invalid JSON — default force=false
    }

    // 2. Check pre-conditions
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey)

    // Use the user's own client (not admin) so auth.uid() works inside the function
    const { data: checkResult, error: checkError } = await supabase.rpc(
      'check_account_deletable',
    )

    if (checkError) {
      console.error('check_account_deletable failed:', checkError)
      return new Response(
        JSON.stringify({ error: 'Failed to check account status' }),
        { status: 500, headers: jsonHeaders },
      )
    }

    if (!checkResult.deletable) {
      return new Response(
        JSON.stringify({
          error: 'not_deletable',
          reasons: checkResult.reasons,
        }),
        { status: 200, headers: jsonHeaders },
      )
    }

    const stripe = new Stripe(stripeSecretKey, {
      apiVersion: '2025-11-17.clover',
    })

    // 3. Reward payout (if not force)
    if (!force) {
      const { data: wallet } = await supabaseAdmin
        .from('reward_wallets')
        .select('balance')
        .eq('user_id', userId)
        .maybeSingle()

      if (wallet && wallet.balance > 0) {
        // Get Connect account
        const { data: stripeAccount } = await supabaseAdmin
          .from('stripe_accounts')
          .select('stripe_connect_account_id, payouts_enabled')
          .eq('profile_id', userId)
          .maybeSingle()

        if (
          !stripeAccount?.stripe_connect_account_id ||
          !stripeAccount.payouts_enabled
        ) {
          return new Response(
            JSON.stringify({
              error: 'payout_failed',
              reward_balance: wallet.balance,
              message: 'No active Connect account for payout',
            }),
            { status: 200, headers: jsonHeaders },
          )
        }

        try {
          // Get exchange rate
          const { data: rate } = await supabaseAdmin
            .from('reward_exchange_rates')
            .select('rate_per_point')
            .eq('currency', 'JPY')
            .eq('active', true)
            .single()

          if (!rate) {
            throw new Error('No active exchange rate found')
          }

          const currencyAmount = wallet.balance * rate.rate_per_point
          const payoutId = crypto.randomUUID()

          // Create payout record
          const { error: insertError } = await supabaseAdmin
            .from('reward_payouts')
            .insert({
              id: payoutId,
              user_id: userId,
              points_amount: wallet.balance,
              currency: 'JPY',
              currency_amount: currencyAmount,
              rate_per_point: rate.rate_per_point,
              status: 'pending',
              batch_date: new Date().toISOString().split('T')[0],
            })

          if (insertError) throw insertError

          // Execute Stripe Transfer
          const transfer = await stripe.transfers.create(
            {
              amount: currencyAmount,
              currency: 'jpy',
              destination: stripeAccount.stripe_connect_account_id,
              description: `Account deletion payout - ${wallet.balance} points`,
              metadata: { payout_id: payoutId, user_id: userId },
            },
            { idempotencyKey: `deletion-payout-${payoutId}` },
          )

          // Mark payout success
          await supabaseAdmin
            .from('reward_payouts')
            .update({
              status: 'success',
              stripe_transfer_id: transfer.id,
            })
            .eq('id', payoutId)

          // Deduct wallet
          await supabaseAdmin.rpc('deduct_reward_for_payout', {
            p_user_id: userId,
            p_amount: wallet.balance,
            p_payout_id: payoutId,
          })
        } catch (payoutError) {
          const message = payoutError instanceof Error ? payoutError.message : String(payoutError)
          console.error('Payout failed:', message)
          return new Response(
            JSON.stringify({
              error: 'payout_failed',
              reward_balance: wallet.balance,
              message,
            }),
            { status: 200, headers: jsonHeaders },
          )
        }
      }
    }

    // 4. Cancel Stripe subscription (if exists)
    const { data: subscription } = await supabaseAdmin
      .from('user_subscriptions')
      .select('stripe_subscription_id, provider, status')
      .eq('user_id', userId)
      .maybeSingle()

    if (
      subscription?.stripe_subscription_id &&
      subscription.provider === 'stripe' &&
      subscription.status === 'active'
    ) {
      try {
        await stripe.subscriptions.cancel(
          subscription.stripe_subscription_id,
          { prorate: false },
        )
      } catch (subError) {
        // Log but don't block — subscription will expire naturally
        console.error('Subscription cancel failed:', subError)
      }
    }

    // 5. Deauthorize Stripe Connect (if exists)
    const { data: connectAccount } = await supabaseAdmin
      .from('stripe_accounts')
      .select('stripe_connect_account_id')
      .eq('profile_id', userId)
      .maybeSingle()

    if (connectAccount?.stripe_connect_account_id) {
      try {
        await stripe.accounts.del(connectAccount.stripe_connect_account_id)
      } catch (connectError) {
        // Log but don't block — account data will be CASCADE-deleted
        console.error('Connect deauthorize failed:', connectError)
      }
    }

    // 6. Delete avatar objects from R2 (best-effort)
    const cloudflareAccountId = Deno.env.get('CLOUDFLARE_ACCOUNT_ID')
    const r2AccessKeyId = Deno.env.get('R2_ACCESS_KEY_ID')
    const r2SecretAccessKey = Deno.env.get('R2_SECRET_ACCESS_KEY')
    const r2BucketName = Deno.env.get('R2_BUCKET_NAME')

    if (
      cloudflareAccountId &&
      r2AccessKeyId &&
      r2SecretAccessKey &&
      r2BucketName
    ) {
      try {
        const s3Client = new S3Client({
          region: 'auto',
          endpoint: `https://${cloudflareAccountId}.r2.cloudflarestorage.com`,
          credentials: {
            accessKeyId: r2AccessKeyId,
            secretAccessKey: r2SecretAccessKey,
          },
        })

        const list = await s3Client.send(
          new ListObjectsV2Command({
            Bucket: r2BucketName,
            Prefix: `avatar/${userId}/`,
          }),
        )

        if (list.Contents && list.Contents.length > 0) {
          await s3Client.send(
            new DeleteObjectsCommand({
              Bucket: r2BucketName,
              Delete: {
                Objects: list.Contents.map(({ Key }) => ({ Key: Key! })),
              },
            }),
          )
        }
      } catch (r2Error) {
        console.error('Avatar R2 cleanup failed:', r2Error)
      }
    } else {
      console.warn(
        'Skipping avatar R2 cleanup: R2 environment variables not configured',
      )
    }

    // 7. Delete auth user (CASCADE/SET NULL handles everything)
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(userId)

    if (deleteError) {
      console.error('User deletion failed:', deleteError)
      return new Response(
        JSON.stringify({ error: 'Failed to delete user account' }),
        { status: 500, headers: jsonHeaders },
      )
    }

    // 8. Success
    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: jsonHeaders },
    )
  } catch (error) {
    console.error('delete-account error:', error)
    const message = error instanceof Error ? error.message : String(error)
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: jsonHeaders },
    )
  }
})
