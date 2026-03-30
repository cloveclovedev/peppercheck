import 'jsr:@supabase/functions-js@^2/edge-runtime.d.ts'

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  try {
    const body = await req.json()
    console.log('Received Pub/Sub message:', JSON.stringify(body))
    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('Error processing RTDN:', error)
    // Always return 200 to prevent Pub/Sub infinite retries
    return new Response(JSON.stringify({ error: 'processing failed' }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  }
})
