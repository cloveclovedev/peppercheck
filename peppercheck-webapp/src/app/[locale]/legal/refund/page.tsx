import { Header } from '@/components/Header'
import { Footer } from '@/components/Footer'
import { ObfuscatedEmail } from '@/components/ObfuscatedEmail'
import { getTranslations } from 'next-intl/server'
import { createGenerateMetadata } from '@/lib/metadata'

export const generateMetadata = createGenerateMetadata('Refund')

export default async function RefundPage() {
  const t = await getTranslations('Refund')

  return (
    <div className="flex min-h-screen flex-col font-sans">
      <Header />

      <main className="mx-auto w-full max-w-[var(--max-content-width)] flex-1 px-6 py-12 md:py-24">
        <article className="mx-auto max-w-2xl">
          <h1 className="text-3xl font-extrabold tracking-tight text-[var(--color-heading)]">
            {t('title')}
          </h1>
          <p className="mt-2 text-sm text-[var(--color-text)] opacity-60">
            {t('effectiveDate')}
          </p>

          {/* 1. How to Cancel */}
          <section className="mt-12">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('cancellation.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">
              {t('cancellation.body')}
            </p>
          </section>

          {/* 2. Refund Policy */}
          <section className="mt-10">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('refund.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">
              {t('refund.body')}
            </p>
          </section>

          {/* 3. Exceptions */}
          <section className="mt-10">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('exceptions.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">
              {t('exceptions.body')}
            </p>
          </section>

          {/* 4. Contact */}
          <section className="mt-10">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('contact.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">
              {t('contact.body')}
            </p>
            <p className="mt-2 font-semibold text-[var(--color-heading)]">
              <ObfuscatedEmail />
            </p>
          </section>
        </article>
      </main>

      <Footer />
    </div>
  )
}
