// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'judgement.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Judgement {

 String get id; String get status; String? get comment;@JsonKey(name: 'is_confirmed') bool get isConfirmed;@JsonKey(name: 'reopen_count') int get reopenCount;@JsonKey(name: 'created_at') String get createdAt;@JsonKey(name: 'updated_at') String get updatedAt;
/// Create a copy of Judgement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JudgementCopyWith<Judgement> get copyWith => _$JudgementCopyWithImpl<Judgement>(this as Judgement, _$identity);

  /// Serializes this Judgement to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Judgement&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.comment, comment) || other.comment == comment)&&(identical(other.isConfirmed, isConfirmed) || other.isConfirmed == isConfirmed)&&(identical(other.reopenCount, reopenCount) || other.reopenCount == reopenCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,status,comment,isConfirmed,reopenCount,createdAt,updatedAt);

@override
String toString() {
  return 'Judgement(id: $id, status: $status, comment: $comment, isConfirmed: $isConfirmed, reopenCount: $reopenCount, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $JudgementCopyWith<$Res>  {
  factory $JudgementCopyWith(Judgement value, $Res Function(Judgement) _then) = _$JudgementCopyWithImpl;
@useResult
$Res call({
 String id, String status, String? comment,@JsonKey(name: 'is_confirmed') bool isConfirmed,@JsonKey(name: 'reopen_count') int reopenCount,@JsonKey(name: 'created_at') String createdAt,@JsonKey(name: 'updated_at') String updatedAt
});




}
/// @nodoc
class _$JudgementCopyWithImpl<$Res>
    implements $JudgementCopyWith<$Res> {
  _$JudgementCopyWithImpl(this._self, this._then);

  final Judgement _self;
  final $Res Function(Judgement) _then;

/// Create a copy of Judgement
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? status = null,Object? comment = freezed,Object? isConfirmed = null,Object? reopenCount = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,isConfirmed: null == isConfirmed ? _self.isConfirmed : isConfirmed // ignore: cast_nullable_to_non_nullable
as bool,reopenCount: null == reopenCount ? _self.reopenCount : reopenCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Judgement].
extension JudgementPatterns on Judgement {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Judgement value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Judgement() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Judgement value)  $default,){
final _that = this;
switch (_that) {
case _Judgement():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Judgement value)?  $default,){
final _that = this;
switch (_that) {
case _Judgement() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String status,  String? comment, @JsonKey(name: 'is_confirmed')  bool isConfirmed, @JsonKey(name: 'reopen_count')  int reopenCount, @JsonKey(name: 'created_at')  String createdAt, @JsonKey(name: 'updated_at')  String updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Judgement() when $default != null:
return $default(_that.id,_that.status,_that.comment,_that.isConfirmed,_that.reopenCount,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String status,  String? comment, @JsonKey(name: 'is_confirmed')  bool isConfirmed, @JsonKey(name: 'reopen_count')  int reopenCount, @JsonKey(name: 'created_at')  String createdAt, @JsonKey(name: 'updated_at')  String updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Judgement():
return $default(_that.id,_that.status,_that.comment,_that.isConfirmed,_that.reopenCount,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String status,  String? comment, @JsonKey(name: 'is_confirmed')  bool isConfirmed, @JsonKey(name: 'reopen_count')  int reopenCount, @JsonKey(name: 'created_at')  String createdAt, @JsonKey(name: 'updated_at')  String updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Judgement() when $default != null:
return $default(_that.id,_that.status,_that.comment,_that.isConfirmed,_that.reopenCount,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Judgement implements Judgement {
  const _Judgement({required this.id, required this.status, this.comment, @JsonKey(name: 'is_confirmed') this.isConfirmed = false, @JsonKey(name: 'reopen_count') this.reopenCount = 0, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'updated_at') required this.updatedAt});
  factory _Judgement.fromJson(Map<String, dynamic> json) => _$JudgementFromJson(json);

@override final  String id;
@override final  String status;
@override final  String? comment;
@override@JsonKey(name: 'is_confirmed') final  bool isConfirmed;
@override@JsonKey(name: 'reopen_count') final  int reopenCount;
@override@JsonKey(name: 'created_at') final  String createdAt;
@override@JsonKey(name: 'updated_at') final  String updatedAt;

/// Create a copy of Judgement
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JudgementCopyWith<_Judgement> get copyWith => __$JudgementCopyWithImpl<_Judgement>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$JudgementToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Judgement&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.comment, comment) || other.comment == comment)&&(identical(other.isConfirmed, isConfirmed) || other.isConfirmed == isConfirmed)&&(identical(other.reopenCount, reopenCount) || other.reopenCount == reopenCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,status,comment,isConfirmed,reopenCount,createdAt,updatedAt);

@override
String toString() {
  return 'Judgement(id: $id, status: $status, comment: $comment, isConfirmed: $isConfirmed, reopenCount: $reopenCount, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$JudgementCopyWith<$Res> implements $JudgementCopyWith<$Res> {
  factory _$JudgementCopyWith(_Judgement value, $Res Function(_Judgement) _then) = __$JudgementCopyWithImpl;
@override @useResult
$Res call({
 String id, String status, String? comment,@JsonKey(name: 'is_confirmed') bool isConfirmed,@JsonKey(name: 'reopen_count') int reopenCount,@JsonKey(name: 'created_at') String createdAt,@JsonKey(name: 'updated_at') String updatedAt
});




}
/// @nodoc
class __$JudgementCopyWithImpl<$Res>
    implements _$JudgementCopyWith<$Res> {
  __$JudgementCopyWithImpl(this._self, this._then);

  final _Judgement _self;
  final $Res Function(_Judgement) _then;

/// Create a copy of Judgement
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? status = null,Object? comment = freezed,Object? isConfirmed = null,Object? reopenCount = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Judgement(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,isConfirmed: null == isConfirmed ? _self.isConfirmed : isConfirmed // ignore: cast_nullable_to_non_nullable
as bool,reopenCount: null == reopenCount ? _self.reopenCount : reopenCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
