import { Header } from '@/components/Header'
import { Footer } from '@/components/Footer'
import { Link } from '@/i18n/routing'
import { useTranslations } from 'next-intl'

const FEATURES = ['create', 'review', 'reward'] as const

export default function Home() {
  const t = useTranslations('HomePage')

  return (
    <div className="flex min-h-screen flex-col font-sans">
      <Header />

      <main className="mx-auto w-full max-w-[var(--max-content-width)] flex-1 px-6 py-12 md:py-24">
        {/* Hero */}
        <div className="flex flex-col items-center justify-center gap-6 text-center">
          <h1 className="text-4xl font-extrabold tracking-tight text-[var(--color-heading)] sm:text-5xl md:text-6xl">
            {t.rich('title', {
              br: () => <br />,
            })}
          </h1>
          <p className="max-w-xl text-lg text-[var(--color-text)] opacity-80">
            {t('subtitle')}
          </p>
        </div>

        {/* Features */}
        <div className="mx-auto mt-16 grid max-w-4xl gap-8 sm:grid-cols-3">
          {FEATURES.map((key) => (
            <div key={key} className="text-center">
              <h2 className="text-lg font-bold text-[var(--color-heading)]">
                {t(`features.${key}.heading`)}
              </h2>
              <p className="mt-2 text-[var(--color-text)] opacity-80">
                {t(`features.${key}.body`)}
              </p>
            </div>
          ))}
        </div>

        {/* CTA */}
        <div className="mt-12 flex justify-center">
          <Link
            href="/pricing"
            className="rounded-lg bg-[var(--color-heading)] px-8 py-3 font-semibold text-white hover:opacity-90"
          >
            {t('cta')}
          </Link>
        </div>
      </main>

      <Footer />
    </div>
  )
}
