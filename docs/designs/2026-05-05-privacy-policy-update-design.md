# Privacy Policy Update — Align with Current Implementation

**Date:** 2026-05-05

## Problem

The webapp privacy policy at `peppercheck-webapp/src/app/[locale]/legal/privacy/page.tsx` (effective 2026-03-09) has drifted from the current implementation. The following gaps exist:

1. **IAP not disclosed.** The `thirdParty` section lists `google / stripe / firebase / supabase`, but subscriptions are now IAP-only (Apple App Store / Google Play Billing). The Stripe entry over-broadly claims "決済処理およびレフェリーへの報酬支払い", which only the payout half is still true. Stripe is now Connect-only.
2. **Anonymized retention is not disclosed.** Account deletion uses `ON DELETE SET NULL` for tasks, judgements, ratings, and reward payouts — meaning task content and evaluation history are kept (anonymized) after deletion. The `AccountDelete` UI tells users this; the privacy policy does not.
3. **Asset retention period is not disclosed.** Evidence image files are stored on Cloudflare R2. Auto-deletion on `due_date + 90 days` is planned but not yet implemented; there is no privacy disclosure.
4. **Avatar deletion is not disclosed and not implemented.** Avatar files in R2 currently survive account deletion because R2 is not subject to Postgres CASCADE.
5. **Age requirement is inconsistent.** Terms (eligibility) requires 18+; privacy policy section 8 says "13歳未満を対象としていません" (a US COPPA-style clause not relevant here).
6. **Operator data access is not disclosed.** Section 5 covers technical security only. Best practice for non-E2EE services is to disclose that the operator can access user data for support, troubleshooting, legal compliance, and abuse investigation.
7. **Card data clause is overly broad.** `collect.payment` lists "カードブランド・下4桁、カード有効期限". The columns `stripe_accounts.pm_brand / pm_last4 / pm_exp_month / pm_exp_year` exist but are no longer written under the IAP-only flow, and there are no legacy users (pre-launch).
8. **Cloudflare is not disclosed at all.** Webapp delivery (Pages/Workers) and media storage (R2) both run through Cloudflare, but no entry exists.
9. **Cross-border transfer is not disclosed.** APPI requires foreign-third-party transfers to be flagged. Current policy lists US-headquartered services without noting their location.
10. **`supabase` entry overstates scope.** "すべてのユーザーデータ" is wrong — media files live on R2, not Supabase Storage.

## Design

### Approach

**Content-only changes.** The section structure (10 sections, in current order) is preserved because it is intentionally aligned with Google Play's recommended privacy policy outline. New sub-paragraphs are added by introducing new i18n keys and adding `<p>` elements in `page.tsx`; no section is renamed, split, or reordered.

Both `messages/ja.json` and `messages/en.json` are updated in lockstep — the page is bilingual.

### Effective Date

`effectiveDate`: bump from `2026年3月9日` → `2026年5月5日` (en: `March 9, 2026` → `May 5, 2026`).

### Section 2 — `collect.task` and `collect.payment`

**`collect.task` (modify):** append "ポイント・リワード残高および取引履歴" to the existing body. Points and rewards are internal account state, not external payment data — they belong with task/judgment activity (the values are issued and consumed via task creation and judgment).

**`collect.payment` (modify):** drop card details and rewrite around IAP + Connect.

```
Before: Stripeアカウント識別子、カードブランド・下4桁、カード有効期限、サブスクリプション状態、ポイント・リワード残高、振込履歴。カード番号の全桁はStripeが直接管理しており、当方のサーバーには保存されません。

After:  サブスクリプション情報（プロバイダ、状態、Apple / Google Play からの購入トランザクション識別子）、Stripeアカウント識別子（レフリーとしての報酬受取に使用）、振込履歴。クレジットカード情報および銀行口座情報は Apple / Google / Stripe が直接管理しており、当方のサーバーには保存されません。
```

### Section 4 — `thirdParty` (largest change)

The thirdParty array grows from 4 entries to 6 entries (adding `apple` and `cloudflare`). The `google` entry is repurposed to cover both Sign-In and Google Play Billing — they share a legal entity, so a single per-company entry is more accurate than splitting per sub-product. Order: auth → payment → notify → infra.

```typescript
const thirdParties = [
  'google',     // login + Google Play Billing
  'apple',      // App Store IAP (NEW)
  'stripe',     // Connect payouts
  'firebase',   // FCM
  'supabase',   // backend structured data
  'cloudflare', // webapp delivery + R2 media (NEW)
] as const
```

**Intro paragraph (modify):** add cross-border-transfer disclosure.

```
Before: アプリの運営に必要な範囲で、以下の第三者サービスと情報を共有します。

After:  アプリの運営に必要な範囲で、以下の第三者サービスと情報を共有します。下記の事業者は日本国外（主に米国）に所在しており、各社のプライバシーポリシーおよび現地の法令に従って個人情報を取り扱います。
```

**Per-entry bodies:** every entry ends with `所在地: 米国。` (en: `Location: United States.`) for cross-border disclosure.

