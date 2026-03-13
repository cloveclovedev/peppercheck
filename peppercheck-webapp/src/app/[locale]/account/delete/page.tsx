'use client'

import { createClient } from '@/lib/supabase/client'
import { useState, useEffect } from 'react'
import { useTranslations } from 'next-intl'

type DeletionState =
  | { step: 'loading' }
  | { step: 'blocked'; message: string }
  | { step: 'confirm' }
  | { step: 'final-confirm' }
  | { step: 'payout-failed'; amount: number }
  | { step: 'deleting' }
  | { step: 'deleted' }
  | { step: 'error'; message: string }

export default function DeleteAccountPage() {
  const t = useTranslations('AccountDelete')
  const supabase = createClient()
  const [state, setState] = useState<DeletionState>({ step: 'loading' })

  useEffect(() => {
    checkDeletable()
  }, [])

  async function checkDeletable() {
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser()
      if (!user) return

      const { data, error } = await supabase.rpc('check_account_deletable')

      if (error) throw error

      if (data.deletable) {
        setState({ step: 'confirm' })
      } else {
        setState({ step: 'blocked', message: t('blocked') })
      }
    } catch {
      setState({ step: 'error', message: t('error') })
    }
  }

  async function executeDelete(force: boolean) {
    setState({ step: 'deleting' })

    try {
      const { data: result, error } = await supabase.functions.invoke(
        'delete-account',
        { body: { force } },
      )

      if (error) throw error

      if (result.success) {
        await supabase.auth.signOut()
        setState({ step: 'deleted' })
        return
      }

      if (result.error === 'not_deletable') {
        setState({ step: 'blocked', message: t('blocked') })
        return
      }

      if (result.error === 'payout_failed') {
        setState({ step: 'payout-failed', amount: result.reward_balance })
        return
      }

      throw new Error(result.error || 'Unknown error')
    } catch {
      setState({ step: 'error', message: t('error') })
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-gray-50 px-4 py-12">
      <div className="w-full max-w-md space-y-6 rounded-lg bg-white p-8 shadow">
        <h1 className="text-2xl font-bold text-gray-900">{t('title')}</h1>

        {state.step === 'loading' && (
          <p className="text-gray-500">Loading...</p>
        )}

        {state.step === 'blocked' && (
          <p className="text-red-600">{state.message}</p>
        )}

        {state.step === 'confirm' && (
          <>
            <div className="space-y-3 text-sm text-gray-700">
              <p className="font-medium">{t('description')}</p>
              <p>{t('deletedItems')}</p>
              <p className="font-medium">{t('anonymizedLabel')}</p>
              <p>{t('anonymizedItems')}</p>
              <p>{t('retainedLabel')}</p>
              <p className="text-amber-600">{t('iapNotice')}</p>
            </div>
            <div className="flex gap-3">
              <button
                onClick={() => setState({ step: 'final-confirm' })}
                className="rounded-md bg-red-600 px-4 py-2 text-sm font-medium text-white hover:bg-red-700"
              >
                {t('deleteButton')}
              </button>
              <button
                onClick={() => window.history.back()}
                className="rounded-md border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
              >
                {t('cancelButton')}
              </button>
            </div>
          </>
        )}

        {state.step === 'final-confirm' && (
          <>
            <p className="font-medium text-red-600">{t('finalWarning')}</p>
            <div className="flex gap-3">
              <button
                onClick={() => executeDelete(false)}
                className="rounded-md bg-red-600 px-4 py-2 text-sm font-medium text-white hover:bg-red-700"
              >
                {t('deleteButton')}
              </button>
              <button
                onClick={() => setState({ step: 'confirm' })}
                className="rounded-md border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
              >
                {t('cancelButton')}
              </button>
            </div>
          </>
        )}

        {state.step === 'payout-failed' && (
          <>
            <p className="text-amber-600">
              {t('payoutFailed', { amount: state.amount })}
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => executeDelete(true)}
                className="rounded-md bg-red-600 px-4 py-2 text-sm font-medium text-white hover:bg-red-700"
              >
                {t('deleteButton')}
              </button>
              <button
                onClick={() => setState({ step: 'confirm' })}
                className="rounded-md border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
              >
                {t('cancelButton')}
              </button>
            </div>
          </>
        )}

        {state.step === 'deleting' && (
          <p className="text-gray-500">Deleting account...</p>
        )}

        {state.step === 'deleted' && (
          <p className="text-green-600">{t('deletedMessage')}</p>
        )}

        {state.step === 'error' && (
          <>
            <p className="text-red-600">{state.message}</p>
            <button
              onClick={checkDeletable}
              className="rounded-md border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
            >
              Retry
            </button>
          </>
        )}
      </div>
    </div>
  )
}
