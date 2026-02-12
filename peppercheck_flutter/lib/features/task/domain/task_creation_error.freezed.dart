// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_creation_error.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TaskCreationError {

 TaskCreationErrorType get type; String get message; int? get balance; int? get locked; int? get required; int? get minHours;
/// Create a copy of TaskCreationError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskCreationErrorCopyWith<TaskCreationError> get copyWith => _$TaskCreationErrorCopyWithImpl<TaskCreationError>(this as TaskCreationError, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskCreationError&&(identical(other.type, type) || other.type == type)&&(identical(other.message, message) || other.message == message)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.locked, locked) || other.locked == locked)&&(identical(other.required, required) || other.required == required)&&(identical(other.minHours, minHours) || other.minHours == minHours));
}


@override
int get hashCode => Object.hash(runtimeType,type,message,balance,locked,required,minHours);

@override
String toString() {
  return 'TaskCreationError(type: $type, message: $message, balance: $balance, locked: $locked, required: $required, minHours: $minHours)';
}


}

/// @nodoc
abstract mixin class $TaskCreationErrorCopyWith<$Res>  {
  factory $TaskCreationErrorCopyWith(TaskCreationError value, $Res Function(TaskCreationError) _then) = _$TaskCreationErrorCopyWithImpl;
@useResult
$Res call({
 TaskCreationErrorType type, String message, int? balance, int? locked, int? required, int? minHours
});




}
/// @nodoc
class _$TaskCreationErrorCopyWithImpl<$Res>
    implements $TaskCreationErrorCopyWith<$Res> {
  _$TaskCreationErrorCopyWithImpl(this._self, this._then);

  final TaskCreationError _self;
  final $Res Function(TaskCreationError) _then;

/// Create a copy of TaskCreationError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? message = null,Object? balance = freezed,Object? locked = freezed,Object? required = freezed,Object? minHours = freezed,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as TaskCreationErrorType,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,balance: freezed == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as int?,locked: freezed == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as int?,required: freezed == required ? _self.required : required // ignore: cast_nullable_to_non_nullable
as int?,minHours: freezed == minHours ? _self.minHours : minHours // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [TaskCreationError].
extension TaskCreationErrorPatterns on TaskCreationError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskCreationError value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskCreationError() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskCreationError value)  $default,){
final _that = this;
switch (_that) {
case _TaskCreationError():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskCreationError value)?  $default,){
final _that = this;
switch (_that) {
case _TaskCreationError() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TaskCreationErrorType type,  String message,  int? balance,  int? locked,  int? required,  int? minHours)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskCreationError() when $default != null:
return $default(_that.type,_that.message,_that.balance,_that.locked,_that.required,_that.minHours);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TaskCreationErrorType type,  String message,  int? balance,  int? locked,  int? required,  int? minHours)  $default,) {final _that = this;
switch (_that) {
case _TaskCreationError():
return $default(_that.type,_that.message,_that.balance,_that.locked,_that.required,_that.minHours);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TaskCreationErrorType type,  String message,  int? balance,  int? locked,  int? required,  int? minHours)?  $default,) {final _that = this;
switch (_that) {
case _TaskCreationError() when $default != null:
return $default(_that.type,_that.message,_that.balance,_that.locked,_that.required,_that.minHours);case _:
  return null;

}
}

}

/// @nodoc


class _TaskCreationError implements TaskCreationError {
  const _TaskCreationError({required this.type, required this.message, this.balance, this.locked, this.required, this.minHours});
  

@override final  TaskCreationErrorType type;
@override final  String message;
@override final  int? balance;
@override final  int? locked;
@override final  int? required;
@override final  int? minHours;

/// Create a copy of TaskCreationError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskCreationErrorCopyWith<_TaskCreationError> get copyWith => __$TaskCreationErrorCopyWithImpl<_TaskCreationError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskCreationError&&(identical(other.type, type) || other.type == type)&&(identical(other.message, message) || other.message == message)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.locked, locked) || other.locked == locked)&&(identical(other.required, required) || other.required == required)&&(identical(other.minHours, minHours) || other.minHours == minHours));
}


@override
int get hashCode => Object.hash(runtimeType,type,message,balance,locked,required,minHours);

@override
String toString() {
  return 'TaskCreationError(type: $type, message: $message, balance: $balance, locked: $locked, required: $required, minHours: $minHours)';
}


}

/// @nodoc
abstract mixin class _$TaskCreationErrorCopyWith<$Res> implements $TaskCreationErrorCopyWith<$Res> {
  factory _$TaskCreationErrorCopyWith(_TaskCreationError value, $Res Function(_TaskCreationError) _then) = __$TaskCreationErrorCopyWithImpl;
@override @useResult
$Res call({
 TaskCreationErrorType type, String message, int? balance, int? locked, int? required, int? minHours
});




}
/// @nodoc
class __$TaskCreationErrorCopyWithImpl<$Res>
    implements _$TaskCreationErrorCopyWith<$Res> {
  __$TaskCreationErrorCopyWithImpl(this._self, this._then);

  final _TaskCreationError _self;
  final $Res Function(_TaskCreationError) _then;

/// Create a copy of TaskCreationError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? message = null,Object? balance = freezed,Object? locked = freezed,Object? required = freezed,Object? minHours = freezed,}) {
  return _then(_TaskCreationError(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as TaskCreationErrorType,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,balance: freezed == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as int?,locked: freezed == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as int?,required: freezed == required ? _self.required : required // ignore: cast_nullable_to_non_nullable
as int?,minHours: freezed == minHours ? _self.minHours : minHours // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
