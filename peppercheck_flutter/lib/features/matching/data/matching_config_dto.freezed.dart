// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'matching_config_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MatchingConfigDto {

 int get openDeadlineHours; int get cancelDeadlineHours; int get rematchCutoffHours; int get maxRefereesPerTask; int get matchingPointCost;
/// Create a copy of MatchingConfigDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MatchingConfigDtoCopyWith<MatchingConfigDto> get copyWith => _$MatchingConfigDtoCopyWithImpl<MatchingConfigDto>(this as MatchingConfigDto, _$identity);

  /// Serializes this MatchingConfigDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MatchingConfigDto&&(identical(other.openDeadlineHours, openDeadlineHours) || other.openDeadlineHours == openDeadlineHours)&&(identical(other.cancelDeadlineHours, cancelDeadlineHours) || other.cancelDeadlineHours == cancelDeadlineHours)&&(identical(other.rematchCutoffHours, rematchCutoffHours) || other.rematchCutoffHours == rematchCutoffHours)&&(identical(other.maxRefereesPerTask, maxRefereesPerTask) || other.maxRefereesPerTask == maxRefereesPerTask)&&(identical(other.matchingPointCost, matchingPointCost) || other.matchingPointCost == matchingPointCost));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,openDeadlineHours,cancelDeadlineHours,rematchCutoffHours,maxRefereesPerTask,matchingPointCost);

@override
String toString() {
  return 'MatchingConfigDto(openDeadlineHours: $openDeadlineHours, cancelDeadlineHours: $cancelDeadlineHours, rematchCutoffHours: $rematchCutoffHours, maxRefereesPerTask: $maxRefereesPerTask, matchingPointCost: $matchingPointCost)';
}


}

