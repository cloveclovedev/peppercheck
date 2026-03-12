// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'referee_obligation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RefereeObligation {

 String get id; String get status;@JsonKey(name: 'source_request_id') String get sourceRequestId;@JsonKey(name: 'fulfill_request_id') String? get fulfillRequestId;@JsonKey(name: 'created_at') String get createdAt;@JsonKey(name: 'fulfilled_at') String? get fulfilledAt;
/// Create a copy of RefereeObligation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RefereeObligationCopyWith<RefereeObligation> get copyWith => _$RefereeObligationCopyWithImpl<RefereeObligation>(this as RefereeObligation, _$identity);

  /// Serializes this RefereeObligation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RefereeObligation&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.sourceRequestId, sourceRequestId) || other.sourceRequestId == sourceRequestId)&&(identical(other.fulfillRequestId, fulfillRequestId) || other.fulfillRequestId == fulfillRequestId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.fulfilledAt, fulfilledAt) || other.fulfilledAt == fulfilledAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,status,sourceRequestId,fulfillRequestId,createdAt,fulfilledAt);

@override
String toString() {
  return 'RefereeObligation(id: $id, status: $status, sourceRequestId: $sourceRequestId, fulfillRequestId: $fulfillRequestId, createdAt: $createdAt, fulfilledAt: $fulfilledAt)';
}


}

/// @nodoc
abstract mixin class $RefereeObligationCopyWith<$Res>  {
  factory $RefereeObligationCopyWith(RefereeObligation value, $Res Function(RefereeObligation) _then) = _$RefereeObligationCopyWithImpl;
@useResult
$Res call({
 String id, String status,@JsonKey(name: 'source_request_id') String sourceRequestId,@JsonKey(name: 'fulfill_request_id') String? fulfillRequestId,@JsonKey(name: 'created_at') String createdAt,@JsonKey(name: 'fulfilled_at') String? fulfilledAt
});




}
/// @nodoc
class _$RefereeObligationCopyWithImpl<$Res>
    implements $RefereeObligationCopyWith<$Res> {
  _$RefereeObligationCopyWithImpl(this._self, this._then);

  final RefereeObligation _self;
  final $Res Function(RefereeObligation) _then;

/// Create a copy of RefereeObligation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? status = null,Object? sourceRequestId = null,Object? fulfillRequestId = freezed,Object? createdAt = null,Object? fulfilledAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,sourceRequestId: null == sourceRequestId ? _self.sourceRequestId : sourceRequestId // ignore: cast_nullable_to_non_nullable
as String,fulfillRequestId: freezed == fulfillRequestId ? _self.fulfillRequestId : fulfillRequestId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,fulfilledAt: freezed == fulfilledAt ? _self.fulfilledAt : fulfilledAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RefereeObligation].
extension RefereeObligationPatterns on RefereeObligation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RefereeObligation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RefereeObligation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RefereeObligation value)  $default,){
final _that = this;
switch (_that) {
case _RefereeObligation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RefereeObligation value)?  $default,){
final _that = this;
switch (_that) {
case _RefereeObligation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String status, @JsonKey(name: 'source_request_id')  String sourceRequestId, @JsonKey(name: 'fulfill_request_id')  String? fulfillRequestId, @JsonKey(name: 'created_at')  String createdAt, @JsonKey(name: 'fulfilled_at')  String? fulfilledAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RefereeObligation() when $default != null:
return $default(_that.id,_that.status,_that.sourceRequestId,_that.fulfillRequestId,_that.createdAt,_that.fulfilledAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String status, @JsonKey(name: 'source_request_id')  String sourceRequestId, @JsonKey(name: 'fulfill_request_id')  String? fulfillRequestId, @JsonKey(name: 'created_at')  String createdAt, @JsonKey(name: 'fulfilled_at')  String? fulfilledAt)  $default,) {final _that = this;
switch (_that) {
case _RefereeObligation():
return $default(_that.id,_that.status,_that.sourceRequestId,_that.fulfillRequestId,_that.createdAt,_that.fulfilledAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String status, @JsonKey(name: 'source_request_id')  String sourceRequestId, @JsonKey(name: 'fulfill_request_id')  String? fulfillRequestId, @JsonKey(name: 'created_at')  String createdAt, @JsonKey(name: 'fulfilled_at')  String? fulfilledAt)?  $default,) {final _that = this;
switch (_that) {
case _RefereeObligation() when $default != null:
return $default(_that.id,_that.status,_that.sourceRequestId,_that.fulfillRequestId,_that.createdAt,_that.fulfilledAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RefereeObligation implements RefereeObligation {
  const _RefereeObligation({required this.id, required this.status, @JsonKey(name: 'source_request_id') required this.sourceRequestId, @JsonKey(name: 'fulfill_request_id') this.fulfillRequestId, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'fulfilled_at') this.fulfilledAt});
  factory _RefereeObligation.fromJson(Map<String, dynamic> json) => _$RefereeObligationFromJson(json);

@override final  String id;
@override final  String status;
@override@JsonKey(name: 'source_request_id') final  String sourceRequestId;
@override@JsonKey(name: 'fulfill_request_id') final  String? fulfillRequestId;
@override@JsonKey(name: 'created_at') final  String createdAt;
@override@JsonKey(name: 'fulfilled_at') final  String? fulfilledAt;

/// Create a copy of RefereeObligation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RefereeObligationCopyWith<_RefereeObligation> get copyWith => __$RefereeObligationCopyWithImpl<_RefereeObligation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RefereeObligationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefereeObligation&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.sourceRequestId, sourceRequestId) || other.sourceRequestId == sourceRequestId)&&(identical(other.fulfillRequestId, fulfillRequestId) || other.fulfillRequestId == fulfillRequestId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.fulfilledAt, fulfilledAt) || other.fulfilledAt == fulfilledAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,status,sourceRequestId,fulfillRequestId,createdAt,fulfilledAt);

@override
String toString() {
  return 'RefereeObligation(id: $id, status: $status, sourceRequestId: $sourceRequestId, fulfillRequestId: $fulfillRequestId, createdAt: $createdAt, fulfilledAt: $fulfilledAt)';
}


}

/// @nodoc
abstract mixin class _$RefereeObligationCopyWith<$Res> implements $RefereeObligationCopyWith<$Res> {
  factory _$RefereeObligationCopyWith(_RefereeObligation value, $Res Function(_RefereeObligation) _then) = __$RefereeObligationCopyWithImpl;
@override @useResult
$Res call({
 String id, String status,@JsonKey(name: 'source_request_id') String sourceRequestId,@JsonKey(name: 'fulfill_request_id') String? fulfillRequestId,@JsonKey(name: 'created_at') String createdAt,@JsonKey(name: 'fulfilled_at') String? fulfilledAt
});




}
/// @nodoc
class __$RefereeObligationCopyWithImpl<$Res>
    implements _$RefereeObligationCopyWith<$Res> {
  __$RefereeObligationCopyWithImpl(this._self, this._then);

  final _RefereeObligation _self;
  final $Res Function(_RefereeObligation) _then;

/// Create a copy of RefereeObligation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? status = null,Object? sourceRequestId = null,Object? fulfillRequestId = freezed,Object? createdAt = null,Object? fulfilledAt = freezed,}) {
  return _then(_RefereeObligation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,sourceRequestId: null == sourceRequestId ? _self.sourceRequestId : sourceRequestId // ignore: cast_nullable_to_non_nullable
as String,fulfillRequestId: freezed == fulfillRequestId ? _self.fulfillRequestId : fulfillRequestId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,fulfilledAt: freezed == fulfilledAt ? _self.fulfilledAt : fulfilledAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
