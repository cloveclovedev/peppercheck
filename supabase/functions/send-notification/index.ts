// Setup type definitions for built-in Supabase Runtime APIs
import 'jsr:@supabase/functions-js/edge-runtime.d.ts'

import { createClient } from '@supabase/supabase-js'
import admin from 'firebase-admin'

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const firebaseServiceAccount = Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? ''

if (!supabaseUrl || !supabaseServiceRoleKey) {
  console.warn('Supabase service credentials missing.')
}

if (!firebaseServiceAccount) {
  console.warn('FIREBASE_SERVICE_ACCOUNT is missing.')
}

// Initialize Firebase Admin
try {
  if (firebaseServiceAccount && admin.apps.length === 0) {
    const serviceAccount = JSON.parse(firebaseServiceAccount)
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    })
  }
} catch (e) {
  console.error('Failed to initialize Firebase Admin:', e)
}

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface NotificationPayload {
  user_ids: string[]
  notification: {
    title_loc_key: string
    title_loc_args?: string[]
    body_loc_key: string
    body_loc_args?: string[]
    data?: Record<string, string>
  }
}

Deno.serve(async (req) => {
  console.log('[send-notification] Request received:', req.method, req.url)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  try {
    const payload: NotificationPayload = await req.json()
    const { user_ids, notification } = payload

    if (!user_ids || user_ids.length === 0) {
      return new Response(JSON.stringify({ message: 'No user_ids provided' }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Fetch tokens from DB. Linking on user_id as per schema.
    const { data: tokensData, error: dbError } = await supabase
      .from('user_fcm_tokens')
      .select('token, user_id')
      .in('user_id', user_ids)

    if (dbError) {
      console.error('Database error fetching tokens:', dbError)
      throw dbError
    }

    if (!tokensData || tokensData.length === 0) {
      console.log('No tokens found for provided user_ids')
      return new Response(
        JSON.stringify({ message: 'No tokens found', successCount: 0, failureCount: 0 }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // Deduplicate tokens
    const tokens = [...new Set(tokensData.map((t) => t.token))]

    if (tokens.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No valid tokens found', successCount: 0, failureCount: 0 }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // Construct message
    // Best practice for localization: Use platform-specific overrides (Android/APNs) with loc-keys.
    const message: admin.messaging.MulticastMessage = {
      tokens: tokens,
      data: notification.data ?? {},
      android: {
        priority: 'high',
        notification: {
          titleLocKey: notification.title_loc_key,
          titleLocArgs: notification.title_loc_args || [],
          bodyLocKey: notification.body_loc_key,
          bodyLocArgs: notification.body_loc_args || [],
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              'title-loc-key': notification.title_loc_key,
              'title-loc-args': notification.title_loc_args || [],
              'loc-key': notification.body_loc_key,
              'loc-args': notification.body_loc_args || [],
            },
            sound: 'default',
          },
        },
      },
    }

    if (admin.apps.length === 0) {
      throw new Error('Firebase Admin not initialized (missing service account?)')
    }

    const response = await admin.messaging().sendEachForMulticast(message)

    console.log('FCM Send Response:', JSON.stringify(response))

    // Handle invalid tokens (cleanup)
    const tokensToRemove: string[] = []
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        const err = resp.error
        if (
          err?.code === 'messaging/invalid-registration-token' ||
          err?.code === 'messaging/registration-token-not-registered'
        ) {
          tokensToRemove.push(tokens[idx])
        }
      }
    })

    if (tokensToRemove.length > 0) {
      await supabase.from('user_fcm_tokens').delete().in('token', tokensToRemove)
      console.log(`Removed ${tokensToRemove.length} invalid tokens`)
    }

    return new Response(
      JSON.stringify({
        success: true,
        successCount: response.successCount,
        failureCount: response.failureCount,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (error) {
    console.error('Error sending notification:', error)
    return new Response(JSON.stringify({ error: 'Internal Server Error', details: error }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