| Key | Name | Body |
|---|---|---|
| `google` | Google | ログイン認証のためのメールアドレスおよびプロフィール情報、ならびにGoogle Playでのサブスクリプション課金処理のためのトランザクション情報。所在地: 米国。 |
| `apple` (NEW) | Apple | App Storeでのサブスクリプション課金処理のためのトランザクション情報。Appleアカウントの個人情報は当方に共有されません。所在地: 米国。 |
| `stripe` | Stripe | レフリーへの報酬送金のためのStripe Connectアカウント情報。所在地: 米国。 |
| `firebase` | Firebase Cloud Messaging | プッシュ通知配信のためのデバイストークン。所在地: 米国。 |
| `supabase` | Supabase | バックエンドのデータ保存および認証。メディアファイルはCloudflare R2に保管されます。所在地: 米国。 |
| `cloudflare` (NEW) | Cloudflare | webサイトの配信およびユーザーのメディアファイルの保管。アクセスログにはIPアドレス等が含まれます。所在地: 米国。 |

### Section 5 — `security` (operator access)

Add a new sub-paragraph disclosing operator data access. The existing `security.body` (technical measures) stays unchanged; a new key `security.operatorAccess` is added and rendered as a second `<p>`.

```
security.operatorAccess (NEW):
サービスの運営上必要な場合に限り、当方はユーザーデータにアクセスすることがあります。アクセスは、お問い合わせ対応、障害調査、法令遵守、不正利用への対応など、必要最小限の範囲に限定します。
```

Wording uses "当方" (consistent with the rest of the policy and appropriate for a sole-proprietor operator) and avoids claims of organizational controls (audit log review, separation of duties) that do not exist.

### Section 6 — `retention` (full rewrite of body, two new keys)

`retention.body` is rewritten to describe the actual deletion behavior. Two new keys are added for asset cleanup and legal exception, each rendered as its own `<p>`.

**`retention.body` (rewrite):**

```
Before: アカウントが有効である限りデータを保持します。アカウントを削除された場合、30日以内に個人データを削除します。ただし、法令上の要件や正当な業務上の必要性（紛争解決、契約の履行など）がある場合はこの限りではありません。

After:  アカウントが有効である限り、データを保持します。アカウントを削除された場合、本人を特定可能な情報（プロフィール、メールアドレス、決済情報、ポイント・リワード残高、通知設定、アバター画像等）は速やかに削除します。一方、タスク・審査関連のコンテンツ（タスクのタイトル・説明、エビデンス、審査メッセージ、評価コメント、レフリー判定等）は、サービス品質維持および他ユーザー保護の観点から、本人を特定可能な情報を匿名化したうえで保持します。
```

The "30日以内" claim is replaced with "速やかに" because the actual implementation deletes immediately via `auth.admin.deleteUser` + Postgres CASCADE.

**`retention.evidenceFiles` (NEW):**

```
エビデンス画像ファイルは、対応するタスクの期限日から90日経過後に自動削除されます。
```

**`retention.legalException` (NEW):**

```
法令上の要件や正当な業務上の必要性（紛争解決、契約の履行、税務記録など）がある場合は、上記の保持期間にかかわらず必要な範囲でデータを保持することがあります。
```

### Section 8 — `children` (age requirement)

Reframe from COPPA (under-13) to align with Terms eligibility (18+).

```
Before: Peppercheckは13歳未満のお子様を対象としていません。13歳未満のお子様から故意に個人情報を収集することはありません。万が一そのような情報を収集したことが判明した場合、速やかに削除いたします。

After:  Peppercheckは18歳以上の方を対象としており、未成年の方による利用は想定していません。未成年から故意に個人情報を収集することはありません。万が一そのような情報を収集したことが判明した場合、速やかに削除いたします。
```

The belt-and-suspenders sentence ("万が一〜削除") is preserved as a safety clause.

### `page.tsx` — JSX updates

Three changes:

1. **`thirdParties` array** — update from 4 entries to 6 entries (see Section 4 above).
2. **`security` section** — add a second `<p>` rendering `security.operatorAccess`.
3. **`retention` section** — add two more `<p>`s rendering `retention.evidenceFiles` and `retention.legalException`.

No changes to section ordering, headings, or top-level structure.

### Files changed

```
peppercheck-webapp/
  src/app/[locale]/legal/privacy/page.tsx   # MODIFY: thirdParties array, security/retention <p> additions
  messages/ja.json                          # MODIFY: Privacy.* updates (every section above)
  messages/en.json                          # MODIFY: Privacy.* updates (parallel English)
```

## Follow-up issues (not part of this PR)

These are tracked as separate issues so the policy update can ship independently. Each is referenced in the policy text, so they should be implemented within a reasonable window after the policy is published.

1. **R2 lifecycle rule for evidence files** — Cloudflare R2 lifecycle rule that deletes evidence-file directories `due_date + 90 days` after the task's `due_date`. Currently unimplemented. Public issue (no secrets — directory layout is operationally trivial; the 90-day policy is publicly disclosed once this PR lands).
2. **Avatar file deletion in `delete-account`** — extend the `delete-account` Edge Function to delete the user's avatar object from R2 before calling `auth.admin.deleteUser`. Without this, avatars linger in R2 after account deletion despite the privacy policy promising removal.
3. **Drop dead `pm_*` columns from `stripe_accounts`** — `pm_brand / pm_last4 / pm_exp_month / pm_exp_year` are no longer written under IAP-only and there are no legacy rows (pre-launch). Drop in a schema-only migration.

## Out of scope

- Restructuring the policy section order or headings (Google Play-aligned outline is intentionally preserved).
- Adding a separate "data residency / region" disclosure (Supabase Tokyo region, R2 region) — Q8 settled at country-level disclosure only.
- Updating `Terms` or `Refund` pages.
- Re-acceptance flow for existing users (none yet — pre-launch).
- Changing the ObfuscatedEmail contact target.
- Implementing the three follow-up issues above.
