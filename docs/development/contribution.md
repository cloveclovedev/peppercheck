# PepperCheck: Contribution Guidelines

## PR作成ルール

### ブランチ命名規則
推奨パターン：
- `feature/機能名` - 新機能追加
- `fix/修正内容` - バグ修正
- `docs/ドキュメント内容` - ドキュメント更新
- `refactor/リファクタリング内容` - コード改善

例：
- `feature/task-creation`
- `fix/auth-error-handling`
- `docs/api-specification`

### コミットメッセージ規則
[Conventional Commits](https://www.conventionalcommits.org/)に準拠

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

#### Type
- `feat`: 新機能
- `fix`: バグ修正
- `docs`: ドキュメントのみの変更
- `style`: コードの意味に影響しない変更（空白、フォーマット等）
- `refactor`: バグ修正や機能追加ではないコード変更
- `test`: テストの追加や修正
- `chore`: ビルドプロセスや補助ツールの変更

#### 例
```
feat(auth): add Google Sign-In integration
fix(android): resolve navigation crash on login
docs(api): update endpoint documentation
refactor(database): optimize user query performance
```

### PRタイトル規則
[Conventional Commits](https://www.conventionalcommits.org/)に準拠

例：
- `feat(supabase): add task creation functionality`
- `fix(android): resolve authentication error`
- `docs(docs): update API documentation`

## コード規約

### Kotlin/Android規約
- Kotlin公式スタイルガイドに準拠
- Jetpack Compose UIコンポーネントは小さく保つ
- ViewModelsは状態を持つがUIに依存しない
- Repository層はすべてのデータソースを抽象化

### データベース規約
- 正規化を徹底
- Row Level Security (RLS)を必ず設定
- 外部キー制約を適切に設定
- インデックスを適切に作成

### API規約
- RESTful設計を基本とする
- URLは簡潔で意味のある命名
- CRUD操作を標準HTTPメソッドで実装
- 適切なHTTPステータスコードを使用

#### URL例
```
GET    /api/tasks          # タスク一覧取得
POST   /api/tasks          # タスク作成
GET    /api/tasks/{id}     # タスク詳細取得
PUT    /api/tasks/{id}     # タスク更新
DELETE /api/tasks/{id}     # タスク削除
```

---

**更新日**: 2025年7月
**バージョン**: 1.0 
