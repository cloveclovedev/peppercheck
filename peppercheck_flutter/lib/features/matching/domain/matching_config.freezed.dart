// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'matching_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MatchingConfig {

 int get openDeadlineHours; int get cancelDeadlineHours; int get rematchCutoffHours; int get maxRefereesPerTask; int get matchingPointCost;
/// Create a copy of MatchingConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MatchingConfigCopyWith<MatchingConfig> get copyWith => _$MatchingConfigCopyWithImpl<MatchingConfig>(this as MatchingConfig, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MatchingConfig&&(identical(other.openDeadlineHours, openDeadlineHours) || other.openDeadlineHours == openDeadlineHours)&&(identical(other.cancelDeadlineHours, cancelDeadlineHours) || other.cancelDeadlineHours == cancelDeadlineHours)&&(identical(other.rematchCutoffHours, rematchCutoffHours) || other.rematchCutoffHours == rematchCutoffHours)&&(identical(other.maxRefereesPerTask, maxRefereesPerTask) || other.maxRefereesPerTask == maxRefereesPerTask)&&(identical(other.matchingPointCost, matchingPointCost) || other.matchingPointCost == matchingPointCost));
}


@override
int get hashCode => Object.hash(runtimeType,openDeadlineHours,cancelDeadlineHours,rematchCutoffHours,maxRefereesPerTask,matchingPointCost);

@override
String toString() {
  return 'MatchingConfig(openDeadlineHours: $openDeadlineHours, cancelDeadlineHours: $cancelDeadlineHours, rematchCutoffHours: $rematchCutoffHours, maxRefereesPerTask: $maxRefereesPerTask, matchingPointCost: $matchingPointCost)';
}


}

/// @nodoc
abstract mixin class $MatchingConfigCopyWith<$Res>  {
  factory $MatchingConfigCopyWith(MatchingConfig value, $Res Function(MatchingConfig) _then) = _$MatchingConfigCopyWithImpl;
@useResult
$Res call({
 int openDeadlineHours, int cancelDeadlineHours, int rematchCutoffHours, int maxRefereesPerTask, int matchingPointCost
});




}
/// @nodoc
class _$MatchingConfigCopyWithImpl<$Res>
    implements $MatchingConfigCopyWith<$Res> {
  _$MatchingConfigCopyWithImpl(this._self, this._then);

  final MatchingConfig _self;
  final $Res Function(MatchingConfig) _then;

/// Create a copy of MatchingConfig
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


/// Adds pattern-matching-related methods to [MatchingConfig].
extension MatchingConfigPatterns on MatchingConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MatchingConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MatchingConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MatchingConfig value)  $default,){
final _that = this;
switch (_that) {
case _MatchingConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MatchingConfig value)?  $default,){
final _that = this;
switch (_that) {
case _MatchingConfig() when $default != null:
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
case _MatchingConfig() when $default != null:
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
case _MatchingConfig():
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
case _MatchingConfig() when $default != null:
return $default(_that.openDeadlineHours,_that.cancelDeadlineHours,_that.rematchCutoffHours,_that.maxRefereesPerTask,_that.matchingPointCost);case _:
  return null;

}
}

}

/// @nodoc


class _MatchingConfig implements MatchingConfig {
  const _MatchingConfig({required this.openDeadlineHours, required this.cancelDeadlineHours, required this.rematchCutoffHours, required this.maxRefereesPerTask, required this.matchingPointCost});
  

@override final  int openDeadlineHours;
@override final  int cancelDeadlineHours;
@override final  int rematchCutoffHours;
@override final  int maxRefereesPerTask;
@override final  int matchingPointCost;

/// Create a copy of MatchingConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MatchingConfigCopyWith<_MatchingConfig> get copyWith => __$MatchingConfigCopyWithImpl<_MatchingConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MatchingConfig&&(identical(other.openDeadlineHours, openDeadlineHours) || other.openDeadlineHours == openDeadlineHours)&&(identical(other.cancelDeadlineHours, cancelDeadlineHours) || other.cancelDeadlineHours == cancelDeadlineHours)&&(identical(other.rematchCutoffHours, rematchCutoffHours) || other.rematchCutoffHours == rematchCutoffHours)&&(identical(other.maxRefereesPerTask, maxRefereesPerTask) || other.maxRefereesPerTask == maxRefereesPerTask)&&(identical(other.matchingPointCost, matchingPointCost) || other.matchingPointCost == matchingPointCost));
}


@override
int get hashCode => Object.hash(runtimeType,openDeadlineHours,cancelDeadlineHours,rematchCutoffHours,maxRefereesPerTask,matchingPointCost);

@override
String toString() {
  return 'MatchingConfig(openDeadlineHours: $openDeadlineHours, cancelDeadlineHours: $cancelDeadlineHours, rematchCutoffHours: $rematchCutoffHours, maxRefereesPerTask: $maxRefereesPerTask, matchingPointCost: $matchingPointCost)';
}


}

/// @nodoc
abstract mixin class _$MatchingConfigCopyWith<$Res> implements $MatchingConfigCopyWith<$Res> {
  factory _$MatchingConfigCopyWith(_MatchingConfig value, $Res Function(_MatchingConfig) _then) = __$MatchingConfigCopyWithImpl;
@override @useResult
$Res call({
 int openDeadlineHours, int cancelDeadlineHours, int rematchCutoffHours, int maxRefereesPerTask, int matchingPointCost
});




}
/// @nodoc
class __$MatchingConfigCopyWithImpl<$Res>
    implements _$MatchingConfigCopyWith<$Res> {
  __$MatchingConfigCopyWithImpl(this._self, this._then);

  final _MatchingConfig _self;
  final $Res Function(_MatchingConfig) _then;

/// Create a copy of MatchingConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? openDeadlineHours = null,Object? cancelDeadlineHours = null,Object? rematchCutoffHours = null,Object? maxRefereesPerTask = null,Object? matchingPointCost = null,}) {
  return _then(_MatchingConfig(
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
