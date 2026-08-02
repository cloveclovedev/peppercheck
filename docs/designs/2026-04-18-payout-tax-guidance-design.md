# Payout Tax Guidance Design

**Issue:** #354
**Date:** 2026-04-18

## Problem

Stripe Connect Express onboarding displays "個人事業主" (sole proprietor) on the summary page. This label creates a psychological barrier for Japanese users concerned about 副業 (side job) regulations at their employer. Users may abandon the onboarding flow upon seeing this label.

## Solution

Add an informational card in the payout setup section that proactively explains:

1. The "個人事業主" label is a Stripe system classification, not a legal business registration
2. Tax classification and filing thresholds

The card is displayed **before** the setup button so users see the reassurance before deciding to proceed.

## Display Content

2 paragraphs + disclaimer (no title — context is clear from the surrounding section):

> Stripeの画面で「個人事業主」と表示されますが、これは決済システム上「法人ではない個人」を指す区分です。開業届の提出や勤務先への通知は一切ありません。
>
> 本アプリの報酬は税務上「雑所得」に分類されます。年間20万円以下であれば、原則として確定申告は不要です。
>
> ※ 一般的な税務情報であり、個別の税務アドバイスではありません。勤務先の就業規則については各自ご確認ください。

### Legal Basis (fact-checked)

| Claim | Source | Accuracy |
|-------|--------|----------|
| 20万円以下は確定申告不要 | 所得税法121条, [NTA No.1900](https://www.nta.go.jp/taxes/shiraberu/taxanswer/shotoku/1900.htm) | Accurate (for single-employer salaried workers; if voluntarily filing, must include) |
| レビュー報酬 = 雑所得 | [NTA No.1500](https://www.nta.go.jp/taxes/shiraberu/taxanswer/shotoku/1500.htm), [NTA No.1906](https://www.nta.go.jp/taxes/shiraberu/taxanswer/shotoku/1906.htm) | Accurate |
| Stripe「個人事業主」≠ 開業届 | [NTA No.2090](https://www.nta.go.jp/taxes/shiraberu/taxanswer/shotoku/2090.htm) | Accurate (Stripe-internal classification only) |

## UI Layout

### Payout setup section layout (isNotStarted / isInProgress)

```
┌─────────────────────────────────────────┐
│  Section Title: 出金設定                  │
│                                         │
│  Description text                       │
│  ("報酬を受け取るには..." etc.)             │
│                                         │
│  ┌─────────────────────────────────────┐ │
│  │ ℹ️  Stripeの画面で「個人事業主」と...  │ │
│  │                                     │ │
│  │ 本アプリの報酬は税務上...             │ │
│  │                                     │ │
│  │ ※一般的な税務情報であり...            │ │
│  └─────────────────────────────────────┘ │
│                                         │
│  [ 出金設定を行う ]  (button)             │
│                                         │
│  ▼ 入力のヒントを表示  (collapsible)      │
│    - 業種ヒント                          │
│    - 商品説明ヒント                      │
│    - ウェブサイトヒント                   │
└─────────────────────────────────────────┘
```

### Styling

- `Card` with `surfaceContainerHighest` background
- Leading `Icons.info_outline` icon on the first line
- Body: `bodySmall` style, `onSurfaceVariant` color
- Disclaimer: `labelSmall` style, lighter color

### Visibility

| State | Info card | Button | Hints |
|-------|-----------|--------|-------|
| isNotStarted | Shown | "出金設定を行う" | Shown |
| isInProgress | Shown | "出金設定を再開する" | Shown |
| isComplete | **Hidden** | "出金設定を変更" | Hidden |

## Localization Keys

Added to `ja.i18n.json` under `payout`:

| Key | Value |
|-----|-------|
| `taxGuidanceStripe` | Stripeの画面で「個人事業主」と表示されますが、これは決済システム上「法人ではない個人」を指す区分です。開業届の提出や勤務先への通知は一切ありません。 |
| `taxGuidanceTax` | 本アプリの報酬は税務上「雑所得」に分類されます。年間20万円以下であれば、原則として確定申告は不要です。 |
| `taxGuidanceDisclaimer` | ※ 一般的な税務情報であり、個別の税務アドバイスではありません。勤務先の就業規則については各自ご確認ください。 |

## Files to Modify

1. `peppercheck_flutter/lib/features/payout/presentation/widgets/payout_setup_section.dart` — Add info card widget
2. `peppercheck_flutter/assets/i18n/ja.i18n.json` — Add localization keys

No new files required.
