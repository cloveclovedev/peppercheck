// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'referee_available_time_slot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RefereeAvailableTimeSlot {

 String get id;@JsonKey(name: 'user_id') String get userId; int get dow;@JsonKey(name: 'start_min') int get startMin;@JsonKey(name: 'end_min') int get endMin;@JsonKey(name: 'is_active') bool get isActive;@JsonKey(name: 'created_at') String? get createdAt;@JsonKey(name: 'updated_at') String? get updatedAt;
/// Create a copy of RefereeAvailableTimeSlot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RefereeAvailableTimeSlotCopyWith<RefereeAvailableTimeSlot> get copyWith => _$RefereeAvailableTimeSlotCopyWithImpl<RefereeAvailableTimeSlot>(this as RefereeAvailableTimeSlot, _$identity);

  /// Serializes this RefereeAvailableTimeSlot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RefereeAvailableTimeSlot&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.dow, dow) || other.dow == dow)&&(identical(other.startMin, startMin) || other.startMin == startMin)&&(identical(other.endMin, endMin) || other.endMin == endMin)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,dow,startMin,endMin,isActive,createdAt,updatedAt);

@override
String toString() {
  return 'RefereeAvailableTimeSlot(id: $id, userId: $userId, dow: $dow, startMin: $startMin, endMin: $endMin, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $RefereeAvailableTimeSlotCopyWith<$Res>  {
  factory $RefereeAvailableTimeSlotCopyWith(RefereeAvailableTimeSlot value, $Res Function(RefereeAvailableTimeSlot) _then) = _$RefereeAvailableTimeSlotCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId, int dow,@JsonKey(name: 'start_min') int startMin,@JsonKey(name: 'end_min') int endMin,@JsonKey(name: 'is_active') bool isActive,@JsonKey(name: 'created_at') String? createdAt,@JsonKey(name: 'updated_at') String? updatedAt
});




}
/// @nodoc
class _$RefereeAvailableTimeSlotCopyWithImpl<$Res>
    implements $RefereeAvailableTimeSlotCopyWith<$Res> {
  _$RefereeAvailableTimeSlotCopyWithImpl(this._self, this._then);

  final RefereeAvailableTimeSlot _self;
  final $Res Function(RefereeAvailableTimeSlot) _then;

/// Create a copy of RefereeAvailableTimeSlot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? dow = null,Object? startMin = null,Object? endMin = null,Object? isActive = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,dow: null == dow ? _self.dow : dow // ignore: cast_nullable_to_non_nullable
as int,startMin: null == startMin ? _self.startMin : startMin // ignore: cast_nullable_to_non_nullable
as int,endMin: null == endMin ? _self.endMin : endMin // ignore: cast_nullable_to_non_nullable
as int,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RefereeAvailableTimeSlot].
extension RefereeAvailableTimeSlotPatterns on RefereeAvailableTimeSlot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RefereeAvailableTimeSlot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RefereeAvailableTimeSlot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RefereeAvailableTimeSlot value)  $default,){
final _that = this;
switch (_that) {
case _RefereeAvailableTimeSlot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RefereeAvailableTimeSlot value)?  $default,){
final _that = this;
switch (_that) {
case _RefereeAvailableTimeSlot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId,  int dow, @JsonKey(name: 'start_min')  int startMin, @JsonKey(name: 'end_min')  int endMin, @JsonKey(name: 'is_active')  bool isActive, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'updated_at')  String? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RefereeAvailableTimeSlot() when $default != null:
return $default(_that.id,_that.userId,_that.dow,_that.startMin,_that.endMin,_that.isActive,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId,  int dow, @JsonKey(name: 'start_min')  int startMin, @JsonKey(name: 'end_min')  int endMin, @JsonKey(name: 'is_active')  bool isActive, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'updated_at')  String? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _RefereeAvailableTimeSlot():
return $default(_that.id,_that.userId,_that.dow,_that.startMin,_that.endMin,_that.isActive,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String userId,  int dow, @JsonKey(name: 'start_min')  int startMin, @JsonKey(name: 'end_min')  int endMin, @JsonKey(name: 'is_active')  bool isActive, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'updated_at')  String? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _RefereeAvailableTimeSlot() when $default != null:
return $default(_that.id,_that.userId,_that.dow,_that.startMin,_that.endMin,_that.isActive,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RefereeAvailableTimeSlot implements RefereeAvailableTimeSlot {
  const _RefereeAvailableTimeSlot({required this.id, @JsonKey(name: 'user_id') required this.userId, required this.dow, @JsonKey(name: 'start_min') required this.startMin, @JsonKey(name: 'end_min') required this.endMin, @JsonKey(name: 'is_active') required this.isActive, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt});
  factory _RefereeAvailableTimeSlot.fromJson(Map<String, dynamic> json) => _$RefereeAvailableTimeSlotFromJson(json);

@override final  String id;
@override@JsonKey(name: 'user_id') final  String userId;
@override final  int dow;
@override@JsonKey(name: 'start_min') final  int startMin;
@override@JsonKey(name: 'end_min') final  int endMin;
@override@JsonKey(name: 'is_active') final  bool isActive;
@override@JsonKey(name: 'created_at') final  String? createdAt;
@override@JsonKey(name: 'updated_at') final  String? updatedAt;

/// Create a copy of RefereeAvailableTimeSlot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RefereeAvailableTimeSlotCopyWith<_RefereeAvailableTimeSlot> get copyWith => __$RefereeAvailableTimeSlotCopyWithImpl<_RefereeAvailableTimeSlot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RefereeAvailableTimeSlotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefereeAvailableTimeSlot&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.dow, dow) || other.dow == dow)&&(identical(other.startMin, startMin) || other.startMin == startMin)&&(identical(other.endMin, endMin) || other.endMin == endMin)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,dow,startMin,endMin,isActive,createdAt,updatedAt);

@override
String toString() {
  return 'RefereeAvailableTimeSlot(id: $id, userId: $userId, dow: $dow, startMin: $startMin, endMin: $endMin, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$RefereeAvailableTimeSlotCopyWith<$Res> implements $RefereeAvailableTimeSlotCopyWith<$Res> {
  factory _$RefereeAvailableTimeSlotCopyWith(_RefereeAvailableTimeSlot value, $Res Function(_RefereeAvailableTimeSlot) _then) = __$RefereeAvailableTimeSlotCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId, int dow,@JsonKey(name: 'start_min') int startMin,@JsonKey(name: 'end_min') int endMin,@JsonKey(name: 'is_active') bool isActive,@JsonKey(name: 'created_at') String? createdAt,@JsonKey(name: 'updated_at') String? updatedAt
});




}
/// @nodoc
class __$RefereeAvailableTimeSlotCopyWithImpl<$Res>
    implements _$RefereeAvailableTimeSlotCopyWith<$Res> {
  __$RefereeAvailableTimeSlotCopyWithImpl(this._self, this._then);

  final _RefereeAvailableTimeSlot _self;
  final $Res Function(_RefereeAvailableTimeSlot) _then;

/// Create a copy of RefereeAvailableTimeSlot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? dow = null,Object? startMin = null,Object? endMin = null,Object? isActive = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_RefereeAvailableTimeSlot(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,dow: null == dow ? _self.dow : dow // ignore: cast_nullable_to_non_nullable
as int,startMin: null == startMin ? _self.startMin : startMin // ignore: cast_nullable_to_non_nullable
as int,endMin: null == endMin ? _self.endMin : endMin // ignore: cast_nullable_to_non_nullable
as int,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
