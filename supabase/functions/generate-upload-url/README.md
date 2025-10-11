# generate-upload-url Edge Function

## 概要

タスクエビデンス用画像のアップロードに必要な署名付きURLを生成するEdge Function。Cloudflare R2ストレージへの安全なファイルアップロードを提供します。

## API仕様

### エンドポイント
```
POST https://your-project.supabase.co/functions/v1/generate-upload-url
```

### 認証
- **Authorization**: `Bearer [JWT_TOKEN]`
- **apikey**: Supabase Anon Key（ヘッダー）

### リクエスト

```json
{
  "task_id": "123e4567-e89b-12d3-a456-426614174000",
  "filename": "evidence.jpg",
  "content_type": "image/jpeg",
  "file_size_bytes": 1024000,
  "kind": "evidence"
}
```

#### パラメータ
| フィールド | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| `task_id` | string | ✓ | アップロード対象のタスクID |
| `filename` | string | ✓ | ファイル名（拡張子を含む） |
| `content_type` | string | ✓ | MIMEタイプ |
| `file_size_bytes` | number | ✓ | ファイルサイズ（バイト） |
| `kind` | string | ✓ | アップロード種別（現在は "evidence" のみ） |

#### 制限事項
- **ファイルサイズ**: 最大5MB
- **対応形式**: `image/jpeg`, `image/png`, `image/webp`, `image/gif`, `image/heic`, `image/heif`
- **権限**: タスクの所有者（tasker）のみアップロード可能

### レスポンス

#### 成功時（200）
```json
{
  "upload_url": "https://presigned-url.r2.dev/...",
  "r2_key": "evidence/2025/08/03/uuid.jpg",
  "expires_in": 600
}
```

#### エラー時
各エラーには適切なHTTPステータスコードとエラーメッセージが返されます。

## エラーレスポンス

### 400 Bad Request

#### 無効なJSON形式
```json
{
  "error": "Invalid JSON format in request body"
}
```
**原因**: リクエストボディが正しいJSON形式でない
**対処法**: JSON形式を確認してください

#### 必須フィールド不足
```json
{
  "error": "Missing required fields: task_id, filename, content_type, file_size_bytes, kind"
}
```
**原因**: 必須パラメータが不足している
**対処法**: すべての必須フィールドを含めてください

#### 対応外のファイル形式
```json
{
  "error": "Content type image/bmp not allowed"
}
```
**原因**: サポートされていないファイル形式
**対処法**: 対応形式（JPEG, PNG, WebP, GIF, HEIC, HEIF）を使用してください

#### ファイル拡張子とMIMEタイプの不一致
```json
{
  "error": "File extension does not match content type image/jpeg"
}
```
**原因**: ファイル名の拡張子とcontent_typeが一致しない
**対処法**: 拡張子とMIMEタイプを正しく設定してください

#### ファイルサイズ超過
```json
{
  "error": "File size 6000000 bytes exceeds maximum 5242880 bytes"
}
```
**原因**: ファイルサイズが5MBを超えている
**対処法**: ファイルサイズを5MB以下に圧縮してください

### 401 Unauthorized

#### 認証ヘッダー不足
```json
{
  "error": "Missing authorization header"
}
```
**原因**: AuthorizationヘッダーがリクエストにBei
**対処法**: `Authorization: Bearer [JWT_TOKEN]` ヘッダーを追加してください

#### 無効なトークン
```json
{
  "error": "Unauthorized: Invalid or expired token"
}
```
**原因**: JWTトークンが無効または期限切れ
**対処法**: 有効なJWTトークンを取得して再送信してください

### 403 Forbidden

#### タスクへのアクセス権限なし
```json
{
  "error": "Task not found or you do not have permission to upload evidence for this task"
}
```
**原因**: 指定されたタスクが存在しないか、ユーザーがタスクの所有者でない
**対処法**: 正しいtask_idを指定し、タスクの所有者として認証されていることを確認してください

### 500 Internal Server Error

