# エビデンス機能設計書

## 概要

PepperCheckにおけるエビデンス機能の横断的設計ドキュメント。
タスク完了の証拠となる画像・動画等のアップロード、保存、配信機能を包含する。

## MVP実装方針

### 直接アップロード方式を採用

**選択理由**:
- 開発速度とシンプルさを優先
- 画像処理パイプラインをスキップし、アップロード完了と同時に公開
- `processing_status="ready"`で即座に利用可能状態に設定

**将来拡張への準備**:
- データ構造は将来の画像処理に対応（`processing_status`, `error_message`等）
- R2キーと公開URLを分離し、処理パイプライン導入時の変更を最小化

## システムアーキテクチャ

### 全体構成
```
[Android App] ───── [Supabase Edge Function] ───── [Cloudflare R2]
      │                        │                         │
      │                        │                         │
      └─────── [Supabase REST API] ───── [PostgreSQL] ────┘
                                              │
                                    [task_evidences]
                                    [task_evidence_assets]
```

### データフロー
1. **ファイル情報取得**: クライアントからファイルメタデータを収集
2. **署名付きURL生成**: `generate-upload-url` Edge Functionで一時的なアップロードURLを生成
3. **R2アップロード**: 署名付きURLを使用してCloudflare R2に直接アップロード
4. **DB記録**: アップロード成功後にアセットレコードを作成
5. **状態更新**: エビデンスステータスを"ready"に更新

### コンポーネント詳細

#### Supabase Edge Function: `generate-upload-url`
**役割**: R2への署名付きアップロードURL生成
**パラメータ**:
```json
{
  "task_id": "uuid",
  "filename": "evidence.jpg", 
  "content_type": "image/jpeg",
  "file_size_bytes": 1024000,
  "kind": "evidence"
}
```

**レスポンス**:
```json
{
  "upload_url": "https://...",
  "r2_key": "evidence/2025/08/04/uuid.jpg",
  "expires_in": 600
}
```

#### Cloudflare R2
**バケット構造**:
```
peppercheck/
└── evidence/
    └── YYYY/
        └── MM/
            └── DD/
                ├── uuid1.jpg
                ├── uuid2.png
                └── ...
```

**公開URL**: `https://file.peppercheck.com/evidence/YYYY/MM/DD/uuid.ext`

#### PostgreSQL スキーマ

##### task_evidences
- `id`: UUID (Primary Key)
- `task_id`: UUID (Foreign Key)
- `description`: TEXT
- `status`: TEXT (`pending_upload`, `ready`)
- `created_at`, `updated_at`: TIMESTAMP

##### task_evidence_assets  
- `id`: UUID (Primary Key)
- `evidence_id`: UUID (Foreign Key)
- `file_url`: TEXT (R2キー: `evidence/2025/08/04/uuid.jpg`)
- `public_url`: TEXT (外部URL: `https://file.peppercheck.com/...`)
- `file_size_bytes`: BIGINT
- `content_type`: TEXT
- `processing_status`: TEXT (`ready`, `pending`, `failed`)
- `error_message`: TEXT
- `created_at`: TIMESTAMP

## データ設計

### 重要な設計判断

#### file_url vs public_url の分離
- **file_url**: R2内部キー（`evidence/2025/08/04/uuid.jpg`）
  - 将来の処理パイプライン用
  - ファイルの物理的な場所を示す
- **public_url**: 外部アクセス用URL（`https://file.peppercheck.com/...`）
  - MVPでの直接配信用
  - CDN経由でのアクセス最適化

#### processing_status の状態管理
- **MVP**: アップロード成功時に即座に`"ready"`に設定
- **将来**: `"pending"` → `"processing"` → `"ready"` / `"failed"`

## セキュリティ

### アップロード制限
- **認証**: ログインユーザーのみ
- **権限**: タスクの所有者（tasker）のみアップロード可能
- **ファイル形式**: 画像のみ（JPEG, PNG, WebP, GIF, HEIC, HEIF）
- **ファイルサイズ**: 最大5MB
- **有効期限**: 署名付きURL 10分

### アクセス制御
- **アップロード**: 署名付きURL（認証必須）
- **閲覧**: パブリックアクセス（file.peppercheck.com経由）
- **削除**: 所有者のみ（API経由）

## パフォーマンス

### CDN配信
- **Cloudflare CDN**: 全世界エッジネットワーク
- **キャッシュ戦略**: Immutable content（長期キャッシュ）
- **レスポンス時間**: <50ms（エッジキャッシュヒット時）

### 最適化
- **並列アップロード**: 複数ファイル同時処理
- **プログレス表示**: リアルタイム進捗フィードバック
- **エラーリトライ**: 自動再試行メカニズム

## エラーハンドリング

### 失敗パターンと対応

#### R2アップロード失敗
- **原因**: ネットワーク障害、ファイル破損、権限エラー
- **対応**: DBレコード作成せず、ユーザーにエラー表示
- **復旧**: 再アップロード

#### DB作成失敗
- **原因**: DB接続エラー、スキーマ違反
- **対応**: アップロード済みファイルは残存
- **復旧**: 手動クリーンアップ + 再DB登録

#### Edge Function失敗
- **原因**: 設定エラー、R2認証失敗
- **対応**: 署名付きURL生成失敗
- **復旧**: 環境変数確認 + 再実行

### ログ戦略
- **成功時**: 簡潔な完了ログ（task_id, asset数）
- **失敗時**: エラー内容と失敗段階を詳細記録
- **監視**: Cloudflare Analytics + Supabase Logs

## 将来の拡張計画

### Phase 2: 画像処理パイプライン
**アーキテクチャ変更**:
```
[Client] → [R2: incoming/] → [Cloudflare Worker] → [R2: public/]
                                    ↓
                            [画像検証・リサイズ・圧縮]
                                    ↓
                            [processing_status更新]
```

**処理内容**:
- ファイル形式検証
- 画像リサイズ（複数サイズ生成）
- 圧縮最適化
- メタデータ除去

### Phase 3: 高度な処理
**AI機能**:
- NSFW検知（Cloudflare AI）
- 物体認識による関連性チェック
- OCR（テキスト抽出）

**運用機能**:
- 自動WebP変換
- ウォーターマーク追加
- 不正画像の自動削除
- ライフサイクル管理（古いファイルの自動削除）

**監視・分析**:
- アップロード成功率分析
- ファイルサイズ・形式統計
- CDNキャッシュヒット率

## 運用監視

### メトリクス
- **アップロード成功率**: 目標 >99%
- **平均アップロード時間**: 目標 <3秒
- **CDNキャッシュヒット率**: 目標 >95%
- **ストレージ使用量**: 月次監視

### アラート
- アップロード失敗率 >5%
- 平均レスポンス時間 >5秒
- ストレージ使用量 80%超過
- R2 API エラー率 >1%

### コスト管理
- **R2料金**: ストレージ10GB無料、転送量無制限
- **Edge Function**: 10万リクエスト/月無料
- **予算アラート**: 月額$50超過時

---

**更新日**: 2025年8月4日  
**バージョン**: 1.0  
**作成者**: MVP開発チーム