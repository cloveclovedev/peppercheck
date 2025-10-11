# 評価システム設計仕様

## 概要
タスク完了後の相互評価システム。Tasker↔Referee間の5段階評価とコメント機能を提供し、ユーザーの信頼性スコアを管理する。

## データベース設計

### rating_histories テーブル
```sql
CREATE TABLE rating_histories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rater_id uuid NOT NULL REFERENCES profiles(id),    -- 評価した人（トリガーで自動設定）
    ratee_id uuid NOT NULL REFERENCES profiles(id),    -- 評価される人（旧user_id）
    task_id uuid REFERENCES tasks(id),                 -- 評価対象タスク
    judgement_id uuid REFERENCES judgements(id),       -- どの判定に対する評価か
    rating_type text NOT NULL,                         -- 'tasker' or 'referee'
    rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment text,                                      -- オプションコメント
    created_at timestamp with time zone DEFAULT now()
);
```

### user_ratings テーブル（集計用）
```sql
CREATE TABLE user_ratings (
    user_id uuid PRIMARY KEY REFERENCES profiles(id),
    tasker_rating numeric DEFAULT 0,           -- Taskerとしての平均評価
    tasker_rating_count integer DEFAULT 0,     -- Taskerとしての評価数
    referee_rating numeric DEFAULT 0,          -- Refereeとしての平均評価
    referee_rating_count integer DEFAULT 0,    -- Refereeとしての評価数
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);
```

## 評価フロー

### パターン1: Referee → Tasker評価（自動実行）
```
1. judgement.open → approved遷移時に自動実行
2. RatingDialog表示（対象: tasker名）
3. 1-5段階評価 + コメント入力（必須）
4. rating_histories INSERTで評価投稿
5. PostgreSQL Triggerでuser_ratings自動更新
6. judgementがapproved状態で待機
```

### パターン2: Tasker → Referee評価（任意実行）
```
1. judgement.approved状態でTaskScreen表示
2. "Rate Referee"ボタンタップ（任意タイミング）
3. RatingDialog表示（対象: judgement.profiles.username）
4. 1-5段階評価 + コメント入力
5. rating_histories INSERTで評価投稿
6. PostgreSQL Triggerでuser_ratings自動更新
7. judgement.approved → closed遷移
```

### パターン3: Referee → Tasker評価（Tasker強制完了後）
```
1. judgement.rejected → self_closed遷移時
2. Taskerがreferee評価を実行済み
3. Referee側でTaskScreen表示時に"Rate Tasker"ボタン表示
4. RatingDialog表示（対象: tasker名）
5. 1-5段階評価 + コメント入力
6. judgement.self_closed → closed遷移
```

### システム評価（タイムアウト時）
```
1. judgement.timeout または evidence_timeout遷移時
2. システムが自動的に0点評価を投稿
3. 評価対象: タイムアウト責任者（referee or tasker）
4. コメント: "Automatic rating due to timeout"
```

## 技術的設計判断

### user_ratings更新方式: 全件再計算 vs 増分計算

#### 検討した選択肢
1. **増分計算**: `new_avg = (old_avg * old_count + new_rating) / (old_count + 1)`
2. **全件再計算**: `SELECT AVG(rating) FROM rating_histories WHERE user_id = ? AND rating_type = ?`

#### 採用判断: 全件再計算
**理由**:
- **データ量**: 1ユーザーあたりの評価数は限定的（数十〜数百件）
- **実行頻度**: 評価投稿は高頻度ではない
- **整合性**: 常に正確な値を保証、計算誤差なし
- **シンプル性**: ロジックが単純で保守しやすい
- **PostgreSQL最適化**: AVG関数は高度に最適化済み
- **同時更新耐性**: タイミング問題やトランザクション順序に影響されない

#### パフォーマンス対策
```sql
-- インデックス最適化
CREATE INDEX idx_rating_histories_ratee_type ON rating_histories(ratee_id, rating_type);
CREATE INDEX idx_rating_histories_rater_task ON rating_histories(rater_id, task_id);
CREATE INDEX idx_rating_histories_judgement ON rating_histories(judgement_id);
```

### 評価対象者名前取得方式

#### Tasker → Referee評価時
```kotlin
// 既存judgements情報を活用
val judgements = taskRepository.getJudgements(taskId)
judgements.forEach { judgement ->
    val refereeName = judgement.profiles?.username ?: "Unknown Referee"
    // RatingDialog表示
}
```

#### Referee → Tasker評価時
```kotlin
// Task情報からtasker情報取得
val task = taskRepository.getTask(taskId)
// TODO: tasker名前取得のため、tasks.tasker_id → profiles JOIN必要
```

