// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'public_profile_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PublicProfileDto {

 String get userId; String get username; String? get avatarUrl;
/// Create a copy of PublicProfileDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicProfileDtoCopyWith<PublicProfileDto> get copyWith => _$PublicProfileDtoCopyWithImpl<PublicProfileDto>(this as PublicProfileDto, _$identity);

  /// Serializes this PublicProfileDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicProfileDto&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.username, username) || other.username == username)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,username,avatarUrl);

@override
String toString() {
  return 'PublicProfileDto(userId: $userId, username: $username, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class $PublicProfileDtoCopyWith<$Res>  {
  factory $PublicProfileDtoCopyWith(PublicProfileDto value, $Res Function(PublicProfileDto) _then) = _$PublicProfileDtoCopyWithImpl;
@useResult
$Res call({
 String userId, String username, String? avatarUrl
});




}
/// @nodoc
class _$PublicProfileDtoCopyWithImpl<$Res>
    implements $PublicProfileDtoCopyWith<$Res> {
  _$PublicProfileDtoCopyWithImpl(this._self, this._then);

  final PublicProfileDto _self;
  final $Res Function(PublicProfileDto) _then;

/// Create a copy of PublicProfileDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? username = null,Object? avatarUrl = freezed,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PublicProfileDto].
extension PublicProfileDtoPatterns on PublicProfileDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PublicProfileDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PublicProfileDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PublicProfileDto value)  $default,){
final _that = this;
switch (_that) {
case _PublicProfileDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PublicProfileDto value)?  $default,){
final _that = this;
switch (_that) {
case _PublicProfileDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userId,  String username,  String? avatarUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublicProfileDto() when $default != null:
return $default(_that.userId,_that.username,_that.avatarUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userId,  String username,  String? avatarUrl)  $default,) {final _that = this;
switch (_that) {
case _PublicProfileDto():
return $default(_that.userId,_that.username,_that.avatarUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userId,  String username,  String? avatarUrl)?  $default,) {final _that = this;
switch (_that) {
case _PublicProfileDto() when $default != null:
return $default(_that.userId,_that.username,_that.avatarUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PublicProfileDto extends PublicProfileDto {
  const _PublicProfileDto({required this.userId, required this.username, this.avatarUrl}): super._();
  factory _PublicProfileDto.fromJson(Map<String, dynamic> json) => _$PublicProfileDtoFromJson(json);

@override final  String userId;
@override final  String username;
@override final  String? avatarUrl;

/// Create a copy of PublicProfileDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PublicProfileDtoCopyWith<_PublicProfileDto> get copyWith => __$PublicProfileDtoCopyWithImpl<_PublicProfileDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PublicProfileDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublicProfileDto&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.username, username) || other.username == username)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,username,avatarUrl);

@override
String toString() {
  return 'PublicProfileDto(userId: $userId, username: $username, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class _$PublicProfileDtoCopyWith<$Res> implements $PublicProfileDtoCopyWith<$Res> {
  factory _$PublicProfileDtoCopyWith(_PublicProfileDto value, $Res Function(_PublicProfileDto) _then) = __$PublicProfileDtoCopyWithImpl;
@override @useResult
$Res call({
 String userId, String username, String? avatarUrl
});




}
/// @nodoc
class __$PublicProfileDtoCopyWithImpl<$Res>
    implements _$PublicProfileDtoCopyWith<$Res> {
  __$PublicProfileDtoCopyWithImpl(this._self, this._then);

  final _PublicProfileDto _self;
  final $Res Function(_PublicProfileDto) _then;

/// Create a copy of PublicProfileDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? username = null,Object? avatarUrl = freezed,}) {
  return _then(_PublicProfileDto(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
