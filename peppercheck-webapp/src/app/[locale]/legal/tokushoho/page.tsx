import { Header } from '@/components/Header'
import { Footer } from '@/components/Footer'
import { ObfuscatedEmail } from '@/components/ObfuscatedEmail'
import { getTranslations } from 'next-intl/server'
import { createGenerateMetadata } from '@/lib/metadata'
import { Link } from '@/i18n/routing'

export const generateMetadata = createGenerateMetadata('Tokushoho')

const ROWS = [
  'seller',
  'representative',
  'address',
  'phone',
  'contact',
  'price',
  'additionalFees',
  'payment',
  'paymentPeriod',
  'delivery',
  'cancellation',
] as const

export default async function TokushohoPage() {
  const t = await getTranslations('Tokushoho')

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
                    <Link
                      href="/pricing"
                      className="underline decoration-2 hover:opacity-80"
                    >
                      {t(`${key}.value`)}
                    </Link>
                  ) : key === 'cancellation' ? (
                    <Link
                      href="/legal/refund"
                      className="underline decoration-2 hover:opacity-80"
                    >
                      {t(`${key}.value`)}
                    </Link>
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