## 自動更新Trigger設計

### Trigger Function
```sql
CREATE OR REPLACE FUNCTION update_user_ratings()
RETURNS TRIGGER AS $$
DECLARE
    affected_user_id uuid;
BEGIN
    -- INSERT/UPDATE/DELETE対応
    IF TG_OP = 'DELETE' THEN
        affected_user_id := OLD.ratee_id;
    ELSE
        affected_user_id := NEW.ratee_id;
    END IF;

    -- tasker_rating, referee_rating を全件再計算で更新
    UPDATE user_ratings SET
        tasker_rating = COALESCE((SELECT AVG(rating) FROM rating_histories WHERE ratee_id = affected_user_id AND rating_type = 'tasker'), 0),
        tasker_rating_count = (SELECT COUNT(*) FROM rating_histories WHERE ratee_id = affected_user_id AND rating_type = 'tasker'),
        referee_rating = COALESCE((SELECT AVG(rating) FROM rating_histories WHERE ratee_id = affected_user_id AND rating_type = 'referee'), 0),
        referee_rating_count = (SELECT COUNT(*) FROM rating_histories WHERE ratee_id = affected_user_id AND rating_type = 'referee'),
        updated_at = NOW()
    WHERE user_id = affected_user_id;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;
```

## UI/UX設計

### RatingDialog仕様
- **5段階星評価**: タップで選択、AccentYellow でハイライト
- **コメント入力**: オプション、3行テキストフィールド
- **対象者表示**: "Rate Referee: {username}" / "Rate Tasker: {username}"
- **Submit条件**: 星評価必須、コメントはオプション

### 表示タイミング
- **completed状態のタスクのみ**: draft/open/judging では表示しない
- **評価未済の対象者のみ**: 既に評価済みの場合は非表示
- **TaskScreen統合**: 別画面ではなくDialog で完結

## 評価完了判定

### 全評価完了の条件
```kotlin
// Taskerの場合: 承認済みの全Refereeを評価済み
val approvedJudgements = getJudgements(taskId).filter { it.status == "approved" }
val ratedJudgementIds = getRatingHistory(taskId, "referee").map { it.judgement_id }
val isTaskerDone = approvedJudgements.all { it.id in ratedJudgementIds }

// Refereeの場合: Taskerを評価済み（judgement_idベースで管理）
val myJudgementRatings = getRatingHistory(taskId, "tasker")
val isRefereeDone = myJudgementRatings.any { it.judgement_id == myJudgementId }
```

### 完了後の処理
- **TaskからHomeScreen削除**: 全評価完了時
- **統計更新**: user_ratingsは自動更新済み
- **通知**: 評価完了通知（将来実装）

## 実装優先度

### Phase 1: 基本評価機能（MVP）
1. PostgreSQL Trigger実装
2. RatingHistory data class
3. RatingRepository CRUD
4. TaskScreen統合（Dialog表示）

### Phase 2: UX改善
1. 評価済み状態表示
2. 評価履歴表示
3. プロフィール画面での評価表示

### Phase 3: 高度な機能
1. 評価分析・レポート
2. 悪質ユーザー検知
3. 評価の重み付け

---

## RLS (Row Level Security) 設計

### 自動rater_id設定
```sql
-- rater_idを自動設定するトリガー関数
CREATE OR REPLACE FUNCTION set_rater_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.rater_id IS NULL THEN
    NEW.rater_id := (select auth.uid());
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- トリガー設定
CREATE TRIGGER trigger_set_rater_id
  BEFORE INSERT ON rating_histories
  FOR EACH ROW
  EXECUTE FUNCTION set_rater_id();
```

### アクセス権限
```sql
-- 認証済みユーザーは評価を投稿可能
CREATE POLICY "Allow authenticated users to insert ratings"
ON rating_histories FOR INSERT TO authenticated WITH CHECK (true);

-- 関係者のみ評価を閲覧可能
CREATE POLICY "Allow users to view their related ratings"
ON rating_histories FOR SELECT TO authenticated
USING (rater_id = (select auth.uid()) OR ratee_id = (select auth.uid()));

-- タスク参加者は関連評価を閲覧可能
CREATE POLICY "Allow task participants to view task ratings"
ON rating_histories FOR SELECT TO authenticated
USING (
  EXISTS (SELECT 1 FROM tasks WHERE tasks.id = rating_histories.task_id AND tasks.tasker_id = (select auth.uid())) OR
  EXISTS (SELECT 1 FROM judgements WHERE judgements.id = rating_histories.judgement_id AND judgements.referee_id = (select auth.uid()))
);
```

---

**作成日**: 2025年8月13日  
**最終更新**: 2025年8月24日
