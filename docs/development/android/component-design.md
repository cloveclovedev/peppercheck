# Android UI Component 設計ガイド

## 概要
PepperCheck Android アプリにおけるUI Componentの設計方針と使用方法について説明します。

## Component 階層構造

```
ui/components/
├── common/                    # 全アプリ共通コンポーネント
│   ├── BaseSection.kt        # 基本セクション
│   └── ImageExpandedDialog.kt # 画像拡大ダイアログ
├── evidence/                 # エビデンス関連（今後実装予定）
├── task/                     # タスク関連（今後実装予定）
└── form/                     # フォーム関連（今後実装予定）
```

## 共通コンポーネント

### BaseSection

すべてのセクション表示で使用する基本コンポーネント。統一されたカードベースのレイアウトを提供します。

#### 基本使用法
```kotlin
BaseSection(title = "Section Title") {
    Text("Section content goes here")
}
```

#### アクション付きセクション
```kotlin
BaseSection(
    title = "Submitted Evidence",
    actions = {
        TextButton(onClick = { /* Edit action */ }) {
            Text("Edit")
        }
    }
) {
    Text("Evidence content")
}
```

#### 特徴
- **統一されたスタイル**: 16dp角丸、BackGroundLight背景
- **16dpパディング**: UI Guidelines準拠
- **アクション対応**: タイトル右側にボタン等を配置可能
- **フレキシブル**: 任意のコンテンツを表示可能

### ImageExpandedDialog

画像拡大表示用のモーダルダイアログ。

#### 基本使用法
```kotlin
var expandedImageUrl by remember { mutableStateOf<String?>(null) }

ImageExpandedDialog(
    imageUrl = expandedImageUrl,
    onDismiss = { expandedImageUrl = null }
)
```

#### 特徴
- **角丸表示**: 16dp角丸で統一感
- **適度な透明背景**: alpha 0.4fで後ろが透ける
- **直感的操作**: 背景タップで閉じる
- **レスポンシブ**: 85%幅で画面サイズに対応

## 設計原則

### 1. UI Guidelines準拠
- **セクション間余白**: 12dp
- **カード内パディング**: 16dp  
- **要素間小余白**: 8dp
- **角丸**: 16dp（セクション）、8dp（小要素）

### 2. 一貫性
- **カラーパレット**: BackGroundLight, TextBlack, AccentYellow
- **タイポグラフィ**: MaterialTheme.typography準拠
- **スペーシング**: 8dpベースのグリッドシステム

### 3. 再利用性
- **汎用的設計**: 特定の画面に依存しない
- **カスタマイズ性**: パラメータで動作を制御
- **組み合わせ可能**: 他のコンポーネントと組み合わせ可能

## 実装例

### TaskScreenでの使用（リファクタリング完了）

TaskScreenは完全にBaseSection化されており、以下のセクションで構成されています：

```kotlin
@Composable 
fun TaskScreen(/*...*/) {
    LazyColumn {
        // タスク情報セクション
        item {
            TaskInfoSection(task = uiState.task!!)
        }
        
        item { Spacer(modifier = Modifier.height(12.dp)) }
        
        // ユーザー役割に応じたセクション
        when (uiState.userRole) {
            UserRole.TASKER -> {
                item {
                    TaskerSection(
                        judgements = uiState.judgements,
                        evidence = uiState.evidence, 
                        onSubmitEvidence = onSubmitEvidence
                    )
                }
            }
            UserRole.REFEREE -> {
                item {
                    RefereeSection(
                        judgement = uiState.judgements.firstOrNull(),
                        evidence = uiState.evidence,
                        onUpdateJudgement = onUpdateJudgement
                    )
                }
            }
        }
    }
}

// すべてのセクションでBaseSection使用
@Composable
private fun TaskInfoSection(task: TaskUiModel) {
    BaseSection(title = task.title) { /* コンテンツ */ }
}

@Composable 
private fun SubmittedEvidenceSection(/*...*/) {
    BaseSection(title = "Submitted Evidence") { /* コンテンツ */ }
}
```

## 他画面での実装例

### HomeScreen（実装完了）

