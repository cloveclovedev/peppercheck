// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'referee_request_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RefereeRequestDto {

 String get id; String get taskId; String get status; String? get matchedRefereeId; String? get respondedAt; String? get pointSource; bool get isObligation; String get createdAt; String get updatedAt; PublicProfileDto? get referee;
/// Create a copy of RefereeRequestDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RefereeRequestDtoCopyWith<RefereeRequestDto> get copyWith => _$RefereeRequestDtoCopyWithImpl<RefereeRequestDto>(this as RefereeRequestDto, _$identity);

  /// Serializes this RefereeRequestDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RefereeRequestDto&&(identical(other.id, id) || other.id == id)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.status, status) || other.status == status)&&(identical(other.matchedRefereeId, matchedRefereeId) || other.matchedRefereeId == matchedRefereeId)&&(identical(other.respondedAt, respondedAt) || other.respondedAt == respondedAt)&&(identical(other.pointSource, pointSource) || other.pointSource == pointSource)&&(identical(other.isObligation, isObligation) || other.isObligation == isObligation)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.referee, referee) || other.referee == referee));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,taskId,status,matchedRefereeId,respondedAt,pointSource,isObligation,createdAt,updatedAt,referee);

@override
String toString() {
  return 'RefereeRequestDto(id: $id, taskId: $taskId, status: $status, matchedRefereeId: $matchedRefereeId, respondedAt: $respondedAt, pointSource: $pointSource, isObligation: $isObligation, createdAt: $createdAt, updatedAt: $updatedAt, referee: $referee)';
}


}

/// @nodoc
abstract mixin class $RefereeRequestDtoCopyWith<$Res>  {
  factory $RefereeRequestDtoCopyWith(RefereeRequestDto value, $Res Function(RefereeRequestDto) _then) = _$RefereeRequestDtoCopyWithImpl;
@useResult
$Res call({
 String id, String taskId, String status, String? matchedRefereeId, String? respondedAt, String? pointSource, bool isObligation, String createdAt, String updatedAt, PublicProfileDto? referee
});


$PublicProfileDtoCopyWith<$Res>? get referee;

}
/// @nodoc
class _$RefereeRequestDtoCopyWithImpl<$Res>
    implements $RefereeRequestDtoCopyWith<$Res> {
  _$RefereeRequestDtoCopyWithImpl(this._self, this._then);

  final RefereeRequestDto _self;
  final $Res Function(RefereeRequestDto) _then;

/// Create a copy of RefereeRequestDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? taskId = null,Object? status = null,Object? matchedRefereeId = freezed,Object? respondedAt = freezed,Object? pointSource = freezed,Object? isObligation = null,Object? createdAt = null,Object? updatedAt = null,Object? referee = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,matchedRefereeId: freezed == matchedRefereeId ? _self.matchedRefereeId : matchedRefereeId // ignore: cast_nullable_to_non_nullable
as String?,respondedAt: freezed == respondedAt ? _self.respondedAt : respondedAt // ignore: cast_nullable_to_non_nullable
as String?,pointSource: freezed == pointSource ? _self.pointSource : pointSource // ignore: cast_nullable_to_non_nullable
as String?,isObligation: null == isObligation ? _self.isObligation : isObligation // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,referee: freezed == referee ? _self.referee : referee // ignore: cast_nullable_to_non_nullable
as PublicProfileDto?,
  ));
}
/// Create a copy of RefereeRequestDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicProfileDtoCopyWith<$Res>? get referee {
    if (_self.referee == null) {
    return null;
  }

  return $PublicProfileDtoCopyWith<$Res>(_self.referee!, (value) {
    return _then(_self.copyWith(referee: value));
  });
}
}


