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
	late final TranslationsPayoutJa payout = TranslationsPayoutJa.internal(_root);
	late final TranslationsDashboardJa dashboard = TranslationsDashboardJa.internal(_root);
	late final TranslationsTaskJa task = TranslationsTaskJa.internal(_root);
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
}

// Path: task.status
class TranslationsTaskStatusJa {
	TranslationsTaskStatusJa.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ja: '下書き'
	String get draft => '下書き';

	/// ja: '募集中'
	String get open => '募集中';

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
			'payout.title' => '出金設定',
			'payout.setupPayout' => '出金設定を行う',
			'payout.payoutSetupDescription' => '報酬を受け取るには出金設定が必要です',
			'payout.changePayoutSettings' => '出金設定を変更',
			'payout.payoutSetupComplete' => '出金設定は完了しています',
			'dashboard.totalEarnings' => '総収益',
			'dashboard.pending' => '保留中',
			'dashboard.available' => '出金可能額',
			'dashboard.requestPayout' => '出金を申請',
			'dashboard.payoutRequested' => '出金申請済み',
			'task.status.draft' => '下書き',
			'task.status.open' => '募集中',
			'task.status.judging' => '判定中',
			'task.status.rejected' => '却下',
			'task.status.completed' => '完了',
			'task.status.closed' => '終了',
			'task.status.self_completed' => '自己完結',
			'task.status.expired' => '期限切れ',
			'task.status.done' => '完了',
			_ => null,
		};
	}
}