```kotlin
@Composable
fun TaskSection(title: String, tasks: List<Task>, onTaskClick: (Task) -> Unit) {
    BaseSection(title = title) {
        if (tasks.isEmpty()) {
            Text(
                text = "No tasks yet",
                style = MaterialTheme.typography.bodyMedium,
                color = TextBlack.copy(alpha = 0.6f),
                modifier = Modifier.padding(16.dp)
            )
        } else {
            tasks.forEach { task ->
                TaskCard(task, onTaskClick)
            }
        }
    }
}
```

### ProfileScreen（実装完了）

```kotlin
// アクション付きセクション例
@Composable
fun RefereeAvailabilitySection(/*...*/) {
    BaseSection(
        title = "Referee Availability",
        actions = {
            IconButton(onClick = { showAddDialog = true }) {
                Icon(Icons.Default.Add, contentDescription = "Add availability")
            }
        }
    ) {
        // 可用性リスト表示ロジック
    }
}

// シンプルセクション例  
@Composable
fun ConnectAccountSection(/*...*/) {
    BaseSection(title = "Payment Settings") {
        // Stripe Connect設定UI
    }
}
```

### CreateTaskScreen（実装完了）

```kotlin
@Composable
fun CreateTaskFormSection(/*...*/) {
    BaseSection(title = "Task Details") {
        OutlinedTextField(/* タイトル入力 */)
        Spacer(modifier = Modifier.height(4.dp))
        
        OutlinedTextField(/* 説明入力 */)
        Spacer(modifier = Modifier.height(4.dp))
        
        OutlinedTextField(/* 判定基準入力 */)
        Spacer(modifier = Modifier.height(4.dp))
        
        DeadlineInputField(/* 期限選択 */)
        Spacer(modifier = Modifier.height(12.dp))
        
        CommitmentFeeSelector(/* 手数料選択 */)
    }
}
```

## 今後の拡張計画

### Phase 2: Evidence Components（将来計画）
- `EvidenceContent.kt` - エビデンス表示コンテンツ
- `EvidenceAssetGrid.kt` - 画像グリッド表示
- `EvidenceSubmissionForm.kt` - エビデンス送信フォーム

### Phase 3: 新機能での活用
- 新画面開発時はBaseSection使用を標準とする
- 必要に応じて新しい共通コンポーネントを追加

## ベストプラクティス

### Do
- ✅ BaseSection を使用してセクションを統一
- ✅ UI Guidelines のスペーシングを遵守
- ✅ 既存のテーマカラーを使用
- ✅ コンポーネントにKDocコメントを追加

### Don't
- ❌ 独自のCard実装を作らない
- ❌ ハードコードされたカラー値を使用しない
- ❌ UI Guidelinesに反するスペーシング
- ❌ 画面固有のロジックをコンポーネントに含めない

## パフォーマンス考慮事項

- **Composition の最適化**: remember を適切に使用
- **再描画の最小化**: 状態管理を適切に分離
- **LazyColumn との親和性**: スクロール性能を考慮

---

**作成日**: 2025年8月5日  
**更新日**: 2025年8月5日  
**バージョン**: 1.1

## 完了済みタスク

✅ **Phase 1完了**: 全画面のBaseSection統一化
- **TaskScreen**: 全セクションをBaseSection化完了
  - TaskInfoSection をBaseSection化
  - SubmittedEvidenceSection をBaseSection化  
  - Evidence Submission Form をBaseSection化
  - Judgement Results Section をBaseSection化
  - Referee Judgement Section をBaseSection化

- **HomeScreen**: 全セクションをBaseSection化完了
  - TaskSection（Your tasks / Referee tasks）をBaseSection化

- **ProfileScreen**: 全セクションをBaseSection化完了
  - RefereeAvailabilitySection をBaseSection化（アクション付き）
  - ConnectAccountSection をBaseSection化

- **CreateTaskScreen**: 全セクションをBaseSection化完了
  - CreateTaskFormSection をBaseSection化

**成果**: 4画面すべてが統一されたBaseSection APIを使用し、保守性と再利用性が大幅に向上しました。LLMによる将来の開発において、一貫したコード構造で文脈理解が容易になります。