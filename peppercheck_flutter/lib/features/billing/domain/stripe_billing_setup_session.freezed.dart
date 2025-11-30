// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stripe_billing_setup_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StripeBillingSetupSession {

@JsonKey(name: 'customerId') String get customerId;@JsonKey(name: 'setupIntentClientSecret') String get setupIntentClientSecret;@JsonKey(name: 'ephemeralKeySecret') String get ephemeralKeySecret;
/// Create a copy of StripeBillingSetupSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StripeBillingSetupSessionCopyWith<StripeBillingSetupSession> get copyWith => _$StripeBillingSetupSessionCopyWithImpl<StripeBillingSetupSession>(this as StripeBillingSetupSession, _$identity);

  /// Serializes this StripeBillingSetupSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StripeBillingSetupSession&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.setupIntentClientSecret, setupIntentClientSecret) || other.setupIntentClientSecret == setupIntentClientSecret)&&(identical(other.ephemeralKeySecret, ephemeralKeySecret) || other.ephemeralKeySecret == ephemeralKeySecret));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,customerId,setupIntentClientSecret,ephemeralKeySecret);

@override
String toString() {
  return 'StripeBillingSetupSession(customerId: $customerId, setupIntentClientSecret: $setupIntentClientSecret, ephemeralKeySecret: $ephemeralKeySecret)';
}


}

/// @nodoc
abstract mixin class $StripeBillingSetupSessionCopyWith<$Res>  {
  factory $StripeBillingSetupSessionCopyWith(StripeBillingSetupSession value, $Res Function(StripeBillingSetupSession) _then) = _$StripeBillingSetupSessionCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'customerId') String customerId,@JsonKey(name: 'setupIntentClientSecret') String setupIntentClientSecret,@JsonKey(name: 'ephemeralKeySecret') String ephemeralKeySecret
});




}
/// @nodoc
class _$StripeBillingSetupSessionCopyWithImpl<$Res>
    implements $StripeBillingSetupSessionCopyWith<$Res> {
  _$StripeBillingSetupSessionCopyWithImpl(this._self, this._then);

  final StripeBillingSetupSession _self;
  final $Res Function(StripeBillingSetupSession) _then;

/// Create a copy of StripeBillingSetupSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? customerId = null,Object? setupIntentClientSecret = null,Object? ephemeralKeySecret = null,}) {
  return _then(_self.copyWith(
customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,setupIntentClientSecret: null == setupIntentClientSecret ? _self.setupIntentClientSecret : setupIntentClientSecret // ignore: cast_nullable_to_non_nullable
as String,ephemeralKeySecret: null == ephemeralKeySecret ? _self.ephemeralKeySecret : ephemeralKeySecret // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [StripeBillingSetupSession].
extension StripeBillingSetupSessionPatterns on StripeBillingSetupSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StripeBillingSetupSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StripeBillingSetupSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StripeBillingSetupSession value)  $default,){
final _that = this;
switch (_that) {
case _StripeBillingSetupSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StripeBillingSetupSession value)?  $default,){
final _that = this;
switch (_that) {
case _StripeBillingSetupSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'customerId')  String customerId, @JsonKey(name: 'setupIntentClientSecret')  String setupIntentClientSecret, @JsonKey(name: 'ephemeralKeySecret')  String ephemeralKeySecret)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StripeBillingSetupSession() when $default != null:
return $default(_that.customerId,_that.setupIntentClientSecret,_that.ephemeralKeySecret);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'customerId')  String customerId, @JsonKey(name: 'setupIntentClientSecret')  String setupIntentClientSecret, @JsonKey(name: 'ephemeralKeySecret')  String ephemeralKeySecret)  $default,) {final _that = this;
switch (_that) {
case _StripeBillingSetupSession():
return $default(_that.customerId,_that.setupIntentClientSecret,_that.ephemeralKeySecret);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'customerId')  String customerId, @JsonKey(name: 'setupIntentClientSecret')  String setupIntentClientSecret, @JsonKey(name: 'ephemeralKeySecret')  String ephemeralKeySecret)?  $default,) {final _that = this;
switch (_that) {
case _StripeBillingSetupSession() when $default != null:
return $default(_that.customerId,_that.setupIntentClientSecret,_that.ephemeralKeySecret);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StripeBillingSetupSession implements StripeBillingSetupSession {
  const _StripeBillingSetupSession({@JsonKey(name: 'customerId') required this.customerId, @JsonKey(name: 'setupIntentClientSecret') required this.setupIntentClientSecret, @JsonKey(name: 'ephemeralKeySecret') required this.ephemeralKeySecret});
  factory _StripeBillingSetupSession.fromJson(Map<String, dynamic> json) => _$StripeBillingSetupSessionFromJson(json);

@override@JsonKey(name: 'customerId') final  String customerId;
@override@JsonKey(name: 'setupIntentClientSecret') final  String setupIntentClientSecret;
@override@JsonKey(name: 'ephemeralKeySecret') final  String ephemeralKeySecret;

/// Create a copy of StripeBillingSetupSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StripeBillingSetupSessionCopyWith<_StripeBillingSetupSession> get copyWith => __$StripeBillingSetupSessionCopyWithImpl<_StripeBillingSetupSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StripeBillingSetupSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StripeBillingSetupSession&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.setupIntentClientSecret, setupIntentClientSecret) || other.setupIntentClientSecret == setupIntentClientSecret)&&(identical(other.ephemeralKeySecret, ephemeralKeySecret) || other.ephemeralKeySecret == ephemeralKeySecret));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,customerId,setupIntentClientSecret,ephemeralKeySecret);

@override
String toString() {
  return 'StripeBillingSetupSession(customerId: $customerId, setupIntentClientSecret: $setupIntentClientSecret, ephemeralKeySecret: $ephemeralKeySecret)';
}


}

/// @nodoc
abstract mixin class _$StripeBillingSetupSessionCopyWith<$Res> implements $StripeBillingSetupSessionCopyWith<$Res> {
  factory _$StripeBillingSetupSessionCopyWith(_StripeBillingSetupSession value, $Res Function(_StripeBillingSetupSession) _then) = __$StripeBillingSetupSessionCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'customerId') String customerId,@JsonKey(name: 'setupIntentClientSecret') String setupIntentClientSecret,@JsonKey(name: 'ephemeralKeySecret') String ephemeralKeySecret
});




}
/// @nodoc
class __$StripeBillingSetupSessionCopyWithImpl<$Res>
    implements _$StripeBillingSetupSessionCopyWith<$Res> {
  __$StripeBillingSetupSessionCopyWithImpl(this._self, this._then);

  final _StripeBillingSetupSession _self;
  final $Res Function(_StripeBillingSetupSession) _then;

/// Create a copy of StripeBillingSetupSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? customerId = null,Object? setupIntentClientSecret = null,Object? ephemeralKeySecret = null,}) {
  return _then(_StripeBillingSetupSession(
customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,setupIntentClientSecret: null == setupIntentClientSecret ? _self.setupIntentClientSecret : setupIntentClientSecret // ignore: cast_nullable_to_non_nullable
as String,ephemeralKeySecret: null == ephemeralKeySecret ? _self.ephemeralKeySecret : ephemeralKeySecret // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
