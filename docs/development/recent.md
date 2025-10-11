# 直近実装予定メモ

## UI部品化リファクタリング計画

### ファイル構成計画
```
android/app/src/main/java/dev/mkuri/peppercheck/ui/
├── components/           # 新規作成
│   ├── common/          # 新規作成
│   │   ├── BaseSection.kt        # 基本セクションコンポーネント
│   │   ├── EvidenceContent.kt    # エビデンス表示コンポーネント
│   │   └── ImageExpandedDialog.kt # 画像拡大ダイアログ
│   └── task/            # 新規作成
│       ├── TaskInfoContent.kt    # タスク情報表示
│       └── JudgementForm.kt      # 判定フォーム
├── screens/             # 既存
│   └── task/
│       ├── TaskScreen.kt         # リファクタリング対象
│       └── TaskViewModel.kt      # 変更なし
└── theme/               # 既存
```

### 実装手順
1. **Phase 1**: 共通コンポーネント作成
   - `ui/components/common/`ディレクトリ作成
   - `BaseSection.kt`実装
   - `EvidenceContent.kt`実装
   - `ImageExpandedDialog.kt`移動

2. **Phase 2**: TaskScreen段階的リファクタリング
   - 既存機能を保持しながら新コンポーネントを並行実装
   - A/Bテスト的にオプション切り替え可能に
   - 動作確認後に古いコード削除

3. **Phase 3**: 他画面への適用
   - Referee画面
   - Home画面のタスクカード
   - 新機能での活用

### コンポーネント設計詳細

#### BaseSection.kt (`ui/components/common/`)
```kotlin
@Composable
fun BaseSection(
    title: String,
    modifier: Modifier = Modifier,
    actions: (@Composable RowScope.() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = BackGroundLight),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Medium,
                    color = TextBlack
                )
                actions?.invoke(this)
            }
            Spacer(modifier = Modifier.height(8.dp))
            content()
        }
    }
}
```

#### EvidenceContent.kt (`ui/components/common/`)
```kotlin
@Composable
fun EvidenceContent(
    evidence: TaskEvidenceUiModel?,
    onImageClick: (String) -> Unit = {},
    emptyMessage: String = "エビデンスはまだ提出されていません",
    showMetadata: Boolean = false // Referee用途でのステータス表示制御
) {
    if (evidence != null) {
        Text(
            text = evidence.description,
            style = MaterialTheme.typography.bodyMedium,
            color = TextBlack
        )
        
        if (showMetadata) {
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Status: ${evidence.status}",
                style = MaterialTheme.typography.bodySmall,
                color = TextBlack.copy(alpha = 0.7f)
            )
            Text(
                text = evidence.formattedCreatedAt,
                style = MaterialTheme.typography.bodySmall,
                color = TextBlack.copy(alpha = 0.7f)
            )
        }
        
        val displayableAssets = evidence.assets.filter { it.publicUrl != null }
        if (displayableAssets.isNotEmpty()) {
            Spacer(modifier = Modifier.height(8.dp))
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(displayableAssets) { asset ->
                    EvidenceAssetItem(
                        asset = asset,
                        onClick = { onImageClick(asset.publicUrl!!) }
                    )
                }
            }
        }
    } else {
        Text(
            text = emptyMessage,
            style = MaterialTheme.typography.bodyMedium,
            color = TextBlack.copy(alpha = 0.6f),
            modifier = Modifier.padding(vertical = 16.dp)
        )
    }
}
```

### 移行戦略
- **後方互換性**: 既存コードは残したまま新コンポーネント追加
- **段階的移行**: 1画面ずつ移行してテスト
- **リスク軽減**: いつでも旧実装に戻せる構造

### リファクタリング後の使用例

#### SubmittedEvidenceSection（簡潔版）
```kotlin
@Composable
fun SubmittedEvidenceSection(
    evidence: TaskEvidenceUiModel?,
    showEditActions: Boolean = false,
    onEditEvidence: (() -> Unit)? = null
) {
    var expandedImageUrl by remember { mutableStateOf<String?>(null) }
    
    BaseSection(
        title = "Submitted Evidence",
        actions = if (showEditActions && onEditEvidence != null) {
            {
                TextButton(onClick = onEditEvidence) {
                    Text("Edit")
                }
            }
        } else null
    ) {
        EvidenceContent(
            evidence = evidence,
            onImageClick = { expandedImageUrl = it }
        )
    }
    
    ImageExpandedDialog(
        imageUrl = expandedImageUrl,
        onDismiss = { expandedImageUrl = null }
    )
}
```

#### 他のセクションでも再利用
```kotlin
@Composable
fun JudgementSection(onUpdateJudgement: (String, String?) -> Unit) {
    BaseSection(title = "Judgement") {
        var comment by remember { mutableStateOf("") }
        
        OutlinedTextField(/* ... */)
        Spacer(modifier = Modifier.height(16.dp))
        
        Row(/* ボタン配置 */) {
            Button(/* Approve */) { /* ... */ }
            OutlinedButton(/* Reject */) { /* ... */ }
        }
    }
}

@Composable
fun TaskInfoSection(task: TaskUiModel) {
    BaseSection(title = "Task Information") {
        TaskInfoContent(task = task)
    }
}
```

## その他近日実装予定
- エビデンス編集機能
- 画像のプレビュー改善
- タスクカードの統一化

## 実装優先度
1. **High**: BaseSection, EvidenceContent作成
2. **Medium**: TaskScreen部分的リファクタリング  
3. **Low**: 全画面への展開

## メリット
- ✅ 段階的で安全な実装
- ✅ 既存機能への影響最小化
- ✅ 将来的な保守性向上
- ✅ 新機能開発の加速

---

**作成日**: 2025年8月5日  
**更新日**: 2025年8月5日