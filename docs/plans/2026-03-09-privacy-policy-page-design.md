# Privacy Policy Page Design

## Context

Google Play Store listing requires a privacy policy URL specific to the app (Issue #288, step 1b). The policy must describe what data the app collects, how it's used, and how users can request deletion.

The page will be hosted at `peppercheck.dev/privacy` as part of the existing peppercheck-webapp (Next.js + next-intl).

## Scope

- Add a `/privacy` route with EN/JA support
- Update Footer links from `href="#"` to `/privacy`
- Simple, individual-developer-appropriate policy covering Google Play requirements

## Section Structure

| # | Section | Content |
|---|---------|---------|
| 1 | Operator information | Operator name (CloveClove), contact (hi@cloveclove.dev) |
| 2 | Information we collect | Categorized list of collected data |
| 3 | Purpose of use | Why each category of data is collected |
| 4 | Third-party services | Stripe, Google, Firebase — what data is shared and why |
| 5 | Data storage and security | Encryption, access control overview |
| 6 | Data retention | Retained while account exists, deletion policy |
| 7 | User rights and deletion requests | How to request data access/deletion (Google Play requirement) |
| 8 | Children's privacy | Not intended for users under 13 (Google Play recommendation) |
| 9 | Changes to this policy | How changes are communicated |
| 10 | Contact | hi@cloveclove.dev |

### Data categories (Section 2 detail)

Based on the actual database schema (`supabase/schemas/`):

- **Account information**: Email address, display name, profile image, timezone (via Google Sign-In + profiles table)
- **Task and review data**: Task content (title, description, criteria), evidence (text + uploaded images/files), review messages, rating comments
- **Payment information**: Stripe account IDs, card last 4 digits and expiration, subscription status, point/reward balances, payout history
- **Device information**: FCM tokens, device type, last active timestamp
- **Usage data**: Referee availability time slots, matching history

### Third-party services (Section 4 detail)

| Service | Data shared | Purpose |
|---------|-------------|---------|
| Google (Sign-In) | Email, profile info | Authentication |
| Stripe | Payment method, account info | Payment processing, referee payouts |
| Firebase Cloud Messaging | Device tokens | Push notifications |
| Supabase | All user data | Backend data storage and authentication |

## Technical Implementation

### Page component

- New file: `src/app/[locale]/privacy/page.tsx`
- Dedicated component (not reusing `StaticInfoPage` — privacy policy needs multiple sections, headings, and lists)
- HTML structure (headings, lists, paragraphs) defined in TSX
- Text content pulled from translation JSON via `getTranslations('Privacy')`
- Reuses existing Header/Footer and layout pattern

### Translation

- Add `Privacy` namespace to `messages/en.json` and `messages/ja.json`
- Keys organized by section (e.g., `Privacy.collect.account`, `Privacy.purpose.auth`)

### Footer update

- Change privacy link `href="#"` to `href="/privacy"`

### Effective date

- 2026-03-09

## Decisions

- **Contact email**: `hi@cloveclove.dev` — sufficient for individual development stage; can be changed later if needed
- **Storage details**: Policy describes _what_ is collected, not _where_ it's stored (Cloudflare R2, Supabase DB, etc.) — this is standard practice
- **Scope**: Simple/minimal policy appropriate for individual developer; can be expanded later
- **Language**: Both EN and JA from the start (primary market is Japan)
