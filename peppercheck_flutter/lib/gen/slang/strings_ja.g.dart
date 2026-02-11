///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsJa = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ja,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ja>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	dynamic operator[](String key) => $meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final TranslationsLoginJa login = TranslationsLoginJa.internal(_root);
	late final TranslationsHomeJa home = TranslationsHomeJa.internal(_root);
	late final TranslationsNavJa nav = TranslationsNavJa.internal(_root);
	late final TranslationsBillingJa billing = TranslationsBillingJa.internal(_root);
	late final TranslationsCommonJa common = TranslationsCommonJa.internal(_root);
	late final TranslationsPayoutJa payout = TranslationsPayoutJa.internal(_root);
	late final TranslationsDashboardJa dashboard = TranslationsDashboardJa.internal(_root);
	late final TranslationsTaskJa task = TranslationsTaskJa.internal(_root);
	late final TranslationsProfileJa profile = TranslationsProfileJa.internal(_root);
	late final TranslationsMatchingJa matching = TranslationsMatchingJa.internal(_root);
}

// Path: login
class TranslationsLoginJa {
	TranslationsLoginJa.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: 'PEPPERCHECK'
	String get title => 'PEPPERCHECK';
}

// Path: home
class TranslationsHomeJa {
	TranslationsHomeJa.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: 'Home'
	String get title => 'Home';

	/// ja: '自分のタスク'
	String get myTasks => '自分のタスク';

	/// ja: '判定依頼'
	String get refereeTasks => '判定依頼';

	/// ja: 'タスクはありません'
	String get noTasks => 'タスクはありません';
}

// Path: nav
class TranslationsNavJa {
	TranslationsNavJa.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: 'Home'
	String get home => 'Home';

	/// ja: 'Payments'
	String get payments => 'Payments';

	/// ja: 'Profile'
	String get profile => 'Profile';
}

// Path: billing
class TranslationsBillingJa {
	TranslationsBillingJa.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: '支払い設定'
	String get title => '支払い設定';

	/// ja: '支払い方法'
	String get paymentMethod => '支払い方法';

	/// ja: '支払い方法を追加'
	String get addPaymentMethod => '支払い方法を追加';

	/// ja: '支払い方法を変更'
	String get changePaymentMethod => '支払い方法を変更';

	/// ja: '支払い方法が設定されていません'
	String get noPaymentMethod => '支払い方法が設定されていません';

	/// ja: '支払い方法を追加しました'
	String get paymentMethodAdded => '支払い方法を追加しました';

	/// ja: 'サブスクリプション'
	String get subscription => 'サブスクリプション';

	/// ja: 'プラン'
	String get plan => 'プラン';

	/// ja: 'ステータス'
	String get status => 'ステータス';

	/// ja: '更新日'
	String get renews => '更新日';

	/// ja: 'サブスクリプション管理'
	String get manageSubscription => 'サブスクリプション管理';

	late final TranslationsBillingPlansJa plans = TranslationsBillingPlansJa.internal(_root);

	/// ja: '未加入'
	String get noPlan => '未加入';
}

// Path: common
class TranslationsCommonJa {
	TranslationsCommonJa.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: 'キャンセル'
	String get cancel => 'キャンセル';

	/// ja: '確認'
	String get confirm => '確認';

	/// ja: '保存'
	String get save => '保存';

	late final TranslationsCommonDaysJa days = TranslationsCommonDaysJa.internal(_root);

	/// ja: 'エラー: $message'
	String error({required Object message}) => 'エラー: ${message}';
}

// Path: payout
class TranslationsPayoutJa {
	TranslationsPayoutJa.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: '出金設定'
	String get title => '出金設定';

	/// ja: '出金設定を行う'
	String get setupPayout => '出金設定を行う';

	/// ja: '報酬を受け取るには出金設定が必要です'
	String get payoutSetupDescription => '報酬を受け取るには出金設定が必要です';

	/// ja: '出金設定を変更'
	String get changePayoutSettings => '出金設定を変更';

	/// ja: '出金設定は完了しています'
	String get payoutSetupComplete => '出金設定は完了しています';

	/// ja: '出金設定を再開する'
	String get resumeSetup => '出金設定を再開する';

