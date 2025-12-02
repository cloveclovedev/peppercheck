// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reward_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RewardSummary {

@JsonKey(name: 'available_minor') int get availableMinor;@JsonKey(name: 'pending_minor') int get pendingMinor;@JsonKey(name: 'incoming_pending_minor') int get incomingPendingMinor;@JsonKey(name: 'currency_code') String get currencyCode;
/// Create a copy of RewardSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RewardSummaryCopyWith<RewardSummary> get copyWith => _$RewardSummaryCopyWithImpl<RewardSummary>(this as RewardSummary, _$identity);

  /// Serializes this RewardSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RewardSummary&&(identical(other.availableMinor, availableMinor) || other.availableMinor == availableMinor)&&(identical(other.pendingMinor, pendingMinor) || other.pendingMinor == pendingMinor)&&(identical(other.incomingPendingMinor, incomingPendingMinor) || other.incomingPendingMinor == incomingPendingMinor)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,availableMinor,pendingMinor,incomingPendingMinor,currencyCode);

@override
String toString() {
  return 'RewardSummary(availableMinor: $availableMinor, pendingMinor: $pendingMinor, incomingPendingMinor: $incomingPendingMinor, currencyCode: $currencyCode)';
}


}

/// @nodoc
abstract mixin class $RewardSummaryCopyWith<$Res>  {
  factory $RewardSummaryCopyWith(RewardSummary value, $Res Function(RewardSummary) _then) = _$RewardSummaryCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'available_minor') int availableMinor,@JsonKey(name: 'pending_minor') int pendingMinor,@JsonKey(name: 'incoming_pending_minor') int incomingPendingMinor,@JsonKey(name: 'currency_code') String currencyCode
});




}
/// @nodoc
class _$RewardSummaryCopyWithImpl<$Res>
    implements $RewardSummaryCopyWith<$Res> {
  _$RewardSummaryCopyWithImpl(this._self, this._then);

  final RewardSummary _self;
  final $Res Function(RewardSummary) _then;

/// Create a copy of RewardSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? availableMinor = null,Object? pendingMinor = null,Object? incomingPendingMinor = null,Object? currencyCode = null,}) {
  return _then(_self.copyWith(
availableMinor: null == availableMinor ? _self.availableMinor : availableMinor // ignore: cast_nullable_to_non_nullable
as int,pendingMinor: null == pendingMinor ? _self.pendingMinor : pendingMinor // ignore: cast_nullable_to_non_nullable
as int,incomingPendingMinor: null == incomingPendingMinor ? _self.incomingPendingMinor : incomingPendingMinor // ignore: cast_nullable_to_non_nullable
as int,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RewardSummary].
extension RewardSummaryPatterns on RewardSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RewardSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RewardSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RewardSummary value)  $default,){
final _that = this;
switch (_that) {
case _RewardSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RewardSummary value)?  $default,){
final _that = this;
switch (_that) {
case _RewardSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'available_minor')  int availableMinor, @JsonKey(name: 'pending_minor')  int pendingMinor, @JsonKey(name: 'incoming_pending_minor')  int incomingPendingMinor, @JsonKey(name: 'currency_code')  String currencyCode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RewardSummary() when $default != null:
return $default(_that.availableMinor,_that.pendingMinor,_that.incomingPendingMinor,_that.currencyCode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'available_minor')  int availableMinor, @JsonKey(name: 'pending_minor')  int pendingMinor, @JsonKey(name: 'incoming_pending_minor')  int incomingPendingMinor, @JsonKey(name: 'currency_code')  String currencyCode)  $default,) {final _that = this;
switch (_that) {
case _RewardSummary():
return $default(_that.availableMinor,_that.pendingMinor,_that.incomingPendingMinor,_that.currencyCode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'available_minor')  int availableMinor, @JsonKey(name: 'pending_minor')  int pendingMinor, @JsonKey(name: 'incoming_pending_minor')  int incomingPendingMinor, @JsonKey(name: 'currency_code')  String currencyCode)?  $default,) {final _that = this;
switch (_that) {
case _RewardSummary() when $default != null:
return $default(_that.availableMinor,_that.pendingMinor,_that.incomingPendingMinor,_that.currencyCode);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RewardSummary implements RewardSummary {
  const _RewardSummary({@JsonKey(name: 'available_minor') required this.availableMinor, @JsonKey(name: 'pending_minor') required this.pendingMinor, @JsonKey(name: 'incoming_pending_minor') required this.incomingPendingMinor, @JsonKey(name: 'currency_code') required this.currencyCode});
  factory _RewardSummary.fromJson(Map<String, dynamic> json) => _$RewardSummaryFromJson(json);

@override@JsonKey(name: 'available_minor') final  int availableMinor;
@override@JsonKey(name: 'pending_minor') final  int pendingMinor;
@override@JsonKey(name: 'incoming_pending_minor') final  int incomingPendingMinor;
@override@JsonKey(name: 'currency_code') final  String currencyCode;

/// Create a copy of RewardSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RewardSummaryCopyWith<_RewardSummary> get copyWith => __$RewardSummaryCopyWithImpl<_RewardSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RewardSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RewardSummary&&(identical(other.availableMinor, availableMinor) || other.availableMinor == availableMinor)&&(identical(other.pendingMinor, pendingMinor) || other.pendingMinor == pendingMinor)&&(identical(other.incomingPendingMinor, incomingPendingMinor) || other.incomingPendingMinor == incomingPendingMinor)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,availableMinor,pendingMinor,incomingPendingMinor,currencyCode);

@override
String toString() {
  return 'RewardSummary(availableMinor: $availableMinor, pendingMinor: $pendingMinor, incomingPendingMinor: $incomingPendingMinor, currencyCode: $currencyCode)';
}


}

/// @nodoc
abstract mixin class _$RewardSummaryCopyWith<$Res> implements $RewardSummaryCopyWith<$Res> {
  factory _$RewardSummaryCopyWith(_RewardSummary value, $Res Function(_RewardSummary) _then) = __$RewardSummaryCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'available_minor') int availableMinor,@JsonKey(name: 'pending_minor') int pendingMinor,@JsonKey(name: 'incoming_pending_minor') int incomingPendingMinor,@JsonKey(name: 'currency_code') String currencyCode
});




}
/// @nodoc
class __$RewardSummaryCopyWithImpl<$Res>
    implements _$RewardSummaryCopyWith<$Res> {
  __$RewardSummaryCopyWithImpl(this._self, this._then);

  final _RewardSummary _self;
  final $Res Function(_RewardSummary) _then;

/// Create a copy of RewardSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? availableMinor = null,Object? pendingMinor = null,Object? incomingPendingMinor = null,Object? currencyCode = null,}) {
  return _then(_RewardSummary(
availableMinor: null == availableMinor ? _self.availableMinor : availableMinor // ignore: cast_nullable_to_non_nullable
as int,pendingMinor: null == pendingMinor ? _self.pendingMinor : pendingMinor // ignore: cast_nullable_to_non_nullable
as int,incomingPendingMinor: null == incomingPendingMinor ? _self.incomingPendingMinor : incomingPendingMinor // ignore: cast_nullable_to_non_nullable
as int,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
