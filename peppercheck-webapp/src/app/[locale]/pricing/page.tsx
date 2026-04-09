import { createClient } from '@/lib/supabase/server'
import SubscribeButton from '@/components/SubscribeButton'

import { getTranslations } from 'next-intl/server'

export default async function PricingPage() {
  const supabase = await createClient()
  const t = await getTranslations('Pricing')

  // Check if current user has an active subscription
  const {
    data: { user },
  } = await supabase.auth.getUser()

  let currentSubscription: {
    plan_id: string
    provider: string | null
    status: string
  } | null = null

  if (user) {
    const { data } = await supabase
      .from('user_subscriptions')
      .select('plan_id, provider, status')
      .eq('user_id', user.id)
      .in('status', ['active', 'trialing', 'paused', 'past_due'])
      .maybeSingle()
    currentSubscription = data
  }

  // Fetch plans with prices (Stripe & JPY only for this demo)
  const { data: plans } = await supabase
    .from('subscription_plans')
    .select('*, prices:subscription_plan_prices(*)')
    .eq('is_active', true)
    .order('monthly_points') // Sort by points roughly maps to tiers

  return (
    <div className="min-h-screen bg-gray-50 px-4 py-12 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-7xl">
        <div className="text-center">
          <h2 className="text-3xl font-extrabold text-gray-900 sm:text-4xl">
            {t('title')}
          </h2>
          <p className="mt-4 text-xl text-gray-600">{t('subtitle')}</p>
        </div>

        {currentSubscription &&
          (() => {
            const matchedPlan = plans?.find(
              (p) => p.id === currentSubscription.plan_id,
            )
            const currentPlanDisplay = (() => {
              if (matchedPlan) {
                const planKey = matchedPlan.name.toLowerCase().replace(' ', '_')
                const nameKey = `plans.${planKey}.name`
                return t.has(nameKey) ? t(nameKey) : matchedPlan.name
              }
              return currentSubscription.plan_id
            })()
            const providerDisplay =
              currentSubscription.provider === 'google'
                ? 'Google Play'
                : currentSubscription.provider === 'stripe'
                  ? 'Stripe'
                  : (currentSubscription.provider ?? 'unknown')
            return (
              <div className="mx-auto mt-8 max-w-md rounded-lg border border-green-200 bg-green-50 p-4 text-center">
                <p className="text-sm font-medium text-green-800">
                  {t('currentPlan', {
                    plan: currentPlanDisplay,
                    provider: providerDisplay,
                  })}
                </p>
              </div>
            )
          })()}

        <div className="mt-12 space-y-4 sm:mt-16 sm:grid sm:grid-cols-2 sm:gap-6 sm:space-y-0 lg:mx-auto lg:max-w-4xl xl:mx-0 xl:max-w-none xl:grid-cols-3">
          {plans?.map((plan) => {
            // Find the Stripe price (assuming JPY or USD default, preferably JPY)
            const price = plan.prices.find(
              (p: {
                provider: string
                currency_code: string
                amount_minor: number
              }) => p.provider === 'stripe' && p.currency_code === 'JPY',
            )

            if (!price) return null // Skip plans without Stripe price

            const planKey = plan.name.toLowerCase().replace(' ', '_')
            const nameKey = `plans.${planKey}.name`
            const descriptionKey = `plans.${planKey}.description`

            const displayName = t.has(nameKey) ? t(nameKey) : plan.name
            const displayDesc = t.has(descriptionKey)
              ? t(descriptionKey, { points: plan.monthly_points })
              : `Includes ${plan.monthly_points} points / month`

            return (
              <div
                key={plan.id}
                className="flex flex-col divide-y divide-gray-200 rounded-lg border border-gray-200 bg-white shadow-sm"
              >
                <div className="flex-1 p-6">
                  <h3 className="text-lg leading-6 font-medium text-gray-900">
                    {displayName}
                  </h3>
                  <p className="mt-4 text-sm text-gray-500">{displayDesc}</p>
                  <p className="mt-8">
                    <span className="text-4xl font-extrabold text-gray-900">
                      ¥{price.amount_minor}
                    </span>
                    <span className="text-base font-medium text-gray-500">
                      {t('month')}
                    </span>
                  </p>
                </div>
                <div className="p-6">
                  {currentSubscription ? (
                    <p className="text-center text-sm text-gray-500">
                      {plan.id === currentSubscription.plan_id
                        ? t('activePlan')
                        : t('switchPlanNotAvailable')}
                    </p>
                  ) : (
                    <SubscribeButton
                      planId={plan.id}
                      currency="JPY"
                      label={t('subscribe', { plan: displayName })}
                    />
                  )}
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
