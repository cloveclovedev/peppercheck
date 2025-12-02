// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payout_request_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PayoutRequestResponse {

 String get id; String get status;
/// Create a copy of PayoutRequestResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PayoutRequestResponseCopyWith<PayoutRequestResponse> get copyWith => _$PayoutRequestResponseCopyWithImpl<PayoutRequestResponse>(this as PayoutRequestResponse, _$identity);

  /// Serializes this PayoutRequestResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PayoutRequestResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,status);

@override
String toString() {
  return 'PayoutRequestResponse(id: $id, status: $status)';
}


}

/// @nodoc
abstract mixin class $PayoutRequestResponseCopyWith<$Res>  {
  factory $PayoutRequestResponseCopyWith(PayoutRequestResponse value, $Res Function(PayoutRequestResponse) _then) = _$PayoutRequestResponseCopyWithImpl;
@useResult
$Res call({
 String id, String status
});




}
/// @nodoc
class _$PayoutRequestResponseCopyWithImpl<$Res>
    implements $PayoutRequestResponseCopyWith<$Res> {
  _$PayoutRequestResponseCopyWithImpl(this._self, this._then);

  final PayoutRequestResponse _self;
  final $Res Function(PayoutRequestResponse) _then;

/// Create a copy of PayoutRequestResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? status = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PayoutRequestResponse].
extension PayoutRequestResponsePatterns on PayoutRequestResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PayoutRequestResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PayoutRequestResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PayoutRequestResponse value)  $default,){
final _that = this;
switch (_that) {
case _PayoutRequestResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PayoutRequestResponse value)?  $default,){
final _that = this;
switch (_that) {
case _PayoutRequestResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PayoutRequestResponse() when $default != null:
return $default(_that.id,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String status)  $default,) {final _that = this;
switch (_that) {
case _PayoutRequestResponse():
return $default(_that.id,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String status)?  $default,) {final _that = this;
switch (_that) {
case _PayoutRequestResponse() when $default != null:
return $default(_that.id,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PayoutRequestResponse implements PayoutRequestResponse {
  const _PayoutRequestResponse({required this.id, required this.status});
  factory _PayoutRequestResponse.fromJson(Map<String, dynamic> json) => _$PayoutRequestResponseFromJson(json);

@override final  String id;
@override final  String status;

/// Create a copy of PayoutRequestResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PayoutRequestResponseCopyWith<_PayoutRequestResponse> get copyWith => __$PayoutRequestResponseCopyWithImpl<_PayoutRequestResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PayoutRequestResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PayoutRequestResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,status);

@override
String toString() {
  return 'PayoutRequestResponse(id: $id, status: $status)';
}


}

/// @nodoc
abstract mixin class _$PayoutRequestResponseCopyWith<$Res> implements $PayoutRequestResponseCopyWith<$Res> {
  factory _$PayoutRequestResponseCopyWith(_PayoutRequestResponse value, $Res Function(_PayoutRequestResponse) _then) = __$PayoutRequestResponseCopyWithImpl;
@override @useResult
$Res call({
 String id, String status
});




}
/// @nodoc
class __$PayoutRequestResponseCopyWithImpl<$Res>
    implements _$PayoutRequestResponseCopyWith<$Res> {
  __$PayoutRequestResponseCopyWithImpl(this._self, this._then);

  final _PayoutRequestResponse _self;
  final $Res Function(_PayoutRequestResponse) _then;

/// Create a copy of PayoutRequestResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? status = null,}) {
  return _then(_PayoutRequestResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