	/// ja: 'レフェリーをすることはできますが報酬を出金することはできません。出金設定を最後まで終わらせてください。'
	String get payoutSetupInProgressDescription => 'レフェリーをすることはできますが報酬を出金することはできません。出金設定を最後まで終わらせてください。';

	/// ja: '入力のヒントを表示'
	String get showHints => '入力のヒントを表示';

	/// ja: '入力のヒントを隠す'
	String get hideHints => '入力のヒントを隠す';

	/// ja: '業種は「その他の個人向けサービス」を選んでください'
	String get hintIndustry => '業種は「その他の個人向けサービス」を選んでください';

	/// ja: '商品の説明は「依頼を受けたタスクについて進捗内容をレビューします。レビュー完了時に代金が支払われます。」と入力してください'
	String get hintDescription => '商品の説明は「依頼を受けたタスクについて進捗内容をレビューします。レビュー完了時に代金が支払われます。」と入力してください';

	/// ja: '依頼を受けたタスクについて進捗内容をレビューします。レビュー完了時に代金が支払われます。'
	String get hintDescriptionCopy => '依頼を受けたタスクについて進捗内容をレビューします。レビュー完了時に代金が支払われます。';

	/// ja: 'ウェブサイトは「https://peppercheck.com」を入力してください'
	String get hintWebsite => 'ウェブサイトは「https://peppercheck.com」を入力してください';

	/// ja: 'https://peppercheck.com'
	String get hintWebsiteCopy => 'https://peppercheck.com';

	/// ja: '入力例をコピーしました'
	String get copiedInputExample => '入力例をコピーしました';

	/// ja: '金額'
	String get amount => '金額';

	/// ja: '金額が不正です'
	String get invalidAmount => '金額が不正です';

	/// ja: '出金可能額を超えています'
	String get insufficientFunds => '出金可能額を超えています';

	/// ja: '出金したい金額を入力してください'
	String get enterAmountDescription => '出金したい金額を入力してください';
}

// Path: dashboard
class TranslationsDashboardJa {
	TranslationsDashboardJa.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: '総収益'
	String get totalEarnings => '総収益';

	/// ja: '保留中'
	String get pending => '保留中';

	/// ja: '出金可能額'
	String get available => '出金可能額';

	/// ja: '出金を申請'
	String get requestPayout => '出金を申請';

	/// ja: '出金申請済み'
	String get payoutRequested => '出金申請済み';
}

// Path: task
class TranslationsTaskJa {
	TranslationsTaskJa.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final TranslationsTaskStatusJa status = TranslationsTaskStatusJa.internal(_root);
	late final TranslationsTaskDetailJa detail = TranslationsTaskDetailJa.internal(_root);
	late final TranslationsTaskCreationJa creation = TranslationsTaskCreationJa.internal(_root);
	late final TranslationsTaskEvidenceJa evidence = TranslationsTaskEvidenceJa.internal(_root);
}

// Path: profile
class TranslationsProfileJa {
	TranslationsProfileJa.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: 'プロフィール'
	String get title => 'プロフィール';
}

// Path: matching
class TranslationsMatchingJa {
	TranslationsMatchingJa.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final TranslationsMatchingRefereeAvailabilityJa referee_availability = TranslationsMatchingRefereeAvailabilityJa.internal(_root);
}

// Path: billing.plans
class TranslationsBillingPlansJa {
	TranslationsBillingPlansJa.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: 'ライトプラン'
	String get light => 'ライトプラン';

	/// ja: 'スタンダードプラン'
	String get standard => 'スタンダードプラン';

	/// ja: 'プレミアムプラン'
	String get premium => 'プレミアムプラン';
}

// Path: common.days
class TranslationsCommonDaysJa {
	TranslationsCommonDaysJa.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: '日曜日'
	String get sunday => '日曜日';

	/// ja: '月曜日'
	String get monday => '月曜日';

	/// ja: '火曜日'
	String get tuesday => '火曜日';

	/// ja: '水曜日'
	String get wednesday => '水曜日';

	/// ja: '木曜日'
	String get thursday => '木曜日';

	/// ja: '金曜日'
	String get friday => '金曜日';

	/// ja: '土曜日'
	String get saturday => '土曜日';
}

