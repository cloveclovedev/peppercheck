import { getTranslations } from 'next-intl/server'

export function createGenerateMetadata(namespace: string) {
  return async ({ params }: { params: Promise<{ locale: string }> }) => {
    const { locale } = await params
    const t = await getTranslations({ locale, namespace })
    return { title: t('title') }
  }
}
