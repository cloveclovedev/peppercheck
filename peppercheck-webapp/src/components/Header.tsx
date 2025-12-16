import Link from 'next/link';

export function Header() {
  return (
    <header className="site-header border-b border-[var(--color-text)] bg-[var(--color-background-light)] w-full relative z-50">
      <div className="mx-auto flex h-16 max-w-[calc(var(--max-content-width)+200px)] items-center justify-between px-4 sm:px-8">
        <Link href="/" className="font-sans text-lg font-extrabold tracking-tight text-[var(--color-text)] hover:no-underline">
          peppercheck
        </Link>
        
        <div className="flex items-center gap-2 text-sm font-bold tracking-widest text-[var(--color-text)]">
          <Link href="/en" className="hover:text-[var(--color-text)] hover:underline decoration-2">
            EN
          </Link>
          <span className="text-opacity-40 text-[var(--color-text)]">|</span>
          <Link href="/ja" className="hover:text-[var(--color-text)] hover:underline decoration-2">
            JP
          </Link>
        </div>
      </div>
    </header>
  );
}