// Path: task.status
class TranslationsTaskStatusJa {
	TranslationsTaskStatusJa.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: '下書き'
	String get draft => '下書き';

	/// ja: 'マッチング開始'
	String get open => 'マッチング開始';

	/// ja: '判定中'
	String get judging => '判定中';

	/// ja: '却下'
	String get rejected => '却下';

	/// ja: '完了'
	String get completed => '完了';

	/// ja: '終了'
	String get closed => '終了';

	/// ja: '自己完結'
	String get self_completed => '自己完結';

	/// ja: '期限切れ'
	String get expired => '期限切れ';

	/// ja: '完了'
	String get done => '完了';
}

// Path: task.detail
class TranslationsTaskDetailJa {
	TranslationsTaskDetailJa.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: 'タスク詳細'
	String get title => 'タスク詳細';

	/// ja: 'リクエスト'
	String get sectionRequests => 'リクエスト';

	/// ja: 'ステータス'
	String get labelStatus => 'ステータス';
}

// Path: task.creation
class TranslationsTaskCreationJa {
	TranslationsTaskCreationJa.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: 'タスク作成'
	String get title => 'タスク作成';

	/// ja: 'タスク編集'
	String get titleEdit => 'タスク編集';

	/// ja: 'タスク情報'
	String get sectionInfo => 'タスク情報';

	/// ja: 'タイトル'
	String get labelTitle => 'タイトル';

	/// ja: '詳細 (任意)'
	String get labelDescription => '詳細 (任意)';

	/// ja: '完了条件'
	String get labelCriteria => '完了条件';

	/// ja: '期限'
	String get labelDeadline => '期限';

	/// ja: 'マッチングプラン'
	String get sectionMatching => 'マッチングプラン';

	/// ja: '追加'
	String get buttonAdd => '追加';

	/// ja: '作成'
	String get buttonCreate => '作成';

	/// ja: '更新'
	String get buttonUpdate => '更新';

	late final TranslationsTaskCreationStrategyJa strategy = TranslationsTaskCreationStrategyJa.internal(_root);
	late final TranslationsTaskCreationErrorJa error = TranslationsTaskCreationErrorJa.internal(_root);
}

// Path: task.evidence
class TranslationsTaskEvidenceJa {
	TranslationsTaskEvidenceJa.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: 'エビデンス'
	String get title => 'エビデンス';

	/// ja: 'エビデンスを提出'
	String get submit => 'エビデンスを提出';

	/// ja: '提出済みエビデンス'
	String get submitted => '提出済みエビデンス';

	/// ja: '説明'
	String get description => '説明';

	/// ja: 'タスクの完了を証明する内容を記述してください'
	String get descriptionPlaceholder => 'タスクの完了を証明する内容を記述してください';

	/// ja: '画像は最大5枚までです'
	String get maxImages => '画像は最大5枚までです';

	/// ja: 'エビデンスを提出しました'
	String get success => 'エビデンスを提出しました';

	/// ja: 'エラーが発生しました: $message'
	String error({required Object message}) => 'エラーが発生しました: ${message}';
}

// Path: matching.referee_availability
class TranslationsMatchingRefereeAvailabilityJa {
	TranslationsMatchingRefereeAvailabilityJa.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: '受付可能時間'
	String get title => '受付可能時間';

	/// ja: '受付可能時間が設定されていません'
	String get no_slots => '受付可能時間が設定されていません';

	/// ja: '受付時間を追加'
	String get add_slot => '受付時間を追加';

	/// ja: '受付時間を編集'
	String get edit_slot => '受付時間を編集';

	/// ja: '開始時間'
	String get dialog_start_time => '開始時間';

	/// ja: '終了時間'
	String get dialog_end_time => '終了時間';

	/// ja: '曜日'
	String get dialog_dow => '曜日';

	/// ja: '終了時間は開始時間より後である必要があります'
	String get invalid_time_range => '終了時間は開始時間より後である必要があります';
}

// Path: task.creation.strategy
class TranslationsTaskCreationStrategyJa {
	TranslationsTaskCreationStrategyJa.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: 'スタンダード'
	String get standard => 'スタンダード';
}