/// Adds pattern-matching-related methods to [RefereeRequestDto].
extension RefereeRequestDtoPatterns on RefereeRequestDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RefereeRequestDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RefereeRequestDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RefereeRequestDto value)  $default,){
final _that = this;
switch (_that) {
case _RefereeRequestDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RefereeRequestDto value)?  $default,){
final _that = this;
switch (_that) {
case _RefereeRequestDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String taskId,  String status,  String? matchedRefereeId,  String? respondedAt,  String? pointSource,  bool isObligation,  String createdAt,  String updatedAt,  PublicProfileDto? referee)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RefereeRequestDto() when $default != null:
return $default(_that.id,_that.taskId,_that.status,_that.matchedRefereeId,_that.respondedAt,_that.pointSource,_that.isObligation,_that.createdAt,_that.updatedAt,_that.referee);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String taskId,  String status,  String? matchedRefereeId,  String? respondedAt,  String? pointSource,  bool isObligation,  String createdAt,  String updatedAt,  PublicProfileDto? referee)  $default,) {final _that = this;
switch (_that) {
case _RefereeRequestDto():
return $default(_that.id,_that.taskId,_that.status,_that.matchedRefereeId,_that.respondedAt,_that.pointSource,_that.isObligation,_that.createdAt,_that.updatedAt,_that.referee);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String taskId,  String status,  String? matchedRefereeId,  String? respondedAt,  String? pointSource,  bool isObligation,  String createdAt,  String updatedAt,  PublicProfileDto? referee)?  $default,) {final _that = this;
switch (_that) {
case _RefereeRequestDto() when $default != null:
return $default(_that.id,_that.taskId,_that.status,_that.matchedRefereeId,_that.respondedAt,_that.pointSource,_that.isObligation,_that.createdAt,_that.updatedAt,_that.referee);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RefereeRequestDto extends RefereeRequestDto {
  const _RefereeRequestDto({required this.id, required this.taskId, required this.status, this.matchedRefereeId, this.respondedAt, this.pointSource, this.isObligation = false, required this.createdAt, required this.updatedAt, this.referee}): super._();
  factory _RefereeRequestDto.fromJson(Map<String, dynamic> json) => _$RefereeRequestDtoFromJson(json);

@override final  String id;
@override final  String taskId;
@override final  String status;
@override final  String? matchedRefereeId;
@override final  String? respondedAt;
@override final  String? pointSource;
@override@JsonKey() final  bool isObligation;
@override final  String createdAt;
@override final  String updatedAt;
@override final  PublicProfileDto? referee;

/// Create a copy of RefereeRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RefereeRequestDtoCopyWith<_RefereeRequestDto> get copyWith => __$RefereeRequestDtoCopyWithImpl<_RefereeRequestDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RefereeRequestDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefereeRequestDto&&(identical(other.id, id) || other.id == id)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.status, status) || other.status == status)&&(identical(other.matchedRefereeId, matchedRefereeId) || other.matchedRefereeId == matchedRefereeId)&&(identical(other.respondedAt, respondedAt) || other.respondedAt == respondedAt)&&(identical(other.pointSource, pointSource) || other.pointSource == pointSource)&&(identical(other.isObligation, isObligation) || other.isObligation == isObligation)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.referee, referee) || other.referee == referee));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,taskId,status,matchedRefereeId,respondedAt,pointSource,isObligation,createdAt,updatedAt,referee);

@override
String toString() {
  return 'RefereeRequestDto(id: $id, taskId: $taskId, status: $status, matchedRefereeId: $matchedRefereeId, respondedAt: $respondedAt, pointSource: $pointSource, isObligation: $isObligation, createdAt: $createdAt, updatedAt: $updatedAt, referee: $referee)';
}


}

/// @nodoc
abstract mixin class _$RefereeRequestDtoCopyWith<$Res> implements $RefereeRequestDtoCopyWith<$Res> {
  factory _$RefereeRequestDtoCopyWith(_RefereeRequestDto value, $Res Function(_RefereeRequestDto) _then) = __$RefereeRequestDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String taskId, String status, String? matchedRefereeId, String? respondedAt, String? pointSource, bool isObligation, String createdAt, String updatedAt, PublicProfileDto? referee
});


@override $PublicProfileDtoCopyWith<$Res>? get referee;

}
/// @nodoc
class __$RefereeRequestDtoCopyWithImpl<$Res>
    implements _$RefereeRequestDtoCopyWith<$Res> {
  __$RefereeRequestDtoCopyWithImpl(this._self, this._then);

  final _RefereeRequestDto _self;
  final $Res Function(_RefereeRequestDto) _then;

/// Create a copy of RefereeRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? taskId = null,Object? status = null,Object? matchedRefereeId = freezed,Object? respondedAt = freezed,Object? pointSource = freezed,Object? isObligation = null,Object? createdAt = null,Object? updatedAt = null,Object? referee = freezed,}) {
  return _then(_RefereeRequestDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,matchedRefereeId: freezed == matchedRefereeId ? _self.matchedRefereeId : matchedRefereeId // ignore: cast_nullable_to_non_nullable
as String?,respondedAt: freezed == respondedAt ? _self.respondedAt : respondedAt // ignore: cast_nullable_to_non_nullable
as String?,pointSource: freezed == pointSource ? _self.pointSource : pointSource // ignore: cast_nullable_to_non_nullable
as String?,isObligation: null == isObligation ? _self.isObligation : isObligation // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,referee: freezed == referee ? _self.referee : referee // ignore: cast_nullable_to_non_nullable
as PublicProfileDto?,
  ));
}

/// Create a copy of RefereeRequestDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicProfileDtoCopyWith<$Res>? get referee {
    if (_self.referee == null) {
    return null;
  }

  return $PublicProfileDtoCopyWith<$Res>(_self.referee!, (value) {
    return _then(_self.copyWith(referee: value));
  });
}
}

// dart format on
