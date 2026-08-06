// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'referee_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RefereeRequest {

 String get id; String get taskId; String get status; String? get matchedRefereeId; String? get respondedAt; String get createdAt; String? get updatedAt; String? get pointSource; bool get isObligation;// Aggregated fields
 Judgement? get judgement; PublicProfile? get referee;
/// Create a copy of RefereeRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RefereeRequestCopyWith<RefereeRequest> get copyWith => _$RefereeRequestCopyWithImpl<RefereeRequest>(this as RefereeRequest, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RefereeRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.status, status) || other.status == status)&&(identical(other.matchedRefereeId, matchedRefereeId) || other.matchedRefereeId == matchedRefereeId)&&(identical(other.respondedAt, respondedAt) || other.respondedAt == respondedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.pointSource, pointSource) || other.pointSource == pointSource)&&(identical(other.isObligation, isObligation) || other.isObligation == isObligation)&&(identical(other.judgement, judgement) || other.judgement == judgement)&&(identical(other.referee, referee) || other.referee == referee));
}


@override
int get hashCode => Object.hash(runtimeType,id,taskId,status,matchedRefereeId,respondedAt,createdAt,updatedAt,pointSource,isObligation,judgement,referee);

@override
String toString() {
  return 'RefereeRequest(id: $id, taskId: $taskId, status: $status, matchedRefereeId: $matchedRefereeId, respondedAt: $respondedAt, createdAt: $createdAt, updatedAt: $updatedAt, pointSource: $pointSource, isObligation: $isObligation, judgement: $judgement, referee: $referee)';
}


}

/// @nodoc
abstract mixin class $RefereeRequestCopyWith<$Res>  {
  factory $RefereeRequestCopyWith(RefereeRequest value, $Res Function(RefereeRequest) _then) = _$RefereeRequestCopyWithImpl;
@useResult
$Res call({
 String id, String taskId, String status, String? matchedRefereeId, String? respondedAt, String createdAt, String? updatedAt, String? pointSource, bool isObligation, Judgement? judgement, PublicProfile? referee
});


$JudgementCopyWith<$Res>? get judgement;$PublicProfileCopyWith<$Res>? get referee;

}
/// @nodoc
class _$RefereeRequestCopyWithImpl<$Res>
    implements $RefereeRequestCopyWith<$Res> {
  _$RefereeRequestCopyWithImpl(this._self, this._then);

  final RefereeRequest _self;
  final $Res Function(RefereeRequest) _then;

/// Create a copy of RefereeRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? taskId = null,Object? status = null,Object? matchedRefereeId = freezed,Object? respondedAt = freezed,Object? createdAt = null,Object? updatedAt = freezed,Object? pointSource = freezed,Object? isObligation = null,Object? judgement = freezed,Object? referee = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,matchedRefereeId: freezed == matchedRefereeId ? _self.matchedRefereeId : matchedRefereeId // ignore: cast_nullable_to_non_nullable
as String?,respondedAt: freezed == respondedAt ? _self.respondedAt : respondedAt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,pointSource: freezed == pointSource ? _self.pointSource : pointSource // ignore: cast_nullable_to_non_nullable
as String?,isObligation: null == isObligation ? _self.isObligation : isObligation // ignore: cast_nullable_to_non_nullable
as bool,judgement: freezed == judgement ? _self.judgement : judgement // ignore: cast_nullable_to_non_nullable
as Judgement?,referee: freezed == referee ? _self.referee : referee // ignore: cast_nullable_to_non_nullable
as PublicProfile?,
  ));
}
/// Create a copy of RefereeRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$JudgementCopyWith<$Res>? get judgement {
    if (_self.judgement == null) {
    return null;
  }

  return $JudgementCopyWith<$Res>(_self.judgement!, (value) {
    return _then(_self.copyWith(judgement: value));
  });
}/// Create a copy of RefereeRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicProfileCopyWith<$Res>? get referee {
    if (_self.referee == null) {
    return null;
  }

  return $PublicProfileCopyWith<$Res>(_self.referee!, (value) {
    return _then(_self.copyWith(referee: value));
  });
}
}


/// Adds pattern-matching-related methods to [RefereeRequest].
extension RefereeRequestPatterns on RefereeRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RefereeRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RefereeRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RefereeRequest value)  $default,){
final _that = this;
switch (_that) {
case _RefereeRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RefereeRequest value)?  $default,){
final _that = this;
switch (_that) {
case _RefereeRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String taskId,  String status,  String? matchedRefereeId,  String? respondedAt,  String createdAt,  String? updatedAt,  String? pointSource,  bool isObligation,  Judgement? judgement,  PublicProfile? referee)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RefereeRequest() when $default != null:
return $default(_that.id,_that.taskId,_that.status,_that.matchedRefereeId,_that.respondedAt,_that.createdAt,_that.updatedAt,_that.pointSource,_that.isObligation,_that.judgement,_that.referee);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String taskId,  String status,  String? matchedRefereeId,  String? respondedAt,  String createdAt,  String? updatedAt,  String? pointSource,  bool isObligation,  Judgement? judgement,  PublicProfile? referee)  $default,) {final _that = this;
switch (_that) {
case _RefereeRequest():
return $default(_that.id,_that.taskId,_that.status,_that.matchedRefereeId,_that.respondedAt,_that.createdAt,_that.updatedAt,_that.pointSource,_that.isObligation,_that.judgement,_that.referee);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String taskId,  String status,  String? matchedRefereeId,  String? respondedAt,  String createdAt,  String? updatedAt,  String? pointSource,  bool isObligation,  Judgement? judgement,  PublicProfile? referee)?  $default,) {final _that = this;
switch (_that) {
case _RefereeRequest() when $default != null:
return $default(_that.id,_that.taskId,_that.status,_that.matchedRefereeId,_that.respondedAt,_that.createdAt,_that.updatedAt,_that.pointSource,_that.isObligation,_that.judgement,_that.referee);case _:
  return null;

}
}

}