// Path: task.creation.error
class TranslationsTaskCreationErrorJa {
	TranslationsTaskCreationErrorJa.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: 'エラー'
	String get title => 'エラー';

	/// ja: 'ポイントが不足しています'
	String get insufficientPoints => 'ポイントが不足しています';

	/// ja: '現在の残高: $balance pt ロック済み: $locked pt 必要なポイント: $required pt'
	String insufficientPointsDetail({required Object balance, required Object locked, required Object required}) => '現在の残高: ${balance} pt\nロック済み: ${locked} pt\n必要なポイント: ${required} pt';

	/// ja: '期限が近すぎます'
	String get dueDateTooSoon => '期限が近すぎます';

	/// ja: 'タスクの期限は現在時刻から最低 $minHours 時間後である必要があります'
	String dueDateTooSoonDetail({required Object minHours}) => 'タスクの期限は現在時刻から最低 ${minHours} 時間後である必要があります';

	/// ja: 'ポイントウォレットが見つかりません'
	String get walletNotFound => 'ポイントウォレットが見つかりません';

	/// ja: 'ポイントウォレットの初期化に問題が発生しています。サポートにお問い合わせください。'
	String get walletNotFoundDetail => 'ポイントウォレットの初期化に問題が発生しています。サポートにお問い合わせください。';

	/// ja: 'エラーが発生しました'
	String get unknown => 'エラーが発生しました';

	/// ja: '$message'
	String unknownDetail({required Object message}) => '${message}';

	/// ja: 'OK'
	String get buttonOk => 'OK';
}

