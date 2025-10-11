# PepperCheck Android App

PepperCheckのAndroidアプリケーション開発に関するドキュメントとリソース。

## 📱 概要

Kotlin + Jetpack Composeで開発されたネイティブAndroidアプリケーション。

### 主要機能
- タスク作成・管理
- レフェリー機能
- エビデンス提出・判定
- 決済連携（Stripe）
- リアルタイム更新

## 🎨 UI開発

### **⚠️ UI開発時は必読**
**[📋 UI Guidelines](docs/ui-guidelines.md)** - Android UI開発指針

新しい画面やコンポーネントを作成する際は、必ず上記の指針に従ってください。

### UI特徴
- Material 3 Design
- 統一されたスペーシング（12dp）
- LazyColumnベースのスクロール
- Pull-to-Refresh対応
- カスタムテーマ（AccentYellow）

## 🏗️ アーキテクチャ

### MVVM パターン
```
ui/
├── screens/
│   ├── home/           # ホーム画面
│   ├── profile/        # プロフィール画面
│   ├── task/          # タスク関連（詳細・作成）
│   └── ...
├── theme/             # テーマ・カラー定義
└── components/        # 共通コンポーネント
```

### データ層
```
repository/            # データアクセス層
data/                 # データモデル
```

## 🖼️ エビデンスアップロード実装

### Android固有の実装

#### Repository層構成
```kotlin
// ファイルアップロード処理
R2FileUploadRepository
├── uploadEvidence(): UploadResult?        // メインアップローフロー
├── generateUploadUrl(): GenerateUploadUrlResponse?  // 署名付きURL取得
├── uploadFile(): Boolean                  // R2への直接アップロード
└── ファイルメタデータ取得メソッド群

// DB操作
TaskEvidenceRepository  
├── createTaskEvidence(): TaskEvidence?    // エビデンス作成
├── createTaskEvidenceAsset(): TaskEvidenceAsset?  // アセット作成
└── updateTaskEvidenceStatus(): Boolean    // ステータス更新
```

#### ViewModel設計
```kotlin
// TaskViewModel.submitEvidence()
1. エビデンス作成 (createTaskEvidence)
2. 各ファイルの並列アップロード
   ├── R2アップロード (uploadEvidence)
   ├── アセット作成 (createTaskEvidenceAsset) 
   └── プログレス更新
3. ステータス更新 (updateTaskEvidenceStatus)
```

#### Android固有の考慮事項

**ContentResolver活用**:
- `getFileSize()`: ファイルサイズ取得
- `getContentType()`: MIME type判定  
- `getFileName()`: ファイル名抽出

**エラーハンドリング**:
- ネットワーク接続エラー
- ファイルアクセス権限エラー
- メモリ不足対応

**UI連携**:
- リアルタイムプログレス表示
- エラーメッセージ表示
- アップロード完了後の状態リセット

### 関連ドキュメント
- [エビデンス機能全体設計](../docs/development/functions/evidence.md) - システム全体のアーキテクチャ・設計方針

## 🔧 開発環境

### 必要なツール
- Android Studio
- Kotlin 1.9+
- Compose BOM最新版

### セットアップ
1. プロジェクトをclone
2. `local.properties`にSupabase設定を追加
3. Android Studioでビルド

## 📚 関連ドキュメント

- [UI Guidelines](docs/ui-guidelines.md) - UI開発指針 ⭐
- [../docs/development/design-document.md](../docs/development/design-document.md) - 技術仕様
- [../supabase/README.md](../supabase/README.md) - API仕様