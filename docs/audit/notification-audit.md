# 通知システム総点検 (Notification Audit)

Issue: #257

## 1. 通知一覧（タイミング × 受信者 × 内容）

| # | タイミング | Taskerへの通知 | Refereeへの通知 |
|---|-----------|---------------|----------------|
| 1 | **マッチング成立**（初回） | `notification_request_matched_tasker`<br>タイトル: マッチング成立！<br>本文: あなたのタスク「{taskTitle}」のレフリーが見つかりました。 | `notification_task_assigned_referee`<br>タイトル: 新しい担当タスク<br>本文: タスク「{taskTitle}」の担当レフリーに選ばれました。 |
| 2 | **レフリー再割当**（キャンセル後の再マッチ） | `notification_matching_reassigned_tasker`<br>タイトル: レフェリーが変更されました<br>本文: 「{taskTitle}」に新しいレフェリーが割り当てられました | （新レフリーには #1 が送信される） |
| 3 | **レフリーキャンセル**（再マッチ待ち） | `notification_matching_cancelled_pending_tasker`<br>タイトル: マッチングがキャンセルされました<br>本文: レフェリーがキャンセルしました。「{taskTitle}」の新しいレフェリーを検索中です | — |
| 4 | **マッチング期限切れ**（rematch cutoff 超過） | `notification_matching_expired_refunded_tasker`<br>タイトル: マッチング期限切れ<br>本文: 「{taskTitle}」のレフェリーが見つかりませんでした。ポイントが返金されました | — |
| 5 | **エビデンス提出**（初回INSERT） | — | `notification_evidence_submitted_referee`<br>タイトル: エビデンス提出<br>本文: {taskTitle}さんが新しいエビデンスを提出しました。 |
| 6 | **エビデンス更新**（UPDATE、rejected以外） | — | `notification_evidence_updated_referee`<br>タイトル: エビデンス更新<br>本文: {taskTitle}さんがエビデンスを更新しました。 |
| 7 | **エビデンス再提出**（rejected → in_review, reopen_count > 0） | — | `notification_evidence_resubmitted_referee`<br>タイトル: エビデンス再提出<br>本文: {taskTitle}のエビデンスが再提出されました。再度判定してください。 |
| 8 | **レフリー承認** | `notification_judgement_approved_tasker`<br>**⚠️ 未実装（後述 BUG-1）** | — |
| 9 | **レフリー却下** | `notification_judgement_rejected_tasker`<br>**⚠️ 未実装（後述 BUG-2）** | — |
| 10 | **判定確認**（Taskerが手動確認） | — | `notification_judgement_confirmed_referee`<br>**⚠️ 未実装（後述 BUG-3）** |
| 11 | **エビデンスタイムアウト**（期限切れ） | `notification_evidence_timeout_tasker`<br>タイトル: エビデンス期限切れ<br>本文: タスク「{taskTitle}」のエビデンス提出期限が過ぎました。ポイントが消費されました。 | `notification_evidence_timeout_referee`<br>タイトル: 報酬獲得<br>本文: タスク「{taskTitle}」のエビデンス期限切れにより報酬を獲得しました。 |
| 12 | **レビュータイムアウト**（レフリーが判定せず） | `notification_review_timeout_tasker`<br>タイトル: レビュー期限切れ<br>本文: タスク「{taskTitle}」は期間内に評価されませんでした。ポイントが返却されました。 | `notification_review_timeout_referee`<br>タイトル: レビュー期限切れ<br>本文: タスク「{taskTitle}」のレビュー期限が過ぎました。 |
| 13 | **自動確認**（due_date + 3日後） | `notification_auto_confirm_tasker`<br>タイトル: 自動確認<br>本文: タスク「{taskTitle}」の評価が自動的に確認されました。 | `notification_auto_confirm_referee`<br>タイトル: 評価確認<br>本文: タスク「{taskTitle}」の評価が確認されました。 |
| 14 | **報酬振込先未設定**（月次payout準備時） | — | `notification_payout_connect_required_referee`<br>**⚠️ 部分実装（後述 BUG-4）**<br>タイトル: 報酬受取設定が必要です<br>本文: 報酬を受け取るために振込先の設定を完了してください。 |
| 15 | **報酬振込失敗** | — | `notification_payout_failed`<br>**⚠️ 部分実装 + 命名違反（後述 BUG-5）**<br>タイトル: 報酬振込失敗<br>本文: 報酬の振込に失敗しました。アカウント設定をご確認ください。 |

