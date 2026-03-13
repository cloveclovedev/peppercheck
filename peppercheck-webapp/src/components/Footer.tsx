'use client'

import { Link } from '@/i18n/routing'
import { useTranslations } from 'next-intl'

function ObfuscatedEmail() {
  const user = 'hi'
  const domain = 'cloveclove.dev'
  const email = `${user}@${domain}`
  return (
    <a href={`mailto:${email}`} className="decoration-2 hover:underline">
      {email}
    </a>
  )
}

export function Footer() {
  const t = useTranslations('Footer')
  return (
    <footer className="relative z-50 w-full border-t border-[var(--color-text)] bg-[var(--color-background-light)] py-12 text-sm font-semibold tracking-wide">
      <div className="mx-auto flex max-w-[var(--max-content-width)] flex-col items-start justify-between gap-6 px-6 md:flex-row md:items-start">
        {/* Left: Legal links */}
        <div className="flex flex-col gap-2">
          <Link href="/legal/terms" className="decoration-2 hover:underline">
            {t('terms')}
          </Link>
          <Link href="/legal/privacy" className="decoration-2 hover:underline">
            {t('privacy')}
          </Link>
          <Link href="/legal/tokushoho" className="decoration-2 hover:underline">
            {t('tokushoho')}
          </Link>
          <Link href="/legal/refund" className="decoration-2 hover:underline">
            {t('refund')}
          </Link>
        </div>

        {/* Right: Contact, X icon & Copyright */}
        <div className="flex flex-col items-start gap-4 md:items-end">
          <div className="flex flex-col items-start gap-2 md:items-end">
            <span>
              {t('contact')}: <ObfuscatedEmail />
            </span>
            <Link
              href="https://x.com/peppercheck_app"
              target="_blank"
              rel="noopener noreferrer"
              className="hover:opacity-80"
            >
              <svg
                viewBox="0 0 24 24"
                aria-hidden="true"
                className="h-5 w-5 fill-current"
              >
                <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
              </svg>
            </Link>
          </div>

          <div className="font-normal text-[var(--color-text)] opacity-80">
            {t('copyright')}
          </div>
        </div>
      </div>
    </footer>
  )
}