/// @nodoc
abstract mixin class $MatchingConfigDtoCopyWith<$Res>  {
  factory $MatchingConfigDtoCopyWith(MatchingConfigDto value, $Res Function(MatchingConfigDto) _then) = _$MatchingConfigDtoCopyWithImpl;
@useResult
$Res call({
 int openDeadlineHours, int cancelDeadlineHours, int rematchCutoffHours, int maxRefereesPerTask, int matchingPointCost
});




}
/// @nodoc
class _$MatchingConfigDtoCopyWithImpl<$Res>
    implements $MatchingConfigDtoCopyWith<$Res> {
  _$MatchingConfigDtoCopyWithImpl(this._self, this._then);

  final MatchingConfigDto _self;
  final $Res Function(MatchingConfigDto) _then;

/// Create a copy of MatchingConfigDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? openDeadlineHours = null,Object? cancelDeadlineHours = null,Object? rematchCutoffHours = null,Object? maxRefereesPerTask = null,Object? matchingPointCost = null,}) {
  return _then(_self.copyWith(
openDeadlineHours: null == openDeadlineHours ? _self.openDeadlineHours : openDeadlineHours // ignore: cast_nullable_to_non_nullable
as int,cancelDeadlineHours: null == cancelDeadlineHours ? _self.cancelDeadlineHours : cancelDeadlineHours // ignore: cast_nullable_to_non_nullable
as int,rematchCutoffHours: null == rematchCutoffHours ? _self.rematchCutoffHours : rematchCutoffHours // ignore: cast_nullable_to_non_nullable
as int,maxRefereesPerTask: null == maxRefereesPerTask ? _self.maxRefereesPerTask : maxRefereesPerTask // ignore: cast_nullable_to_non_nullable
as int,matchingPointCost: null == matchingPointCost ? _self.matchingPointCost : matchingPointCost // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MatchingConfigDto].
extension MatchingConfigDtoPatterns on MatchingConfigDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MatchingConfigDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MatchingConfigDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MatchingConfigDto value)  $default,){
final _that = this;
switch (_that) {
case _MatchingConfigDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MatchingConfigDto value)?  $default,){
final _that = this;
switch (_that) {
case _MatchingConfigDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int openDeadlineHours,  int cancelDeadlineHours,  int rematchCutoffHours,  int maxRefereesPerTask,  int matchingPointCost)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MatchingConfigDto() when $default != null:
return $default(_that.openDeadlineHours,_that.cancelDeadlineHours,_that.rematchCutoffHours,_that.maxRefereesPerTask,_that.matchingPointCost);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int openDeadlineHours,  int cancelDeadlineHours,  int rematchCutoffHours,  int maxRefereesPerTask,  int matchingPointCost)  $default,) {final _that = this;
switch (_that) {
case _MatchingConfigDto():
return $default(_that.openDeadlineHours,_that.cancelDeadlineHours,_that.rematchCutoffHours,_that.maxRefereesPerTask,_that.matchingPointCost);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int openDeadlineHours,  int cancelDeadlineHours,  int rematchCutoffHours,  int maxRefereesPerTask,  int matchingPointCost)?  $default,) {final _that = this;
switch (_that) {
case _MatchingConfigDto() when $default != null:
return $default(_that.openDeadlineHours,_that.cancelDeadlineHours,_that.rematchCutoffHours,_that.maxRefereesPerTask,_that.matchingPointCost);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MatchingConfigDto extends MatchingConfigDto {
  const _MatchingConfigDto({required this.openDeadlineHours, required this.cancelDeadlineHours, required this.rematchCutoffHours, required this.maxRefereesPerTask, required this.matchingPointCost}): super._();
  factory _MatchingConfigDto.fromJson(Map<String, dynamic> json) => _$MatchingConfigDtoFromJson(json);

@override final  int openDeadlineHours;
@override final  int cancelDeadlineHours;
@override final  int rematchCutoffHours;
@override final  int maxRefereesPerTask;
@override final  int matchingPointCost;

/// Create a copy of MatchingConfigDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MatchingConfigDtoCopyWith<_MatchingConfigDto> get copyWith => __$MatchingConfigDtoCopyWithImpl<_MatchingConfigDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MatchingConfigDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MatchingConfigDto&&(identical(other.openDeadlineHours, openDeadlineHours) || other.openDeadlineHours == openDeadlineHours)&&(identical(other.cancelDeadlineHours, cancelDeadlineHours) || other.cancelDeadlineHours == cancelDeadlineHours)&&(identical(other.rematchCutoffHours, rematchCutoffHours) || other.rematchCutoffHours == rematchCutoffHours)&&(identical(other.maxRefereesPerTask, maxRefereesPerTask) || other.maxRefereesPerTask == maxRefereesPerTask)&&(identical(other.matchingPointCost, matchingPointCost) || other.matchingPointCost == matchingPointCost));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,openDeadlineHours,cancelDeadlineHours,rematchCutoffHours,maxRefereesPerTask,matchingPointCost);

@override
String toString() {
  return 'MatchingConfigDto(openDeadlineHours: $openDeadlineHours, cancelDeadlineHours: $cancelDeadlineHours, rematchCutoffHours: $rematchCutoffHours, maxRefereesPerTask: $maxRefereesPerTask, matchingPointCost: $matchingPointCost)';
}


}

/// @nodoc
abstract mixin class _$MatchingConfigDtoCopyWith<$Res> implements $MatchingConfigDtoCopyWith<$Res> {
  factory _$MatchingConfigDtoCopyWith(_MatchingConfigDto value, $Res Function(_MatchingConfigDto) _then) = __$MatchingConfigDtoCopyWithImpl;
@override @useResult
$Res call({
 int openDeadlineHours, int cancelDeadlineHours, int rematchCutoffHours, int maxRefereesPerTask, int matchingPointCost
});




}
/// @nodoc
class __$MatchingConfigDtoCopyWithImpl<$Res>
    implements _$MatchingConfigDtoCopyWith<$Res> {
  __$MatchingConfigDtoCopyWithImpl(this._self, this._then);

  final _MatchingConfigDto _self;
  final $Res Function(_MatchingConfigDto) _then;

/// Create a copy of MatchingConfigDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? openDeadlineHours = null,Object? cancelDeadlineHours = null,Object? rematchCutoffHours = null,Object? maxRefereesPerTask = null,Object? matchingPointCost = null,}) {
  return _then(_MatchingConfigDto(
openDeadlineHours: null == openDeadlineHours ? _self.openDeadlineHours : openDeadlineHours // ignore: cast_nullable_to_non_nullable
as int,cancelDeadlineHours: null == cancelDeadlineHours ? _self.cancelDeadlineHours : cancelDeadlineHours // ignore: cast_nullable_to_non_nullable
as int,rematchCutoffHours: null == rematchCutoffHours ? _self.rematchCutoffHours : rematchCutoffHours // ignore: cast_nullable_to_non_nullable
as int,maxRefereesPerTask: null == maxRefereesPerTask ? _self.maxRefereesPerTask : maxRefereesPerTask // ignore: cast_nullable_to_non_nullable
as int,matchingPointCost: null == matchingPointCost ? _self.matchingPointCost : matchingPointCost // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