---

## 2. 未実装の通知（タイミング図に記載あるが実装なし）

| # | タイミング | 対象 | タイミング図の記載 | 状態 |
|---|-----------|------|------------------|------|
| GAP-1 | **エビデンス期限警告**（Due Date − 10分） | Tasker | "Deadline in 10 mins" | 設計のみ。cron/trigger未実装 |
| GAP-2 | **判定期限警告**（(Due Date + 3h) − 10分） | Referee | "Judgement Deadline Approaching" | 設計のみ。cron/trigger未実装 |
| GAP-3 | **リクエスト承認** | Tasker | lifecycle図: `RequestMatched → RequestAccepted` に `[Notification] Tasker` | `notification_request_accepted` のi18n定義はあるが、SQL側のトリガーが存在しない。デッドコード |

---

## 3. バグ・不整合一覧

### BUG-1: `notification_judgement_approved_tasker` — 全レイヤー欠落

**影響**: レフリーがエビデンスを承認した時、Taskerに空の通知（フォアグラウンドでは「お知らせ / 新しい通知があります。」フォールバック、バックグラウンドでは空白）が届く。

- **SQL**: `on_judgements_status_changed.sql:34` で `'notification_judgement_approved_tasker'` を送信 ✅
- **notification_text_resolver.dart**: switch caseなし ❌
- **ja.i18n.json**: エントリなし ❌
- **Android strings.xml** (en/ja): エントリなし ❌
- **iOS Localizable.strings** (en/ja): エントリなし ❌

### BUG-2: `notification_judgement_rejected_tasker` — 全レイヤー欠落

**影響**: BUG-1と同様。レフリーがエビデンスを却下した時、Taskerに空の通知が届く。

- **SQL**: `on_judgements_status_changed.sql:37` で `'notification_judgement_rejected_tasker'` を送信 ✅
- **notification_text_resolver.dart**: switch caseなし ❌
- **ja.i18n.json**: エントリなし ❌
- **Android strings.xml** (en/ja): エントリなし ❌
- **iOS Localizable.strings** (en/ja): エントリなし ❌

### BUG-3: `notification_judgement_confirmed_referee` — 全レイヤー欠落

**影響**: Taskerが判定を手動確認した時、Refereeに空の通知が届く。

- **SQL**: `on_judgement_confirmed.sql:30` で `'notification_judgement_confirmed_referee'` を送信 ✅
- **notification_text_resolver.dart**: switch caseなし ❌
- **ja.i18n.json**: エントリなし ❌
- **Android strings.xml** (en/ja): エントリなし ❌
- **iOS Localizable.strings** (en/ja): エントリなし ❌

### BUG-4: `notification_payout_connect_required_referee` — 部分実装

**影響**: フォアグラウンドではフォールバック表示。iOSバックグラウンドでは空白。Androidバックグラウンドのみ正常。

- **SQL**: `prepare_monthly_payouts.sql:70` で送信 ✅
- **Android strings.xml** (en/ja): あり ✅
- **notification_text_resolver.dart**: switch caseなし ❌
- **ja.i18n.json**: エントリなし ❌
- **iOS Localizable.strings** (en/ja): エントリなし ❌

### BUG-5: `notification_payout_failed` — 部分実装 + 命名規則違反

**影響**: BUG-4と同様の表示問題。さらに命名規則違反（`_referee`サフィックスが欠落）。

- **Edge Function**: `execute-pending-payouts/index.ts:148` で `'notification_payout_failed'` を送信 ✅
- **Android strings.xml** (en/ja): `notification_payout_failed_title/body` あり ✅
- **notification_text_resolver.dart**: switch caseなし ❌
- **ja.i18n.json**: エントリなし ❌
- **iOS Localizable.strings** (en/ja): エントリなし ❌
- **命名規則**: `notification_payout_failed_referee` であるべき（受信者は報酬を受け取るreferee）

### BUG-6: `notification_request_accepted` — デッドコード + 命名規則違反

**影響**: 直接的な問題はないが、i18n/platform stringsにキーが存在するのにSQL側で送信されていない。

