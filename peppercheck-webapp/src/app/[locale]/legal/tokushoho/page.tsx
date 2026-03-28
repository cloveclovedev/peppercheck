import { Header } from '@/components/Header'
import { Footer } from '@/components/Footer'
import { ObfuscatedEmail } from '@/components/ObfuscatedEmail'
import { getTranslations } from 'next-intl/server'
import { createGenerateMetadata } from '@/lib/metadata'
import { Link } from '@/i18n/routing'
import { createClient } from '@/lib/supabase/server'

export const generateMetadata = createGenerateMetadata('Tokushoho')

const ROWS = [
  'seller',
  'address',
  'phone',
  'contact',
  'representative',
  'additionalFees',
  'cancellation',
  'delivery',
  'payment',
  'paymentPeriod',
  'price',
  'environment',
] as const

export default async function TokushohoPage() {
  const t = await getTranslations('Tokushoho')
  const tPricing = await getTranslations('Pricing')

  const supabase = await createClient()
  const { data: plans } = await supabase
    .from('subscription_plans')
    .select('*, prices:subscription_plan_prices(*)')
    .eq('is_active', true)
    .order('monthly_points')

  const priceLines = plans
    ?.map((plan) => {
      const price = plan.prices.find(
        (p: { provider: string; currency_code: string }) =>
          p.provider === 'stripe' && p.currency_code === 'JPY',
      )
      if (!price) return null
      const planKey = plan.name.toLowerCase().replace(' ', '_')
      const name = tPricing.has(`plans.${planKey}.name`)
        ? tPricing(`plans.${planKey}.name`)
        : plan.name
      return `${name} ¥${price.amount_minor.toLocaleString()}${t('price.perMonth')}`
    })
    .filter(Boolean)

  return (
    <div className="flex min-h-screen flex-col font-sans">
      <Header />

      <main className="mx-auto w-full max-w-[var(--max-content-width)] flex-1 px-6 py-12 md:py-24">
        <article className="mx-auto max-w-2xl">
          <h1 className="text-3xl font-extrabold tracking-tight text-[var(--color-heading)]">
            {t('title')}
          </h1>

          <dl className="mt-12 divide-y divide-gray-200">
            {ROWS.map((key) => (
              <div
                key={key}
                className="flex flex-col gap-1 py-4 sm:flex-row sm:gap-4"
              >
                <dt className="w-48 shrink-0 font-semibold text-[var(--color-heading)]">
                  {t(`${key}.label`)}
                </dt>
                <dd className="text-[var(--color-text)]">
                  {key === 'contact' ? (
                    <ObfuscatedEmail />
                  ) : key === 'price' ? (
                    <div className="space-y-2">
                      <p>
                        {priceLines?.join('、')}
                        {t('price.taxIncluded')}
                      </p>
                      <Link
                        href="/pricing"
                        className="block text-sm underline decoration-2 hover:opacity-80"
                      >
                        {t('price.details')}
                      </Link>
                    </div>
                  ) : key === 'cancellation' ? (
                    <div className="space-y-4">
                      <div>
                        <p className="font-semibold">
                          {t(`${key}.normalHeading`)}
                        </p>
                        <p className="mt-1">{t(`${key}.normalBody`)}</p>
                      </div>
                      <div>
                        <p className="font-semibold">
                          {t(`${key}.defectHeading`)}
                        </p>
                        <p className="mt-1">{t(`${key}.defectBody`)}</p>
                      </div>
                      <Link
                        href="/legal/refund"
                        className="block text-sm underline decoration-2 hover:opacity-80"
                      >
                        {t(`${key}.details`)}
                      </Link>
                    </div>
                  ) : (
                    t(`${key}.value`)
                  )}
                </dd>
              </div>
            ))}
          </dl>
        </article>
      </main>

      <Footer />
    </div>
  )
}
