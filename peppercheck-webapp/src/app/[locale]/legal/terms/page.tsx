import { Header } from '@/components/Header'
import { Footer } from '@/components/Footer'
import { getTranslations } from 'next-intl/server'
import { createGenerateMetadata } from '@/lib/metadata'

export const generateMetadata = createGenerateMetadata('Terms')

export default async function TermsPage() {
  const t = await getTranslations('Terms')

  const prohibitedItems = [
    'abuse',
    'fraud',
    'interference',
    'scraping',
    'impersonation',
  ] as const

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

          {/* 1. Introduction */}
          <section className="mt-12">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('intro.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">{t('intro.body')}</p>
          </section>

          {/* 2. Service Description */}
          <section className="mt-10">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('service.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">{t('service.body')}</p>
          </section>

          {/* 3. Subscription Terms */}
          <section className="mt-10">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('subscription.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">
              {t('subscription.body')}
            </p>
          </section>

          {/* 4. Prohibited Conduct */}
          <section className="mt-10">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('prohibited.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">
              {t('prohibited.intro')}
            </p>
            <ul className="mt-3 list-disc space-y-1 pl-6 text-[var(--color-text)]">
              {prohibitedItems.map((key) => (
                <li key={key}>{t(`prohibited.items.${key}`)}</li>
              ))}
            </ul>
          </section>

          {/* 5. Intellectual Property */}
          <section className="mt-10">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('ip.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">{t('ip.body')}</p>
          </section>

          {/* 6. Limitation of Liability */}
          <section className="mt-10">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('disclaimer.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">
              {t('disclaimer.body')}
            </p>
          </section>

          {/* 7. Governing Law */}
          <section className="mt-10">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('law.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">{t('law.body')}</p>
          </section>

          {/* 8. Modification of Terms */}
          <section className="mt-10">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('changes.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">{t('changes.body')}</p>
          </section>
        </article>
      </main>

      <Footer />
    </div>
  )
}
