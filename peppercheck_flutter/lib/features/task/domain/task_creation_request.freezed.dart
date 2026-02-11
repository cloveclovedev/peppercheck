// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_creation_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TaskCreationRequest {

 String get title; String get description; String get criteria; DateTime? get dueDate; String get taskStatus; List<String> get matchingStrategies;
/// Create a copy of TaskCreationRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskCreationRequestCopyWith<TaskCreationRequest> get copyWith => _$TaskCreationRequestCopyWithImpl<TaskCreationRequest>(this as TaskCreationRequest, _$identity);

  /// Serializes this TaskCreationRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskCreationRequest&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.criteria, criteria) || other.criteria == criteria)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.taskStatus, taskStatus) || other.taskStatus == taskStatus)&&const DeepCollectionEquality().equals(other.matchingStrategies, matchingStrategies));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,description,criteria,dueDate,taskStatus,const DeepCollectionEquality().hash(matchingStrategies));

@override
String toString() {
  return 'TaskCreationRequest(title: $title, description: $description, criteria: $criteria, dueDate: $dueDate, taskStatus: $taskStatus, matchingStrategies: $matchingStrategies)';
}


}

/// @nodoc
abstract mixin class $TaskCreationRequestCopyWith<$Res>  {
  factory $TaskCreationRequestCopyWith(TaskCreationRequest value, $Res Function(TaskCreationRequest) _then) = _$TaskCreationRequestCopyWithImpl;
@useResult
$Res call({
 String title, String description, String criteria, DateTime? dueDate, String taskStatus, List<String> matchingStrategies
});




}
/// @nodoc
class _$TaskCreationRequestCopyWithImpl<$Res>
    implements $TaskCreationRequestCopyWith<$Res> {
  _$TaskCreationRequestCopyWithImpl(this._self, this._then);

  final TaskCreationRequest _self;
  final $Res Function(TaskCreationRequest) _then;

/// Create a copy of TaskCreationRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? description = null,Object? criteria = null,Object? dueDate = freezed,Object? taskStatus = null,Object? matchingStrategies = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,criteria: null == criteria ? _self.criteria : criteria // ignore: cast_nullable_to_non_nullable
as String,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as DateTime?,taskStatus: null == taskStatus ? _self.taskStatus : taskStatus // ignore: cast_nullable_to_non_nullable
as String,matchingStrategies: null == matchingStrategies ? _self.matchingStrategies : matchingStrategies // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [TaskCreationRequest].
extension TaskCreationRequestPatterns on TaskCreationRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskCreationRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskCreationRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskCreationRequest value)  $default,){
final _that = this;
switch (_that) {
case _TaskCreationRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskCreationRequest value)?  $default,){
final _that = this;
switch (_that) {
case _TaskCreationRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  String description,  String criteria,  DateTime? dueDate,  String taskStatus,  List<String> matchingStrategies)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskCreationRequest() when $default != null:
return $default(_that.title,_that.description,_that.criteria,_that.dueDate,_that.taskStatus,_that.matchingStrategies);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  String description,  String criteria,  DateTime? dueDate,  String taskStatus,  List<String> matchingStrategies)  $default,) {final _that = this;
switch (_that) {
case _TaskCreationRequest():
return $default(_that.title,_that.description,_that.criteria,_that.dueDate,_that.taskStatus,_that.matchingStrategies);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  String description,  String criteria,  DateTime? dueDate,  String taskStatus,  List<String> matchingStrategies)?  $default,) {final _that = this;
switch (_that) {
case _TaskCreationRequest() when $default != null:
return $default(_that.title,_that.description,_that.criteria,_that.dueDate,_that.taskStatus,_that.matchingStrategies);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaskCreationRequest implements TaskCreationRequest {
  const _TaskCreationRequest({this.title = '', this.description = '', this.criteria = '', this.dueDate, this.taskStatus = 'draft', final  List<String> matchingStrategies = const []}): _matchingStrategies = matchingStrategies;
  factory _TaskCreationRequest.fromJson(Map<String, dynamic> json) => _$TaskCreationRequestFromJson(json);

@override@JsonKey() final  String title;
@override@JsonKey() final  String description;
@override@JsonKey() final  String criteria;
@override final  DateTime? dueDate;
@override@JsonKey() final  String taskStatus;
 final  List<String> _matchingStrategies;
@override@JsonKey() List<String> get matchingStrategies {
  if (_matchingStrategies is EqualUnmodifiableListView) return _matchingStrategies;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_matchingStrategies);
}


/// Create a copy of TaskCreationRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskCreationRequestCopyWith<_TaskCreationRequest> get copyWith => __$TaskCreationRequestCopyWithImpl<_TaskCreationRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskCreationRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskCreationRequest&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.criteria, criteria) || other.criteria == criteria)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.taskStatus, taskStatus) || other.taskStatus == taskStatus)&&const DeepCollectionEquality().equals(other._matchingStrategies, _matchingStrategies));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,description,criteria,dueDate,taskStatus,const DeepCollectionEquality().hash(_matchingStrategies));

@override
String toString() {
  return 'TaskCreationRequest(title: $title, description: $description, criteria: $criteria, dueDate: $dueDate, taskStatus: $taskStatus, matchingStrategies: $matchingStrategies)';
}


}

/// @nodoc
abstract mixin class _$TaskCreationRequestCopyWith<$Res> implements $TaskCreationRequestCopyWith<$Res> {
  factory _$TaskCreationRequestCopyWith(_TaskCreationRequest value, $Res Function(_TaskCreationRequest) _then) = __$TaskCreationRequestCopyWithImpl;
@override @useResult
$Res call({
 String title, String description, String criteria, DateTime? dueDate, String taskStatus, List<String> matchingStrategies
});




}
/// @nodoc
class __$TaskCreationRequestCopyWithImpl<$Res>
    implements _$TaskCreationRequestCopyWith<$Res> {
  __$TaskCreationRequestCopyWithImpl(this._self, this._then);

  final _TaskCreationRequest _self;
  final $Res Function(_TaskCreationRequest) _then;

/// Create a copy of TaskCreationRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? description = null,Object? criteria = null,Object? dueDate = freezed,Object? taskStatus = null,Object? matchingStrategies = null,}) {
  return _then(_TaskCreationRequest(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,criteria: null == criteria ? _self.criteria : criteria // ignore: cast_nullable_to_non_nullable
as String,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as DateTime?,taskStatus: null == taskStatus ? _self.taskStatus : taskStatus // ignore: cast_nullable_to_non_nullable
as String,matchingStrategies: null == matchingStrategies ? _self._matchingStrategies : matchingStrategies // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
