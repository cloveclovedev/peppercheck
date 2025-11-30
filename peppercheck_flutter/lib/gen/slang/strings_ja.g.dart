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
