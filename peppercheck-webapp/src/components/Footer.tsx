import Link from 'next/link';

export function Footer() {
  return (
    <footer className="w-full border-t border-[var(--color-text)] bg-[var(--color-background-light)] py-12 text-sm font-semibold tracking-wide relative z-50">
      <div className="mx-auto max-w-[var(--max-content-width)] px-6 flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
        
        {/* Left: Terms & Privacy */}
        <div className="flex flex-col gap-2">
          <Link href="#" className="hover:underline decoration-2">
            Terms of Service
          </Link>
          <Link href="#" className="hover:underline decoration-2">
            Privacy Policy
          </Link>
        </div>

        {/* Right: X icon & Copyright */}
        <div className="flex flex-col items-start md:items-end gap-4">
          <Link href="https://x.com/peppercheck_app" target="_blank" rel="noopener noreferrer" className="hover:opacity-80">
             {/* Simple X Logo SVG */}
            <svg viewBox="0 0 24 24" aria-hidden="true" className="h-5 w-5 fill-current">
              <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
            </svg>
          </Link>
          
          <div className="text-[var(--color-text)] opacity-80 font-normal">
            © 2024 CloveClove, Inc.
          </div>
        </div>

      </div>
    </footer>
  );
}
