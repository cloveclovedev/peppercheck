# PepperCheck Documentation

このディレクトリには、PepperCheckプロジェクト全体に関するドキュメントが含まれています。

## ドキュメント構造

```
docs/
├── README.md                   # このファイル
├── overview/                   # プロジェクト概要
│   ├── project-brief.md        # プロジェクト概要と哲学
│   └── product-context.md      # プロダクトコンテキストとユーザージャーニー
└── development/                # 開発関連
    ├── design-document.md      # 開発方針や高レイヤーの設計
    ├── progress.md             # 開発進捗とマイルストーン
    ├── contribution.md         # 開発ルール
    └── functions/              # 機能別詳細設計
        └── evidence.md         # エビデンス機能設計書
```

## 各領域のドキュメント

各技術領域の詳細なドキュメントは、それぞれのディレクトリに配置されています：

- **Android**: `development/android/README.md` - Androidアプリの開発ガイド
- **Supabase**: `development/supabase/README.md` - バックエンドとデータベース
- **Stripe**: `development/stripe/README.md` - 決済システム
- **Cloudflare**: `development/cloudflare/README.md` - R2ストレージとCDN設定
- **Web**: `../web/README.md` - Webサイト

## 機能別詳細設計

**`development/functions/`ディレクトリ**には、機能横断的な詳細設計ドキュメントを配置：

- **evidence.md**: エビデンス機能（アップロード・保存・配信）の全体設計
- 今後追加予定:
  - `payment.md`: 決済機能設計
  - `matching.md`: マッチング機能設計  
  - `notification.md`: 通知機能設計

### 機能設計ドキュメントの特徴
- **システム全体**: 複数の技術スタックにまたがる設計
- **MVP方針**: 現在の実装方針と将来計画
- **運用考慮**: セキュリティ・パフォーマンス・監視

## ドキュメント更新方針

1. **プロジェクト全体の変更**: このdocsディレクトリ内のファイルを更新
2. **機能設計の変更**: `development/functions/` 内の対応ファイルを更新
3. **領域固有の変更**: 各領域のディレクトリ内のドキュメントを更新
4. **技術仕様の変更**: `development/design-document.md` を更新
5. **進捗更新**: `development/progress.md` を定期的に更新
6. **開発ルールの変更**: `development/contribution.md` を更新

## ドキュメント作成ガイドライン

- Markdown形式で記述
- 日本語で記述（技術用語は英語も併記）
- 図表やコード例を積極的に使用
- 更新日時を明記
- 関連ドキュメントへのリンクを適切に設置 
