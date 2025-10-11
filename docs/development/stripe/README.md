# 💳 Stripe Webhook Integration

> ℹ️ `handle-stripe-webhook` Edge Function は本リポジトリから削除されました。以下は再実装時のために残している設計メモです。

## ✅ 想定イベント

* `checkout.session.completed`

## 🔄 Webhook構成のメモ

* **送信元**: Stripe Checkout セッション完了時
* **送信先**: Supabase Functions (`handle-stripe-webhook`) を想定。再導入時は `supabase functions new handle-stripe-webhook` で作成し、デプロイ前に `supabase/config.toml` に設定を追加する。
* **検証方式**: 署名付きヘッダー `stripe-signature` を `constructEventAsync(body, signature, webhook_secret)` で検証

---

## 📦 期待するペイロード形式

```json
{
  "id": "evt_1...",
  "type": "checkout.session.completed",
  "data": {
    "object": {
      "amount_total": 1000,
      "metadata": {
        "user_id": "abc-123"
      }
    }
  }
}
```

---

## 📘 実行処理の流れ

1. `metadata.user_id` と `amount_total` を抽出
2. `wallets.balance` に加算
3. `transactions` テーブルへ insert

   * `type: "charge"`
   * `currency: "JPY"`
   * `description: "Stripe charge"`

---

## 💡 補証

* 通貨は最小単位 (JPYなら100 = ￥100)
* `wallets` に対象ユーザーの行が存在していない場合、事前に作成しておくこと
* 本番運用ではイベントの再送信・重複処理に対する対策も考慮すること
