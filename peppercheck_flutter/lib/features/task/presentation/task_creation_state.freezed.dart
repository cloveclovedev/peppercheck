// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_creation_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TaskCreationState {

 TaskCreationRequest get request; bool get isSubmitting;
/// Create a copy of TaskCreationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskCreationStateCopyWith<TaskCreationState> get copyWith => _$TaskCreationStateCopyWithImpl<TaskCreationState>(this as TaskCreationState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskCreationState&&(identical(other.request, request) || other.request == request)&&(identical(other.isSubmitting, isSubmitting) || other.isSubmitting == isSubmitting));
}


@override
int get hashCode => Object.hash(runtimeType,request,isSubmitting);

@override
String toString() {
  return 'TaskCreationState(request: $request, isSubmitting: $isSubmitting)';
}


}

/// @nodoc
abstract mixin class $TaskCreationStateCopyWith<$Res>  {
  factory $TaskCreationStateCopyWith(TaskCreationState value, $Res Function(TaskCreationState) _then) = _$TaskCreationStateCopyWithImpl;
@useResult
$Res call({
 TaskCreationRequest request, bool isSubmitting
});


$TaskCreationRequestCopyWith<$Res> get request;

}
/// @nodoc
class _$TaskCreationStateCopyWithImpl<$Res>
    implements $TaskCreationStateCopyWith<$Res> {
  _$TaskCreationStateCopyWithImpl(this._self, this._then);

  final TaskCreationState _self;
  final $Res Function(TaskCreationState) _then;

/// Create a copy of TaskCreationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? request = null,Object? isSubmitting = null,}) {
  return _then(_self.copyWith(
request: null == request ? _self.request : request // ignore: cast_nullable_to_non_nullable
as TaskCreationRequest,isSubmitting: null == isSubmitting ? _self.isSubmitting : isSubmitting // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of TaskCreationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaskCreationRequestCopyWith<$Res> get request {
  
  return $TaskCreationRequestCopyWith<$Res>(_self.request, (value) {
    return _then(_self.copyWith(request: value));
  });
}
}


/// Adds pattern-matching-related methods to [TaskCreationState].
extension TaskCreationStatePatterns on TaskCreationState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskCreationState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskCreationState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskCreationState value)  $default,){
final _that = this;
switch (_that) {
case _TaskCreationState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskCreationState value)?  $default,){
final _that = this;
switch (_that) {
case _TaskCreationState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TaskCreationRequest request,  bool isSubmitting)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskCreationState() when $default != null:
return $default(_that.request,_that.isSubmitting);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TaskCreationRequest request,  bool isSubmitting)  $default,) {final _that = this;
switch (_that) {
case _TaskCreationState():
return $default(_that.request,_that.isSubmitting);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TaskCreationRequest request,  bool isSubmitting)?  $default,) {final _that = this;
switch (_that) {
case _TaskCreationState() when $default != null:
return $default(_that.request,_that.isSubmitting);case _:
  return null;

}
}

}

/// @nodoc


class _TaskCreationState implements TaskCreationState {
  const _TaskCreationState({required this.request, this.isSubmitting = false});
  

@override final  TaskCreationRequest request;
@override@JsonKey() final  bool isSubmitting;

/// Create a copy of TaskCreationState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskCreationStateCopyWith<_TaskCreationState> get copyWith => __$TaskCreationStateCopyWithImpl<_TaskCreationState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskCreationState&&(identical(other.request, request) || other.request == request)&&(identical(other.isSubmitting, isSubmitting) || other.isSubmitting == isSubmitting));
}


@override
int get hashCode => Object.hash(runtimeType,request,isSubmitting);

@override
String toString() {
  return 'TaskCreationState(request: $request, isSubmitting: $isSubmitting)';
}


}

/// @nodoc
abstract mixin class _$TaskCreationStateCopyWith<$Res> implements $TaskCreationStateCopyWith<$Res> {
  factory _$TaskCreationStateCopyWith(_TaskCreationState value, $Res Function(_TaskCreationState) _then) = __$TaskCreationStateCopyWithImpl;
@override @useResult
$Res call({
 TaskCreationRequest request, bool isSubmitting
});


@override $TaskCreationRequestCopyWith<$Res> get request;

}
/// @nodoc
class __$TaskCreationStateCopyWithImpl<$Res>
    implements _$TaskCreationStateCopyWith<$Res> {
  __$TaskCreationStateCopyWithImpl(this._self, this._then);

  final _TaskCreationState _self;
  final $Res Function(_TaskCreationState) _then;

/// Create a copy of TaskCreationState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? request = null,Object? isSubmitting = null,}) {
  return _then(_TaskCreationState(
request: null == request ? _self.request : request // ignore: cast_nullable_to_non_nullable
as TaskCreationRequest,isSubmitting: null == isSubmitting ? _self.isSubmitting : isSubmitting // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of TaskCreationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaskCreationRequestCopyWith<$Res> get request {
  
  return $TaskCreationRequestCopyWith<$Res>(_self.request, (value) {
    return _then(_self.copyWith(request: value));
  });
}
}

// dart format on
