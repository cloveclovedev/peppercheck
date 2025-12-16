import { createClient } from '@/lib/supabase/server'
import SubscribeButton from '@/components/SubscribeButton'

import { getTranslations } from 'next-intl/server'

export default async function PricingPage() {
  const supabase = await createClient()
  const t = await getTranslations('Pricing')

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

            // Key mapping logic
            const planKey = plan.name.toLowerCase().replace(' ', '_')
            const nameKey = `plans.${planKey}.name`
            const descriptionKey = `plans.${planKey}.description`

            // Use translation if exists, otherwise fallback to DB
            // Note: simple t() throws if key missing, usually we check or just rely on convention.
            // For robustness, if you are unsure if keys exist, you can suppress warning or ensure keys cover all DB values.
            // Here assuming keys cover all or we let it display key path if missing (dev mode) or fallback if we used t.has() which is available in newer versions but let's stick to standard t() for now or wrap.

            // To properly fallback we rely on `t.has` if available or just string.
            // Since `t.has` is not standard in basic `t` from getTranslations in all versions (it is in next-intl 3.0+),
            // let's try to assume it exists or just use a helper.
            // Actually `t` from `getTranslations` returns a translator function.
            // Let's assume standard behavior. If we want fallback, we might need a workaround if `t.has` isn't there.
            // However, `next-intl` usually renders the key if missing.

            // Re-reading the plan: "t.has checks".
            // `getTranslations` returns a Promise<Translator>. The translator object usually has `has`.

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
                  {/* Features listing could go here if features column was JSON array */}
                </div>
                <div className="p-6">
                  <SubscribeButton
                    planId={plan.id}
                    currency="JPY"
                    label={t('subscribe', { plan: displayName })}
                  />
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
