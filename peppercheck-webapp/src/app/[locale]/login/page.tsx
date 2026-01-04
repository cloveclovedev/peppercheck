'use client'

import { createClient } from '@/lib/supabase/client'
import { useState } from 'react'
import { Link } from '@/i18n/routing'
import { useLocale } from 'next-intl'
import { useSearchParams } from 'next/navigation'

export default function LoginPage() {
  const [loading, setLoading] = useState(false)
  const supabase = createClient()
  const locale = useLocale()
  const searchParams = useSearchParams()
  const next = searchParams.get('next')

  const handleGoogleLogin = async () => {
    setLoading(true)
    try {
      const redirectUrl = new URL(`${window.location.origin}/${locale}/auth/callback`)
      if (next) {
        redirectUrl.searchParams.set('next', next)
      }

      const { error } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo: redirectUrl.toString(),
        },
      })
      if (error) throw error
    } catch (error) {
      console.error('Error logging in:', error)
      alert('Error logging in')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className='flex min-h-screen items-center justify-center bg-gray-50 px-4 py-12 sm:px-6 lg:px-8'>
      <div className='w-full max-w-md space-y-8'>
        <div>
          <h2 className='mt-6 text-center text-3xl font-extrabold text-gray-900'>
            Sign in to your account
          </h2>
          <p className='mt-2 text-center text-sm text-gray-600'>
            Or{' '}
            <Link
              href='/pricing'
              className='font-medium text-indigo-600 hover:text-indigo-500'
            >
              check our pricing
            </Link>
          </p>
        </div>
        <div className='mt-8 space-y-6'>
          <button
            onClick={handleGoogleLogin}
            disabled={loading}
            className='group relative flex w-full justify-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 focus:outline-none disabled:opacity-50'
          >
            {loading ? 'Processing...' : 'Sign in with Google'}
          </button>
        </div>
      </div>
    </div>
  )
}
