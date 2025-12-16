'use client'

import { Link, usePathname } from '@/i18n/routing'

export function Header() {
  const pathname = usePathname()

  return (
    <header className="site-header relative z-50 w-full border-b border-[var(--color-text)] bg-[var(--color-background-light)]">
      <div className="mx-auto flex h-16 max-w-[calc(var(--max-content-width)+200px)] items-center justify-between px-4 sm:px-8">
        <Link
          href="/"
          className="font-sans text-lg font-extrabold tracking-tight text-[var(--color-text)] hover:no-underline"
        >
          peppercheck
        </Link>

        <div className="flex items-center gap-2 text-sm font-bold tracking-widest text-[var(--color-text)]">
          <Link
            href={pathname}
            locale="en"
            className="decoration-2 hover:text-[var(--color-text)] hover:underline"
          >
            EN
          </Link>
          <span className="text-opacity-40 text-[var(--color-text)]">|</span>
          <Link
            href={pathname}
            locale="ja"
            className="decoration-2 hover:text-[var(--color-text)] hover:underline"
          >
            JP
          </Link>
        </div>
      </div>
    </header>
  )
}