/// The flat map containing all translations for locale <ja>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'login.title' => 'PEPPERCHECK',
			'home.title' => 'Home',
			'home.myTasks' => '自分のタスク',
			'home.refereeTasks' => '判定依頼',
			'home.noTasks' => 'タスクはありません',
			'nav.home' => 'Home',
			'nav.payments' => 'Payments',
			'nav.profile' => 'Profile',
			'billing.title' => '支払い設定',
			'billing.paymentMethod' => '支払い方法',
			'billing.addPaymentMethod' => '支払い方法を追加',
			'billing.changePaymentMethod' => '支払い方法を変更',
			'billing.noPaymentMethod' => '支払い方法が設定されていません',
			'billing.paymentMethodAdded' => '支払い方法を追加しました',
			'billing.subscription' => 'サブスクリプション',
			'billing.plan' => 'プラン',
			'billing.status' => 'ステータス',
			'billing.renews' => '更新日',
			'billing.manageSubscription' => 'サブスクリプション管理',
			'billing.plans.light' => 'ライトプラン',
			'billing.plans.standard' => 'スタンダードプラン',
			'billing.plans.premium' => 'プレミアムプラン',
			'billing.noPlan' => '未加入',
			'common.cancel' => 'キャンセル',
			'common.confirm' => '確認',
			'common.save' => '保存',
			'common.days.sunday' => '日曜日',
			'common.days.monday' => '月曜日',
			'common.days.tuesday' => '火曜日',
			'common.days.wednesday' => '水曜日',
			'common.days.thursday' => '木曜日',
			'common.days.friday' => '金曜日',
			'common.days.saturday' => '土曜日',
			'common.error' => ({required Object message}) => 'エラー: ${message}',
			'payout.title' => '出金設定',
			'payout.setupPayout' => '出金設定を行う',
			'payout.payoutSetupDescription' => '報酬を受け取るには出金設定が必要です',
			'payout.changePayoutSettings' => '出金設定を変更',
			'payout.payoutSetupComplete' => '出金設定は完了しています',
			'payout.resumeSetup' => '出金設定を再開する',
			'payout.payoutSetupInProgressDescription' => 'レフェリーをすることはできますが報酬を出金することはできません。出金設定を最後まで終わらせてください。',
			'payout.showHints' => '入力のヒントを表示',
			'payout.hideHints' => '入力のヒントを隠す',
			'payout.hintIndustry' => '業種は「その他の個人向けサービス」を選んでください',
			'payout.hintDescription' => '商品の説明は「依頼を受けたタスクについて進捗内容をレビューします。レビュー完了時に代金が支払われます。」と入力してください',
			'payout.hintDescriptionCopy' => '依頼を受けたタスクについて進捗内容をレビューします。レビュー完了時に代金が支払われます。',
			'payout.hintWebsite' => 'ウェブサイトは「https://peppercheck.com」を入力してください',
			'payout.hintWebsiteCopy' => 'https://peppercheck.com',
			'payout.copiedInputExample' => '入力例をコピーしました',
			'payout.amount' => '金額',
			'payout.invalidAmount' => '金額が不正です',
			'payout.insufficientFunds' => '出金可能額を超えています',
			'payout.enterAmountDescription' => '出金したい金額を入力してください',
			'dashboard.totalEarnings' => '総収益',
			'dashboard.pending' => '保留中',
			'dashboard.available' => '出金可能額',
			'dashboard.requestPayout' => '出金を申請',
			'dashboard.payoutRequested' => '出金申請済み',
			'task.status.draft' => '下書き',
			'task.status.open' => 'マッチング開始',
			'task.status.judging' => '判定中',
			'task.status.rejected' => '却下',
			'task.status.completed' => '完了',
			'task.status.closed' => '終了',
			'task.status.self_completed' => '自己完結',
			'task.status.expired' => '期限切れ',
			'task.status.done' => '完了',
			'task.detail.title' => 'タスク詳細',
			'task.detail.sectionRequests' => 'リクエスト',
			'task.detail.labelStatus' => 'ステータス',
			'task.creation.title' => 'タスク作成',
			'task.creation.titleEdit' => 'タスク編集',
			'task.creation.sectionInfo' => 'タスク情報',
			'task.creation.labelTitle' => 'タイトル',
			'task.creation.labelDescription' => '詳細 (任意)',
			'task.creation.labelCriteria' => '完了条件',
			'task.creation.labelDeadline' => '期限',
			'task.creation.sectionMatching' => 'マッチングプラン',
			'task.creation.buttonAdd' => '追加',
			'task.creation.buttonCreate' => '作成',
			'task.creation.buttonUpdate' => '更新',
			'task.creation.strategy.standard' => 'スタンダード',
			'task.creation.error.title' => 'エラー',
			'task.creation.error.insufficientPoints' => 'ポイントが不足しています',
			'task.creation.error.insufficientPointsDetail' => ({required Object balance, required Object locked, required Object required}) => '現在の残高: ${balance} pt\nロック済み: ${locked} pt\n必要なポイント: ${required} pt',
			'task.creation.error.dueDateTooSoon' => '期限が近すぎます',
			'task.creation.error.dueDateTooSoonDetail' => ({required Object minHours}) => 'タスクの期限は現在時刻から最低 ${minHours} 時間後である必要があります',
			'task.creation.error.walletNotFound' => 'ポイントウォレットが見つかりません',
			'task.creation.error.walletNotFoundDetail' => 'ポイントウォレットの初期化に問題が発生しています。サポートにお問い合わせください。',
			'task.creation.error.unknown' => 'エラーが発生しました',
			'task.creation.error.unknownDetail' => ({required Object message}) => '${message}',
			'task.creation.error.buttonOk' => 'OK',
			'task.evidence.title' => 'エビデンス',
			'task.evidence.submit' => 'エビデンスを提出',
			'task.evidence.submitted' => '提出済みエビデンス',
			'task.evidence.description' => '説明',
			'task.evidence.descriptionPlaceholder' => 'タスクの完了を証明する内容を記述してください',
			'task.evidence.maxImages' => '画像は最大5枚までです',
			'task.evidence.success' => 'エビデンスを提出しました',
			'task.evidence.error' => ({required Object message}) => 'エラーが発生しました: ${message}',
			'profile.title' => 'プロフィール',
			'matching.referee_availability.title' => '受付可能時間',
			'matching.referee_availability.no_slots' => '受付可能時間が設定されていません',
			'matching.referee_availability.add_slot' => '受付時間を追加',
			'matching.referee_availability.edit_slot' => '受付時間を編集',
			'matching.referee_availability.dialog_start_time' => '開始時間',
			'matching.referee_availability.dialog_end_time' => '終了時間',
			'matching.referee_availability.dialog_dow' => '曜日',
			'matching.referee_availability.invalid_time_range' => '終了時間は開始時間より後である必要があります',
			_ => null,
		};
	}
}
