# Stripe Activation Webapp Preparation Design

Related: [Release: Migrate Stripe integration to production (#292)](https://github.com/mkuri/peppercheck/issues/292)

## Overview

Prepare the peppercheck.dev webapp with the minimum pages required to pass Stripe account activation review. This covers service description, legal pages (ToS, Tokushoho, Refund Policy), and contact information — all required by Stripe and Japanese law before going live.

## Scope

This design covers only the webapp page additions for Stripe activation (Issue #292, Step 2). It does NOT cover Stripe Dashboard configuration, API key switching, production testing, or other steps in the issue.

## Pages

### New Routes

| Route | Page | Auth Required |
|-------|------|---------------|
| `/[locale]/legal/terms` | Terms of Service (利用規約) | No |
| `/[locale]/legal/tokushoho` | 特定商取引法に基づく表記 | No |
| `/[locale]/legal/refund` | Refund & Cancellation Policy (返金・キャンセルポリシー) | No |

### Moved Routes

| From | To |
|------|----|
| `/[locale]/privacy` | `/[locale]/legal/privacy` |

All legal pages are grouped under `/legal/` for consistency.

### Modified Pages

| Route | Change |
|-------|--------|
| `/[locale]/` (Home) | Add concise service description (text-only, no images) |
| Footer component | Add links to all legal pages, add obfuscated mailto link |

## Content Details

### Home Page Enhancement

The home page currently uses `useTranslations` (client component). Add a minimal service description section:
- 3–4 key features of peppercheck listed as text
- CTA button linking to `/pricing`
- No images (to be added in a future iteration in a separate chat)

### Terms of Service (`/legal/terms`)

Covers:
- Service usage rules
- Subscription terms (billing cycle, auto-renewal)
- Prohibited conduct
- Intellectual property
- Limitation of liability / disclaimer
- Governing law (Japanese law)
- Modification of terms

### Tokushoho (`/legal/tokushoho`)

Required disclosure items under Japanese Specified Commercial Transactions Act, displayed in table format:
- Seller name (販売業者)
- Representative (代表者)
- Address (所在地)
- Contact (連絡先) — obfuscated email
- Service price (販売価格) — link to `/pricing`
- Payment method (支払方法) — credit card via Stripe
- Service delivery timing (提供時期)
- Cancellation/refund conditions (解約・返金条件) — link to `/legal/refund`

### Refund & Cancellation Policy (`/legal/refund`)

Covers:
- How to cancel a subscription (via app or Customer Portal)
- Access continues until current billing period ends
- No prorated refunds (principle)
- Exceptional refund conditions (if any)
- Contact for refund inquiries

## Implementation

### i18n (next-intl)

All page content managed via translation JSON files, following the existing Privacy Policy page pattern:
- Add namespaces: `Terms`, `Tokushoho`, `Refund`, `HomePage` (extend existing)
- Files: `messages/en.json`, `messages/ja.json`
- Japanese content is the authoritative version; English is a courtesy translation

### Page Components

Each legal page is a server component (`page.tsx`) using `getTranslations()`, with `createGenerateMetadata()` for HTML title tags. Same pattern as the existing `/privacy` page.

### Footer Updates

Footer is a client component using `useTranslations`. Changes:
- Fix ToS link: `href="#"` → `/legal/terms`
- Update Privacy link: `/privacy` → `/legal/privacy`
- Add links: Tokushoho, Refund Policy
- Add obfuscated contact email: JS concatenation (`'hi' + '@' + 'cloveclove.dev'`) in a client-side `<a>` tag with `mailto:` href constructed on render

### Pricing Page

Already implemented. No changes needed — fetches plans from DB, displays JPY prices, has SubscribeButton.

## Out of Scope

- Home page visual design / images (separate future iteration)
- Contact form or dedicated contact page
- Card brand logos (Visa, Mastercard etc.) — can be added to footer or pricing page later if Stripe review requires it
- Business address on non-Tokushoho pages — disclosed on Tokushoho page, sufficient for Stripe review
- HTTPS enforcement — already handled by Cloudflare
- FAQ / Help Center
- Stripe Dashboard configuration
- Production API key switching
- Webhook setup