/// @nodoc


class _RefereeRequest implements RefereeRequest {
  const _RefereeRequest({required this.id, required this.taskId, required this.status, this.matchedRefereeId, this.respondedAt, required this.createdAt, this.updatedAt, this.pointSource, this.isObligation = false, this.judgement, this.referee});
  

@override final  String id;
@override final  String taskId;
@override final  String status;
@override final  String? matchedRefereeId;
@override final  String? respondedAt;
@override final  String createdAt;
@override final  String? updatedAt;
@override final  String? pointSource;
@override@JsonKey() final  bool isObligation;
// Aggregated fields
@override final  Judgement? judgement;
@override final  PublicProfile? referee;

/// Create a copy of RefereeRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RefereeRequestCopyWith<_RefereeRequest> get copyWith => __$RefereeRequestCopyWithImpl<_RefereeRequest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefereeRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.status, status) || other.status == status)&&(identical(other.matchedRefereeId, matchedRefereeId) || other.matchedRefereeId == matchedRefereeId)&&(identical(other.respondedAt, respondedAt) || other.respondedAt == respondedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.pointSource, pointSource) || other.pointSource == pointSource)&&(identical(other.isObligation, isObligation) || other.isObligation == isObligation)&&(identical(other.judgement, judgement) || other.judgement == judgement)&&(identical(other.referee, referee) || other.referee == referee));
}


@override
int get hashCode => Object.hash(runtimeType,id,taskId,status,matchedRefereeId,respondedAt,createdAt,updatedAt,pointSource,isObligation,judgement,referee);

@override
String toString() {
  return 'RefereeRequest(id: $id, taskId: $taskId, status: $status, matchedRefereeId: $matchedRefereeId, respondedAt: $respondedAt, createdAt: $createdAt, updatedAt: $updatedAt, pointSource: $pointSource, isObligation: $isObligation, judgement: $judgement, referee: $referee)';
}


}

/// @nodoc
abstract mixin class _$RefereeRequestCopyWith<$Res> implements $RefereeRequestCopyWith<$Res> {
  factory _$RefereeRequestCopyWith(_RefereeRequest value, $Res Function(_RefereeRequest) _then) = __$RefereeRequestCopyWithImpl;
@override @useResult
$Res call({
 String id, String taskId, String status, String? matchedRefereeId, String? respondedAt, String createdAt, String? updatedAt, String? pointSource, bool isObligation, Judgement? judgement, PublicProfile? referee
});


@override $JudgementCopyWith<$Res>? get judgement;@override $PublicProfileCopyWith<$Res>? get referee;

}
/// @nodoc
class __$RefereeRequestCopyWithImpl<$Res>
    implements _$RefereeRequestCopyWith<$Res> {
  __$RefereeRequestCopyWithImpl(this._self, this._then);

  final _RefereeRequest _self;
  final $Res Function(_RefereeRequest) _then;

/// Create a copy of RefereeRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? taskId = null,Object? status = null,Object? matchedRefereeId = freezed,Object? respondedAt = freezed,Object? createdAt = null,Object? updatedAt = freezed,Object? pointSource = freezed,Object? isObligation = null,Object? judgement = freezed,Object? referee = freezed,}) {
  return _then(_RefereeRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,matchedRefereeId: freezed == matchedRefereeId ? _self.matchedRefereeId : matchedRefereeId // ignore: cast_nullable_to_non_nullable
as String?,respondedAt: freezed == respondedAt ? _self.respondedAt : respondedAt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,pointSource: freezed == pointSource ? _self.pointSource : pointSource // ignore: cast_nullable_to_non_nullable
as String?,isObligation: null == isObligation ? _self.isObligation : isObligation // ignore: cast_nullable_to_non_nullable
as bool,judgement: freezed == judgement ? _self.judgement : judgement // ignore: cast_nullable_to_non_nullable
as Judgement?,referee: freezed == referee ? _self.referee : referee // ignore: cast_nullable_to_non_nullable
as PublicProfile?,
  ));
}

/// Create a copy of RefereeRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$JudgementCopyWith<$Res>? get judgement {
    if (_self.judgement == null) {
    return null;
  }

  return $JudgementCopyWith<$Res>(_self.judgement!, (value) {
    return _then(_self.copyWith(judgement: value));
  });
}/// Create a copy of RefereeRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicProfileCopyWith<$Res>? get referee {
    if (_self.referee == null) {
    return null;
  }

  return $PublicProfileCopyWith<$Res>(_self.referee!, (value) {
    return _then(_self.copyWith(referee: value));
  });
}
}

// dart format on
