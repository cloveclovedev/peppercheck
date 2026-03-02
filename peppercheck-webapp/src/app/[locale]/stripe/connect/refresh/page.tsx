import { Header } from '@/components/Header'
import { Footer } from '@/components/Footer'
import { getTranslations } from 'next-intl/server'

const CONTACT_EMAIL = 'hi@cloveclove.dev'

export default async function StripeConnectRefreshPage() {
  const t = await getTranslations('StripeConnect.refresh')

  return (
    <div className="flex min-h-screen flex-col font-sans">
      <Header />

      <main className="mx-auto w-full max-w-[var(--max-content-width)] flex-1 px-6 py-12 md:py-24">
        <div className="mx-auto max-w-2xl">
          <h1 className="text-3xl font-extrabold tracking-tight text-[var(--color-heading)]">
            {t('title')}
          </h1>
          <p className="mt-6 text-lg text-[var(--color-text)]">
            {t('description')}
          </p>
          <p className="mt-4 text-[var(--color-text)] opacity-80">
            {t('note')}
          </p>
          <p className="mt-8 text-sm text-[var(--color-text)] opacity-60">
            {t('contact', { email: CONTACT_EMAIL })}
          </p>
        </div>
      </main>

      <Footer />
    </div>
  )
}
