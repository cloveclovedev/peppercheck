# Terms of Service: Age Restriction & Content Update

**Issue:** #295
**Date:** 2026-04-01

## Summary

Update the existing Terms of Service page with age restriction (18+), expanded prohibited conduct, dispute resolution process, and contact information. Add legal links to the Flutter app's profile screen. Update Play Store listing with ToS URL.

No in-app enforcement (onboarding ToS acceptance, Referee age confirmation) is included in this scope. Stripe Connect's identity verification serves as the safety net for Referee eligibility.

## Background & Decisions

- **Age restriction: 18+ unified.** IARC questionnaire automatically rates the app 18+ due to financial transaction features (wire transfers, purchase contracts). Since the Play Store enforces 18+ at the distribution level, the ToS reflects the same requirement. In the future, if Tasker-only usage is opened to younger users (13+), the ToS and IARC rating can be revisited.
- **Dispute resolution: lightweight approach.** As a sole proprietorship web service, a simple contact-first process is sufficient. No formal arbitration clause needed. The ToS states the platform's role in user-to-user disputes (best-effort mediation, no legal liability) and directs users to email for support.
- **Flutter link placement: new "Support" section.** A dedicated section titled "お問い合わせ" (Support/Contact) is added to the profile screen above the account actions section. This avoids overloading the existing account actions section and gives legal links appropriate visibility.

## Scope

### In scope

1. Webapp: Update ToS page content (EN + JA)
2. Flutter: Add Support section with legal/contact links to profile screen
3. Store listing: Add ToS URL to `store-listing/ja/full_description.txt`

### Out of scope

- In-app ToS acceptance during onboarding
- In-app age confirmation for Referee role
- Changes to IARC content rating
- Privacy policy content changes

## Design

### 1. Webapp — ToS Page Update

Update existing Terms of Service at `/[locale]/legal/terms`.

#### Section structure (8 → 10 sections)

| # | Key | Section | Change |
|---|-----|---------|--------|
| 1 | `intro` | Introduction | No change |
| 2 | `eligibility` | **Eligibility** | **New** |
| 3 | `service` | Service Description | No change |
| 4 | `subscription` | Subscription Terms | No change |
| 5 | `prohibited` | Prohibited Conduct | **Expanded** |
| 6 | `ip` | Intellectual Property | No change |
| 7 | `disclaimer` | Limitation of Liability | No change |
| 8 | `dispute` | **Dispute Resolution & Governing Law** | **Expanded** (replaces `law`) |
| 9 | `changes` | Modification of Terms | No change |
| 10 | `contact` | **Contact Us** | **New** |

#### New/changed section content

**Section 2 — Eligibility:**
- You must be at least 18 years old to use the Service
- By using the Service, you represent that you meet this age requirement
- JA: 本サービスのご利用は18歳以上の方に限ります

**Section 5 — Prohibited Conduct (additions):**
- Add items for inappropriate content in tasks, evidence, and comments:
  - Submit content that is obscene, harassing, defamatory, or otherwise objectionable
  - Upload evidence containing personally identifiable information of third parties without consent

**Section 8 — Dispute Resolution & Governing Law (replaces current Section 7):**
- Paragraph 1: For issues with the Service, contact us at the email listed in Section 10
- Paragraph 2: For disputes between users (e.g., task review disagreements), the platform will make best efforts to mediate, but is not legally responsible for resolving user-to-user disputes
- Paragraph 3: Governing law (Japan) and jurisdiction — carried over from existing Section 7

**Section 10 — Contact Us:**
- Support email address
- Same pattern as Privacy Policy's contact section

#### Files changed

- `peppercheck-webapp/messages/en.json` — `Terms` section
- `peppercheck-webapp/messages/ja.json` — `Terms` section
- `peppercheck-webapp/src/app/[locale]/legal/terms/page.tsx` — Add new sections, update section numbering
- Update `effectiveDate` to reflect the new effective date

### 2. Flutter — Support Section

Add a new `SupportSection` widget to the profile screen.

#### Widget: `SupportSection`

Location: `peppercheck_flutter/lib/features/profile/presentation/widgets/support_section.dart`

Uses `BaseSection` (existing common widget) with title from i18n.

Contents — three tappable list items:
| Label | Action |
|-------|--------|
| 利用規約 (Terms of Service) | Open `{WEB_URL}/ja/legal/terms` in external browser |
| プライバシーポリシー (Privacy Policy) | Open `{WEB_URL}/ja/legal/privacy` in external browser |
| お問い合わせ (Contact Us) | Open `mailto:{support email}` |

- URL base: reuse the `WEB_DASHBOARD_URL` env var pattern, or introduce a `WEB_BASE_URL` if the existing var includes `/dashboard`
- Locale: use the app's current locale to construct the URL path (`/en/legal/terms` or `/ja/legal/terms`)
- Uses `url_launcher` (already a project dependency)

#### Profile screen layout (updated order)

```
RefereeAvailabilitySection
RefereeBlockedDatesSection
SupportSection              ← NEW
AccountActionsSection
```

#### i18n

Add keys to `peppercheck_flutter/assets/i18n/ja.i18n.json`:

```json
"support": {
  "title": "お問い合わせ",
  "termsOfService": "利用規約",
  "privacyPolicy": "プライバシーポリシー",
  "contactUs": "お問い合わせ"
}
```

### 3. Play Store Listing

Append ToS URL to `store-listing/ja/full_description.txt`:

```
━━━━━━━━━━━━━━━━
【ご利用にあたって】
━━━━━━━━━━━━━━━━

・本アプリのご利用は18歳以上の方に限ります。
・利用規約: https://peppercheck.dev/ja/legal/terms
・プライバシーポリシー: https://peppercheck.dev/ja/legal/privacy
```

## Post-merge Manual Tasks

These are performed by the developer after the PR is merged:

| # | Task | Where | What |
|---|------|-------|------|
| B-1 | Play Store listing update | Google Play Console → Store listing | Copy updated `full_description.txt` content |
| B-2 | Content rating check | Google Play Console → Content rating | Confirm IARC 18+ is maintained |
| B-3 | Deploy verification | Cloudflare Dashboard / peppercheck.dev | Verify ToS page renders correctly after auto-deploy |