- **SQL**: 送信するトリガーなし ❌
- **notification_text_resolver.dart**: switch caseあり（line 41-44） ✅
- **ja.i18n.json**: エントリあり ✅
- **Android strings.xml** (en/ja): エントリあり ✅
- **iOS Localizable.strings** (en/ja): エントリあり ✅
- **命名規則**: `notification_request_accepted_tasker` であるべき（受信者サフィックス欠落）
- **備考**: lifecycle図では `RequestMatched → Accepted` 時に `[Notification] Tasker` とあるが、現在MVPではMatched→Accepted が自動遷移で`process_matching.sql`内で即座に行われる。マッチング成立通知（#1）で実質カバーされている可能性あり。要検討。

---

## 4. 通知データフロー（参照用）

```
SQL trigger
  └→ notify_event(user_id, 'notification_{event}_{recipient}', ARRAY[task_title], {task_id: ...})
      └→ _title / _body サフィックスを自動付与
          └→ Edge Function (send-notification)
              └→ FCM multicast
                  ├→ Android background: strings.xml で loc_key 解決
                  ├→ iOS background: Localizable.strings で loc_key 解決
                  └→ Foreground: notification_text_resolver.dart → slang t.notification.*
```

## 5. エビデンス提出通知の本文の問題

`notification_evidence_submitted_referee_body` と `notification_evidence_updated_referee_body` の `${taskTitle}` / `%1$s` / `%@` 引数に渡される値は **タスクタイトル** だが、本文テンプレートでは「{taskTitle}**さん**が新しいエビデンスを提出しました」と **人名のように** 使われている。

- `on_task_evidences_upserted_notify_referee.sql:38` で `SELECT title INTO v_task_title FROM public.tasks` → タスクのタイトルを取得
- テンプレート: `${taskTitle}さんが新しいエビデンスを提出しました。`
- 結果: 「ジム週3回さんが新しいエビデンスを提出しました。」のような不自然な文になる

→ `タスク「${taskTitle}」のエビデンスが提出されました。` のような修正を検討

---

## 6. 各レイヤーの整合性チェック一覧

| キー（base） | SQL送信 | Dart resolver | ja.i18n.json | Android strings.xml | iOS Localizable.strings | 結果 |
|-------------|---------|--------------|-------------|--------------------|-----------------------|------|
| `notification_request_matched_tasker` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ OK |
| `notification_task_assigned_referee` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ OK |
| `notification_request_accepted` | ❌ 未送信 | ✅ | ✅ | ✅ | ✅ | ⚠️ デッドコード (BUG-6) |
| `notification_evidence_submitted_referee` | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ 本文に問題あり (§5) |
| `notification_evidence_updated_referee` | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ 本文に問題あり (§5) |
| `notification_evidence_resubmitted_referee` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ OK |
| `notification_judgement_approved_tasker` | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ BUG-1 |
| `notification_judgement_rejected_tasker` | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ BUG-2 |
| `notification_judgement_confirmed_referee` | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ BUG-3 |
| `notification_evidence_timeout_tasker` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ OK |
| `notification_evidence_timeout_referee` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ OK |
| `notification_review_timeout_tasker` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ OK |
| `notification_review_timeout_referee` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ OK |
| `notification_auto_confirm_tasker` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ OK |
| `notification_auto_confirm_referee` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ OK |
| `notification_matching_reassigned_tasker` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ OK |
| `notification_matching_cancelled_pending_tasker` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ OK |
| `notification_matching_expired_refunded_tasker` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ OK |
| `notification_payout_connect_required_referee` | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ BUG-4 |
| `notification_payout_failed` | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ BUG-5 |

---

## 7. 対応方針（提案）

### 必須修正（空の通知の原因）
1. **BUG-1, BUG-2**: `notification_judgement_approved_tasker` / `notification_judgement_rejected_tasker` の全5レイヤー追加
2. **BUG-3**: `notification_judgement_confirmed_referee` の全5レイヤー追加
3. **BUG-4**: `notification_payout_connect_required_referee` のFlutter resolver / i18n / iOS strings 追加
4. **BUG-5**: `notification_payout_failed` → `notification_payout_failed_referee` にリネーム + 全レイヤー追加

### 推奨修正
5. **BUG-6**: `notification_request_accepted` のFlutter/platform定義を削除（デッドコード）、または `notification_request_accepted_tasker` にリネームして送信トリガーを追加
6. **§5**: エビデンス提出/更新通知の本文テンプレートを修正（タスクタイトルを人名として使っている問題）

### 将来対応（要検討）
7. **GAP-1**: エビデンス期限警告（Due Date − 10分）の実装
8. **GAP-2**: 判定期限警告（(Due Date + 3h) − 10分）の実装
