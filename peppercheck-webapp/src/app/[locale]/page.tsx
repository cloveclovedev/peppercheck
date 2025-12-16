import { Header } from '@/components/Header'
import { Footer } from '@/components/Footer'

import { useTranslations } from 'next-intl'

export default function Home() {
  const t = useTranslations('HomePage')

  return (
    <div className="flex min-h-screen flex-col font-sans">
      <Header />

      <main className="mx-auto w-full max-w-[var(--max-content-width)] flex-1 px-6 py-12 md:py-24">
        {/* Placeholder for content sections */}
        <div className="flex min-h-[40vh] flex-col items-center justify-center gap-12 text-center">
          <h1 className="text-4xl font-extrabold tracking-tight text-[var(--color-heading)] sm:text-5xl md:text-6xl">
            {t.rich('title', {
              br: () => <br />,
            })}
          </h1>
          <p className="max-w-xl text-lg text-[var(--color-text)] opacity-80">
            {t('placeholder')}
          </p>
        </div>
      </main>

      <Footer />
    </div>
  )
}