#### R2設定エラー
```json
{
  "error": "Server configuration error: R2 credentials not properly configured"
}
```
**原因**: Cloudflare R2の環境変数が正しく設定されていない
**対処法**: 管理者にR2設定の確認を依頼してください

#### 署名付きURL生成エラー
```json
{
  "error": "Failed to generate upload URL. Please check R2 configuration."
}
```
**原因**: R2との接続エラーまたは権限の問題
**対処法**: R2の認証情報とバケット設定を確認してください

#### 予期しないエラー
```json
{
  "error": "Internal server error",
  "debug": "Unexpected error: [具体的なエラーメッセージ]"
}
```
**原因**: システム内部エラー
**対処法**: ログを確認し、必要に応じて管理者に報告してください

## 環境変数

以下の環境変数が設定されている必要があります：

### Supabase（自動設定）
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

### Cloudflare R2（要設定）
- `R2_ACCOUNT_ID` - CloudflareアカウントID
- `R2_ACCESS_KEY_ID` - R2 API Token Access Key ID
- `R2_SECRET_ACCESS_KEY` - R2 API Token Secret Access Key
- `R2_BUCKET_NAME` - R2バケット名

### 設定コマンド
```bash
supabase secrets set R2_ACCOUNT_ID=your_account_id
supabase secrets set R2_ACCESS_KEY_ID=your_access_key_id
supabase secrets set R2_SECRET_ACCESS_KEY=your_secret_access_key
supabase secrets set R2_BUCKET_NAME=your_bucket_name
```

## MVP実装について

### パス構造の変更

**変更前（処理パイプライン用）**:
```
env=prod/evidence/incoming/2025/08/03/task-id/uuid.jpg
```

**変更後（MVP直接アップロード）**:
```
evidence/2025/08/03/uuid.jpg
```

### 主な変更点

1. **直接公開パス**: incomingディレクトリを廃止し、直接公開パスにアップロード
2. **taskId除去**: UUIDで一意性を保証するため、パスからtaskIdを削除
3. **即座アクセス**: アップロード完了と同時に `file.peppercheck.com/evidence/...` でアクセス可能
4. **シンプル化**: 画像処理パイプラインを削除し、最小構成で実装

### 配信URL

アップロード後、以下のURLで即座にアクセス可能：
```
https://file.peppercheck.com/evidence/2025/08/03/uuid.jpg
```

この設計により、MVPとして最もシンプルで高速な画像配信を実現。

## テスト方法

### cURLでのテスト例

```bash
curl -i --location --request POST 'https://your-project.supabase.co/functions/v1/generate-upload-url' \
  --header 'Authorization: Bearer YOUR_JWT_TOKEN_HERE' \
  --header 'Content-Type: application/json' \
  --data '{
    "task_id": "existing_task_id",
    "filename": "test.jpg",
    "content_type": "image/jpeg",
    "file_size_bytes": 1024000,
    "kind": "evidence"
  }'
```

### ローカル開発

```bash
# Supabaseローカル環境の起動
supabase start

# ローカルエンドポイント
curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/generate-upload-url' \
  --header 'Authorization: Bearer [LOCAL_JWT_TOKEN]' \
  --header 'Content-Type: application/json' \
  --data '{...}'
```

## ログの確認

Edge Functionのログを確認する場合：

```bash
supabase functions logs generate-upload-url
```

## トラブルシューティング

### よくある問題

1. **"Unauthorized" エラー**
   - JWTトークンの有効性を確認
   - 認証ヘッダーの形式を確認（`Bearer ` プレフィックス）

2. **"Task not found" エラー**
   - task_idが正しいか確認
   - ユーザーがそのタスクの所有者か確認

3. **"R2 configuration" エラー**
   - 環境変数がすべて設定されているか確認
   - R2の認証情報の有効性を確認

4. **"Invalid JSON" エラー**
   - リクエストボディのJSON形式を確認
   - Content-Typeヘッダーが設定されているか確認