# Cloudflare 設定ガイド

## 概要

PepperCheckでは、画像ファイルの配信にCloudflare R2ストレージとカスタムドメインを使用しています。
MVP時点では直接アップロード方式を採用し、最もシンプルな構成で実装しています。

## アーキテクチャ

```
[Android] → [Supabase generate-upload-url] → [R2: evidence/year/month/day/uuid.ext]
                                                      ↓
[file.peppercheck.com/evidence/year/month/day/uuid.ext] ← [直接配信]
```

## 必要な設定

### 1. R2 バケット設定

#### バケット作成
```bash
# Cloudflare ダッシュボードでバケット作成
バケット名: peppercheck
リージョン: 自動選択
```

#### カスタムドメイン設定
```bash
# Cloudflare ダッシュボード → R2 → バケット → カスタムドメイン
ドメイン: file.peppercheck.com
バケット: peppercheck
```

### 2. API認証情報

#### R2 APIトークン作成
```bash
# Cloudflare ダッシュボード → R2 → Manage R2 API tokens
権限: Object Storage:Edit
リソース: All accounts, All zones
```

#### 環境変数設定（Supabase）
```bash
# Supabase Edge Function用
supabase secrets set R2_ACCOUNT_ID=your_cloudflare_account_id
supabase secrets set R2_ACCESS_KEY_ID=your_r2_access_key_id  
supabase secrets set R2_SECRET_ACCESS_KEY=your_r2_secret_access_key
supabase secrets set R2_BUCKET_NAME=peppercheck
```

## ファイル構造

### R2バケット内構造（MVP）
```
peppercheck/
└── evidence/
    └── 2025/
        └── 08/
            └── 03/
                ├── abc123-def456.jpg
                ├── xyz789-012345.png
                └── ...
```

### URL構造
```
R2パス: evidence/2025/08/03/abc123-def456.jpg
公開URL: https://file.peppercheck.com/evidence/2025/08/03/abc123-def456.jpg
```

## セキュリティ設定

### CORS設定（将来のWeb対応用）
```json
[
  {
    "AllowedOrigins": ["https://peppercheck.com", "https://*.peppercheck.com"],
    "AllowedMethods": ["PUT", "GET", "HEAD"],
    "AllowedHeaders": ["*"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3600
  }
]
```

### アクセス制御
- **アップロード**: 署名付きURL（Supabase Edge Function経由、認証必須）
- **閲覧**: パブリックアクセス（file.peppercheck.com経由）
- **ファイル形式**: 画像のみ（JPEG, PNG, WebP, GIF, HEIC, HEIF）
- **ファイルサイズ**: 最大5MB

## 運用・監視

### コスト監視
```bash
# 無料枠
- ストレージ: 10GB/月
- Class A操作: 100万リクエスト/月
- Class B操作: 1000万リクエスト/月
- 帯域幅: 無制限（Cloudflare CDN経由）
```

### パフォーマンス
- **CDN**: Cloudflareの全世界エッジネットワーク
- **キャッシュ**: 長期キャッシュ（immutable content）
- **レスポンス時間**: <50ms（エッジキャッシュヒット時）

## 将来の拡張計画

### Phase 2: 画像処理パイプライン
```
[R2 incoming/] → [Cloudflare Worker] → [R2 publish/]
                        ↓
              [画像検証・リサイズ・圧縮]
```

### Phase 3: 高度な機能
- NSFW検知（Cloudflare AI）
- 画像最適化（WebP変換）
- ウォーターマーク追加
- 自動削除（ライフサイクルルール）

## トラブルシューティング

### よくある問題

#### 1. カスタムドメインが機能しない
```bash
# DNS設定確認
dig file.peppercheck.com

# 解決策
1. Cloudflare DNSでCNAMEレコード設定
2. SSL証明書の自動発行待ち（最大24時間）
```

#### 2. アップロードエラー
```bash
# R2認証情報確認
- Account ID
- Access Key ID
- Secret Access Key
- バケット名

# 解決策
1. Supabase secretsの再設定
2. R2 APIトークンの権限確認
```

#### 3. 画像が表示されない
```bash
# アクセス確認
curl -I https://file.peppercheck.com/evidence/2025/08/03/test.jpg

# 解決策  
1. R2パスの確認
2. カスタムドメイン設定の確認
3. CORS設定（Web表示の場合）
```

## 関連ドキュメント

- [Supabase README](../supabase/README.md)
- [generate-upload-url API](../supabase/functions/generate-upload-url/README.md)
- [設計文書](../docs/development/design-document.md)