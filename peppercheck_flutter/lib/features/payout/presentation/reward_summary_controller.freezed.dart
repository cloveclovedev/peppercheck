// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reward_summary_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RewardSummaryState {

 RewardSummary get summary; Currency get currency; bool get isRequestingPayout;
/// Create a copy of RewardSummaryState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RewardSummaryStateCopyWith<RewardSummaryState> get copyWith => _$RewardSummaryStateCopyWithImpl<RewardSummaryState>(this as RewardSummaryState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RewardSummaryState&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.isRequestingPayout, isRequestingPayout) || other.isRequestingPayout == isRequestingPayout));
}


@override
int get hashCode => Object.hash(runtimeType,summary,currency,isRequestingPayout);

@override
String toString() {
  return 'RewardSummaryState(summary: $summary, currency: $currency, isRequestingPayout: $isRequestingPayout)';
}


}

/// @nodoc
abstract mixin class $RewardSummaryStateCopyWith<$Res>  {
  factory $RewardSummaryStateCopyWith(RewardSummaryState value, $Res Function(RewardSummaryState) _then) = _$RewardSummaryStateCopyWithImpl;
@useResult
$Res call({
 RewardSummary summary, Currency currency, bool isRequestingPayout
});


$RewardSummaryCopyWith<$Res> get summary;$CurrencyCopyWith<$Res> get currency;

}
/// @nodoc
class _$RewardSummaryStateCopyWithImpl<$Res>
    implements $RewardSummaryStateCopyWith<$Res> {
  _$RewardSummaryStateCopyWithImpl(this._self, this._then);

  final RewardSummaryState _self;
  final $Res Function(RewardSummaryState) _then;

/// Create a copy of RewardSummaryState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? summary = null,Object? currency = null,Object? isRequestingPayout = null,}) {
  return _then(_self.copyWith(
summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as RewardSummary,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as Currency,isRequestingPayout: null == isRequestingPayout ? _self.isRequestingPayout : isRequestingPayout // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of RewardSummaryState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RewardSummaryCopyWith<$Res> get summary {
  
  return $RewardSummaryCopyWith<$Res>(_self.summary, (value) {
    return _then(_self.copyWith(summary: value));
  });
}/// Create a copy of RewardSummaryState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CurrencyCopyWith<$Res> get currency {
  
  return $CurrencyCopyWith<$Res>(_self.currency, (value) {
    return _then(_self.copyWith(currency: value));
  });
}
}


/// Adds pattern-matching-related methods to [RewardSummaryState].
extension RewardSummaryStatePatterns on RewardSummaryState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RewardSummaryState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RewardSummaryState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RewardSummaryState value)  $default,){
final _that = this;
switch (_that) {
case _RewardSummaryState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RewardSummaryState value)?  $default,){
final _that = this;
switch (_that) {
case _RewardSummaryState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( RewardSummary summary,  Currency currency,  bool isRequestingPayout)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RewardSummaryState() when $default != null:
return $default(_that.summary,_that.currency,_that.isRequestingPayout);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( RewardSummary summary,  Currency currency,  bool isRequestingPayout)  $default,) {final _that = this;
switch (_that) {
case _RewardSummaryState():
return $default(_that.summary,_that.currency,_that.isRequestingPayout);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( RewardSummary summary,  Currency currency,  bool isRequestingPayout)?  $default,) {final _that = this;
switch (_that) {
case _RewardSummaryState() when $default != null:
return $default(_that.summary,_that.currency,_that.isRequestingPayout);case _:
  return null;

}
}

}

/// @nodoc


class _RewardSummaryState implements RewardSummaryState {
  const _RewardSummaryState({required this.summary, required this.currency, this.isRequestingPayout = false});
  

@override final  RewardSummary summary;
@override final  Currency currency;
@override@JsonKey() final  bool isRequestingPayout;

/// Create a copy of RewardSummaryState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RewardSummaryStateCopyWith<_RewardSummaryState> get copyWith => __$RewardSummaryStateCopyWithImpl<_RewardSummaryState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RewardSummaryState&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.isRequestingPayout, isRequestingPayout) || other.isRequestingPayout == isRequestingPayout));
}


@override
int get hashCode => Object.hash(runtimeType,summary,currency,isRequestingPayout);

@override
String toString() {
  return 'RewardSummaryState(summary: $summary, currency: $currency, isRequestingPayout: $isRequestingPayout)';
}


}

/// @nodoc
abstract mixin class _$RewardSummaryStateCopyWith<$Res> implements $RewardSummaryStateCopyWith<$Res> {
  factory _$RewardSummaryStateCopyWith(_RewardSummaryState value, $Res Function(_RewardSummaryState) _then) = __$RewardSummaryStateCopyWithImpl;
@override @useResult
$Res call({
 RewardSummary summary, Currency currency, bool isRequestingPayout
});


@override $RewardSummaryCopyWith<$Res> get summary;@override $CurrencyCopyWith<$Res> get currency;

}
/// @nodoc
class __$RewardSummaryStateCopyWithImpl<$Res>
    implements _$RewardSummaryStateCopyWith<$Res> {
  __$RewardSummaryStateCopyWithImpl(this._self, this._then);

  final _RewardSummaryState _self;
  final $Res Function(_RewardSummaryState) _then;

/// Create a copy of RewardSummaryState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? summary = null,Object? currency = null,Object? isRequestingPayout = null,}) {
  return _then(_RewardSummaryState(
summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as RewardSummary,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as Currency,isRequestingPayout: null == isRequestingPayout ? _self.isRequestingPayout : isRequestingPayout // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of RewardSummaryState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RewardSummaryCopyWith<$Res> get summary {
  
  return $RewardSummaryCopyWith<$Res>(_self.summary, (value) {
    return _then(_self.copyWith(summary: value));
  });
}/// Create a copy of RewardSummaryState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CurrencyCopyWith<$Res> get currency {
  
  return $CurrencyCopyWith<$Res>(_self.currency, (value) {
    return _then(_self.copyWith(currency: value));
  });
}
}

// dart format on
