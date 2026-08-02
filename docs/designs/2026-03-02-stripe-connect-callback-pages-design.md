# Stripe Connect Callback Pages for flutter-webapp

## Context

The Hugo public-site (`peppercheck.com`) hosts two Stripe Connect onboarding callback pages (return and refresh) that the `payout-setup` edge function redirects users to after Stripe Connect onboarding. The public-site is being deprecated, so these pages need to be recreated in the Next.js webapp (`peppercheck.dev`).

`STRIPE_BILLING_RETURN_URL` exists in `.env.example` but is unused by any edge function — it will be removed.

## Scope

- Create 2 static pages in `peppercheck-webapp`: Connect onboarding return (success) and refresh (interrupted)
- Add EN/JA translations via next-intl
- Remove unused `STRIPE_BILLING_RETURN_URL` from `.env.example`

## Routing

```
peppercheck-webapp/src/app/[locale]/stripe/connect/
  return/page.tsx    — onboarding complete
  refresh/page.tsx   — onboarding interrupted
```

URLs:
- `/en/stripe/connect/return`, `/ja/stripe/connect/return`
- `/en/stripe/connect/refresh`, `/ja/stripe/connect/refresh`

## Page Characteristics

- No authentication required (user arrives from Stripe in a browser)
- Server Components using `getTranslations`
- Include shared `Header` and `Footer` components (same pattern as home page)
- Purely informational — no client-side interactivity

## Display Content

User-facing copy avoids technical terms like "Stripe Connect" or "onboarding" — it uses plain language about payout setup.

### return page (onboarding complete)

EN:
- Title: "Payout setup completed"
- Body: Your payout setup has been completed successfully. Please return to the Peppercheck app to confirm.
- Note: If additional information is required, please tap the setup button again and complete the necessary steps.
- Contact: hi@cloveclove.dev

JA:
- Title: "報酬受け取り設定が完了しました"
- Body: アプリケーションに戻り確認をお願いします。
- Note: 追加情報が求められる場合がありますので、その場合は再度設定ボタンから必要な操作を実施してください。
- Contact: hi@cloveclove.dev

### refresh page (onboarding interrupted)

EN:
- Title: "Payout setup did not complete successfully"
- Body: Please return to the app and restart the setup.
- Note: Any information you have already entered has been saved. You only need to provide the missing details.
- Contact: hi@cloveclove.dev

JA:
- Title: "報酬受け取り設定が正常に完了しませんでした"
- Body: アプリケーションに戻り再度設定を再開してください。
- Note: 入力済みの情報はStripeに保存済みです。
- Contact: hi@cloveclove.dev

## i18n Structure

Add `StripeConnect` namespace to `messages/en.json` and `messages/ja.json`:

```json
{
  "StripeConnect": {
    "return": {
      "title": "...",
      "description": "...",
      "note": "...",
      "contact": "... {email} ..."
    },
    "refresh": {
      "title": "...",
      "description": "...",
      "note": "...",
      "contact": "... {email} ..."
    }
  }
}
```

## Environment Variable Changes

- Remove `STRIPE_BILLING_RETURN_URL` from `supabase/functions/.env.example`
- Update comments on `STRIPE_ONBOARDING_RETURN_URL` and `STRIPE_ONBOARDING_REFRESH_URL` to reference webapp URL pattern
