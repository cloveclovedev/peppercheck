# Subscription Management: IAP-Only Simplification

**Date:** 2026-04-09
**Status:** Approved

## Context

The Flutter app's `SubscriptionSection` has a "Manage Subscription" button that opens the webapp's `/dashboard` page in an external browser. However:

- The webapp's subscription management features are incomplete
- Users who purchased via Google Play IAP cannot manage their IAP subscription from the webapp
- The webapp's `/pricing` page allows Stripe Checkout, creating a risk of double-purchasing (IAP + Stripe) with no safeguard
- The app currently targets Android only (iOS planned, also IAP-first)
- The webapp serves primarily as a landing page with no fully built logged-in features

## Decision

Simplify subscription management to be IAP-only within the mobile app, while protecting the webapp against double-purchases.

## Design

### 1. Flutter: Remove webapp link, add Google Play cancel link

**Remove:**
- The `ActionButton` ("Manage Subscription") and `_launchWebDashboard` method from `SubscriptionSection`

**Add:**
- Below `_PlanCardList`, a small text link: "Cancel via Google Play" (localized)
  - `fontSize: 12`, `textSecondary` color, right-aligned
  - Vertical spacing: `spacingTiny` above the link
  - Links to `https://play.google.com/store/account/subscriptions` via external browser
  - Visible only when the user has an active subscription

Plan upgrades/downgrades remain handled by the existing IAP flow within the app.

### 2. Webapp: Block double-purchase on `/pricing`

**Change:**
- When a logged-in user already has an active subscription, hide the "Subscribe" buttons on the `/pricing` page
- Replace with a status indicator showing the current plan and provider (e.g., "Current plan: Standard (via Google Play)")
- Unsubscribed and unauthenticated users see the existing page unchanged

**No change to `/dashboard`:**
- The dashboard displays subscription status but has no purchase flow, so no double-purchase risk exists

## Out of Scope

- Stripe direct-billing migration (deferred, "maybe someday")
- iOS IAP integration (separate future work)
- Webapp subscription management features (no current need)
