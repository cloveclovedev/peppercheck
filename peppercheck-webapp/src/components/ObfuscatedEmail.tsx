'use client'

export function ObfuscatedEmail() {
  const user = 'hi'
  const domain = 'cloveclove.dev'
  const email = `${user}@${domain}`
  return (
    <a href={`mailto:${email}`} className="decoration-2 hover:underline">
      {email}
    </a>
  )
}
