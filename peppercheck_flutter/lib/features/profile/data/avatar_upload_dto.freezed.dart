// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'avatar_upload_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AvatarUploadDto {

 String get uploadUrl; String get publicUrl; String get expiresAt;
/// Create a copy of AvatarUploadDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AvatarUploadDtoCopyWith<AvatarUploadDto> get copyWith => _$AvatarUploadDtoCopyWithImpl<AvatarUploadDto>(this as AvatarUploadDto, _$identity);

  /// Serializes this AvatarUploadDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvatarUploadDto&&(identical(other.uploadUrl, uploadUrl) || other.uploadUrl == uploadUrl)&&(identical(other.publicUrl, publicUrl) || other.publicUrl == publicUrl)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uploadUrl,publicUrl,expiresAt);

@override
String toString() {
  return 'AvatarUploadDto(uploadUrl: $uploadUrl, publicUrl: $publicUrl, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class $AvatarUploadDtoCopyWith<$Res>  {
  factory $AvatarUploadDtoCopyWith(AvatarUploadDto value, $Res Function(AvatarUploadDto) _then) = _$AvatarUploadDtoCopyWithImpl;
@useResult
$Res call({
 String uploadUrl, String publicUrl, String expiresAt
});




}
/// @nodoc
class _$AvatarUploadDtoCopyWithImpl<$Res>
    implements $AvatarUploadDtoCopyWith<$Res> {
  _$AvatarUploadDtoCopyWithImpl(this._self, this._then);

  final AvatarUploadDto _self;
  final $Res Function(AvatarUploadDto) _then;

/// Create a copy of AvatarUploadDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uploadUrl = null,Object? publicUrl = null,Object? expiresAt = null,}) {
  return _then(_self.copyWith(
uploadUrl: null == uploadUrl ? _self.uploadUrl : uploadUrl // ignore: cast_nullable_to_non_nullable
as String,publicUrl: null == publicUrl ? _self.publicUrl : publicUrl // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AvatarUploadDto].
extension AvatarUploadDtoPatterns on AvatarUploadDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AvatarUploadDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AvatarUploadDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AvatarUploadDto value)  $default,){
final _that = this;
switch (_that) {
case _AvatarUploadDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AvatarUploadDto value)?  $default,){
final _that = this;
switch (_that) {
case _AvatarUploadDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uploadUrl,  String publicUrl,  String expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AvatarUploadDto() when $default != null:
return $default(_that.uploadUrl,_that.publicUrl,_that.expiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uploadUrl,  String publicUrl,  String expiresAt)  $default,) {final _that = this;
switch (_that) {
case _AvatarUploadDto():
return $default(_that.uploadUrl,_that.publicUrl,_that.expiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uploadUrl,  String publicUrl,  String expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _AvatarUploadDto() when $default != null:
return $default(_that.uploadUrl,_that.publicUrl,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AvatarUploadDto implements AvatarUploadDto {
  const _AvatarUploadDto({required this.uploadUrl, required this.publicUrl, required this.expiresAt});
  factory _AvatarUploadDto.fromJson(Map<String, dynamic> json) => _$AvatarUploadDtoFromJson(json);

@override final  String uploadUrl;
@override final  String publicUrl;
@override final  String expiresAt;

/// Create a copy of AvatarUploadDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AvatarUploadDtoCopyWith<_AvatarUploadDto> get copyWith => __$AvatarUploadDtoCopyWithImpl<_AvatarUploadDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AvatarUploadDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AvatarUploadDto&&(identical(other.uploadUrl, uploadUrl) || other.uploadUrl == uploadUrl)&&(identical(other.publicUrl, publicUrl) || other.publicUrl == publicUrl)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uploadUrl,publicUrl,expiresAt);

@override
String toString() {
  return 'AvatarUploadDto(uploadUrl: $uploadUrl, publicUrl: $publicUrl, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$AvatarUploadDtoCopyWith<$Res> implements $AvatarUploadDtoCopyWith<$Res> {
  factory _$AvatarUploadDtoCopyWith(_AvatarUploadDto value, $Res Function(_AvatarUploadDto) _then) = __$AvatarUploadDtoCopyWithImpl;
@override @useResult
$Res call({
 String uploadUrl, String publicUrl, String expiresAt
});




}
/// @nodoc
class __$AvatarUploadDtoCopyWithImpl<$Res>
    implements _$AvatarUploadDtoCopyWith<$Res> {
  __$AvatarUploadDtoCopyWithImpl(this._self, this._then);

  final _AvatarUploadDto _self;
  final $Res Function(_AvatarUploadDto) _then;

/// Create a copy of AvatarUploadDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uploadUrl = null,Object? publicUrl = null,Object? expiresAt = null,}) {
  return _then(_AvatarUploadDto(
uploadUrl: null == uploadUrl ? _self.uploadUrl : uploadUrl // ignore: cast_nullable_to_non_nullable
as String,publicUrl: null == publicUrl ? _self.publicUrl : publicUrl // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
