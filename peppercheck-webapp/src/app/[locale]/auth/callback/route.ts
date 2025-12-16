import { createClient } from '@/lib/supabase/server'
import { NextResponse } from 'next/server'

export async function GET(request: Request, { params }: { params: Promise<{ locale: string }> }) {
  const { searchParams, origin } = new URL(request.url)
  const code = searchParams.get('code')
  // if "next" is in param, use it as the redirect URL
  const next = searchParams.get('next') ?? '/dashboard'
  const { locale } = await params

  if (code) {
    const supabase = await createClient()
    const { error } = await supabase.auth.exchangeCodeForSession(code)
    if (!error) {
      // Ensure 'next' starts with / if it doesn't, and prepend locale if 'next' is not absolute
      // Simplest: construct /locale/next
      const cleanNext = next.startsWith('/') ? next : `/${next}`
      return NextResponse.redirect(`${origin}/${locale}${cleanNext}`)
    }
  }

  // return the user to an error page with instructions
  return NextResponse.redirect(`${origin}/${locale}/auth/auth-code-error`)
}
