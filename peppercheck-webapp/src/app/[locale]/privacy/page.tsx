import { Header } from '@/components/Header'
import { Footer } from '@/components/Footer'
import { getTranslations } from 'next-intl/server'

export default async function PrivacyPolicyPage() {
  const t = await getTranslations('Privacy')

  const collectCategories = ['account', 'task', 'payment', 'device', 'usage'] as const
  const purposeItems = ['auth', 'service', 'payment', 'notification', 'support', 'safety'] as const
  const thirdParties = ['google', 'stripe', 'firebase', 'supabase'] as const
  const rightsItems = ['access', 'correction', 'deletion', 'withdrawal'] as const

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

          {/* 1. Operator */}
          <section className="mt-12">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('operator.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">{t('operator.body')}</p>
          </section>

          {/* 2. Information We Collect */}
          <section className="mt-10">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('collect.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">{t('collect.intro')}</p>
            <dl className="mt-4 space-y-4">
              {collectCategories.map((key) => (
                <div key={key}>
                  <dt className="font-semibold text-[var(--color-heading)]">
                    {t(`collect.${key}.heading`)}
                  </dt>
                  <dd className="mt-1 text-[var(--color-text)]">
                    {t(`collect.${key}.body`)}
                  </dd>
                </div>
              ))}
            </dl>
          </section>

          {/* 3. Purpose of Use */}
          <section className="mt-10">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('purpose.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">{t('purpose.intro')}</p>
            <ul className="mt-3 list-disc space-y-1 pl-6 text-[var(--color-text)]">
              {purposeItems.map((key) => (
                <li key={key}>{t(`purpose.items.${key}`)}</li>
              ))}
            </ul>
          </section>

          {/* 4. Third-Party Services */}
          <section className="mt-10">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('thirdParty.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">{t('thirdParty.intro')}</p>
            <dl className="mt-4 space-y-4">
              {thirdParties.map((key) => (
                <div key={key}>
                  <dt className="font-semibold text-[var(--color-heading)]">
                    {t(`thirdParty.${key}.name`)}
                  </dt>
                  <dd className="mt-1 text-[var(--color-text)]">
                    {t(`thirdParty.${key}.body`)}
                  </dd>
                </div>
              ))}
            </dl>
          </section>

          {/* 5. Data Storage and Security */}
          <section className="mt-10">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('security.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">{t('security.body')}</p>
          </section>

          {/* 6. Data Retention */}
          <section className="mt-10">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('retention.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">{t('retention.body')}</p>
          </section>

          {/* 7. Your Rights */}
          <section className="mt-10">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('rights.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">{t('rights.intro')}</p>
            <ul className="mt-3 list-disc space-y-1 pl-6 text-[var(--color-text)]">
              {rightsItems.map((key) => (
                <li key={key}>{t(`rights.items.${key}`)}</li>
              ))}
            </ul>
            <p className="mt-3 text-[var(--color-text)]">{t('rights.howTo')}</p>
          </section>

          {/* 8. Children's Privacy */}
          <section className="mt-10">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('children.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">{t('children.body')}</p>
          </section>

          {/* 9. Changes to This Policy */}
          <section className="mt-10">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('changes.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">{t('changes.body')}</p>
          </section>

          {/* 10. Contact */}
          <section className="mt-10">
            <h2 className="text-xl font-bold text-[var(--color-heading)]">
              {t('contact.heading')}
            </h2>
            <p className="mt-3 text-[var(--color-text)]">{t('contact.body')}</p>
            <p className="mt-2 font-semibold text-[var(--color-heading)]">
              <a href={`mailto:${t('contact.email')}`} className="underline decoration-2">
                {t('contact.email')}
              </a>
            </p>
          </section>
        </article>
      </main>

      <Footer />
    </div>
  )
}
