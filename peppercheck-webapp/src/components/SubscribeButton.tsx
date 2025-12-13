'use client'

import { createClient } from '@/lib/supabase/client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'

export default function SubscribeButton(
  { planId, currency }: { planId: string; currency: string },
) {
  const [loading, setLoading] = useState(false)
  const router = useRouter()
  const supabase = createClient()

  const handleSubscribe = async () => {
    setLoading(true)

    // Check auth
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) {
      // Redirect to login
      router.push(`/login?next=/pricing`)
      setLoading(false)
      return
    }

    try {
      const { data, error } = await supabase.functions.invoke('create-stripe-checkout', {
        body: {
          plan_id: planId,
          currency: currency,
          success_url: `${window.location.origin}/dashboard?session_id={CHECKOUT_SESSION_ID}`,
          cancel_url: `${window.location.origin}/pricing`,
        },
      })

      if (error) {
        throw error
      }

      if (data?.url) {
        window.location.href = data.url
      } else {
        throw new Error('No Checkout URL returned')
      }
    } catch (error) {
      console.error('Checkout error:', error)
      alert('Failed to start checkout')
    } finally {
      setLoading(false)
    }
  }

  return (
    <button
      onClick={handleSubscribe}
      disabled={loading}
      className={`w-full py-2 px-4 rounded-md font-semibold text-white transition-colors
        ${loading ? 'bg-gray-400 cursor-not-allowed' : 'bg-blue-600 hover:bg-blue-700'}`}
    >
      {loading ? 'Processing...' : `Subscribe to ${planId}`}
    </button>
  )
}
