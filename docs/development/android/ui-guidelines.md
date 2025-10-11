# PepperCheck Android UI Guidelines

## Layout Guidelines

### Screen Structure
- **全画面でLazyColumnを使用**: 将来的なコンテンツ拡張とPull-to-Refreshに対応
- **Columnの代わりにLazyColumn**: スクロール可能でパフォーマンスが良い

### Spacing Standards
- **セクション間の余白**: 12.dp で統一（タイトルとセクション間、セクション間）
- **カード内padding**: 16.dp
- **要素間の小さな余白**: 8.dp
- **LazyColumn**: Spacerのみで制御、verticalArrangementは使用しない

### Pull-to-Refresh
- **実装必須**: 全リスト画面でPullToRefreshBoxを使用
- **一貫性**: Home画面と同様の実装パターン

## Component Guidelines

### Cards
```kotlin
Card(
    modifier = Modifier.fillMaxWidth(),
    shape = RoundedCornerShape(16.dp),
    colors = CardDefaults.cardColors(containerColor = BackGroundLight),
    elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
)
```

### LazyColumn Structure
```kotlin
LazyColumn(
    modifier = Modifier.fillMaxSize()
        .padding(start = 16.dp, end = 16.dp, bottom = 16.dp, top = 4.dp)
) {
    item { /* Title */ }
    item { Spacer(modifier = Modifier.height(12.dp)) }
    item { /* Section 1 */ }
    item { Spacer(modifier = Modifier.height(12.dp)) }
    item { /* Section 2 */ }
}
```

### PullToRefresh Structure
```kotlin
PullToRefreshBox(
    isRefreshing = uiState.isLoading,
    onRefresh = { viewModel.refresh() },
    state = pullToRefreshState,
    modifier = Modifier.fillMaxSize().padding(padding)
) {
    LazyColumn { /* content */ }
}
```

## Color Standards
- **Background**: Color.Transparent (Scaffold)
- **Card Background**: BackGroundLight
- **Text**: TextBlack
- **Accent**: AccentYellow

## Implementation Checklist
- [ ] LazyColumn for all screens
- [ ] PullToRefreshBox for data screens
- [ ] Consistent spacing (8.dp between sections)
- [ ] Card styling consistency
- [ ] Error handling UI
- [ ] Loading states