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

 String get title; String get description; String get criteria; DateTime? get selectedDateTime; String get taskStatus; List<String> get selectedStrategies;
/// Create a copy of TaskCreationRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskCreationRequestCopyWith<TaskCreationRequest> get copyWith => _$TaskCreationRequestCopyWithImpl<TaskCreationRequest>(this as TaskCreationRequest, _$identity);

  /// Serializes this TaskCreationRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskCreationRequest&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.criteria, criteria) || other.criteria == criteria)&&(identical(other.selectedDateTime, selectedDateTime) || other.selectedDateTime == selectedDateTime)&&(identical(other.taskStatus, taskStatus) || other.taskStatus == taskStatus)&&const DeepCollectionEquality().equals(other.selectedStrategies, selectedStrategies));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,description,criteria,selectedDateTime,taskStatus,const DeepCollectionEquality().hash(selectedStrategies));

@override
String toString() {
  return 'TaskCreationRequest(title: $title, description: $description, criteria: $criteria, selectedDateTime: $selectedDateTime, taskStatus: $taskStatus, selectedStrategies: $selectedStrategies)';
}


}

/// @nodoc
abstract mixin class $TaskCreationRequestCopyWith<$Res>  {
  factory $TaskCreationRequestCopyWith(TaskCreationRequest value, $Res Function(TaskCreationRequest) _then) = _$TaskCreationRequestCopyWithImpl;
@useResult
$Res call({
 String title, String description, String criteria, DateTime? selectedDateTime, String taskStatus, List<String> selectedStrategies
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
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? description = null,Object? criteria = null,Object? selectedDateTime = freezed,Object? taskStatus = null,Object? selectedStrategies = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,criteria: null == criteria ? _self.criteria : criteria // ignore: cast_nullable_to_non_nullable
as String,selectedDateTime: freezed == selectedDateTime ? _self.selectedDateTime : selectedDateTime // ignore: cast_nullable_to_non_nullable
as DateTime?,taskStatus: null == taskStatus ? _self.taskStatus : taskStatus // ignore: cast_nullable_to_non_nullable
as String,selectedStrategies: null == selectedStrategies ? _self.selectedStrategies : selectedStrategies // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  String description,  String criteria,  DateTime? selectedDateTime,  String taskStatus,  List<String> selectedStrategies)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskCreationRequest() when $default != null:
return $default(_that.title,_that.description,_that.criteria,_that.selectedDateTime,_that.taskStatus,_that.selectedStrategies);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  String description,  String criteria,  DateTime? selectedDateTime,  String taskStatus,  List<String> selectedStrategies)  $default,) {final _that = this;
switch (_that) {
case _TaskCreationRequest():
return $default(_that.title,_that.description,_that.criteria,_that.selectedDateTime,_that.taskStatus,_that.selectedStrategies);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  String description,  String criteria,  DateTime? selectedDateTime,  String taskStatus,  List<String> selectedStrategies)?  $default,) {final _that = this;
switch (_that) {
case _TaskCreationRequest() when $default != null:
return $default(_that.title,_that.description,_that.criteria,_that.selectedDateTime,_that.taskStatus,_that.selectedStrategies);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaskCreationRequest implements TaskCreationRequest {
  const _TaskCreationRequest({this.title = '', this.description = '', this.criteria = '', this.selectedDateTime, this.taskStatus = 'open', final  List<String> selectedStrategies = const []}): _selectedStrategies = selectedStrategies;
  factory _TaskCreationRequest.fromJson(Map<String, dynamic> json) => _$TaskCreationRequestFromJson(json);

@override@JsonKey() final  String title;
@override@JsonKey() final  String description;
@override@JsonKey() final  String criteria;
@override final  DateTime? selectedDateTime;
@override@JsonKey() final  String taskStatus;
 final  List<String> _selectedStrategies;
@override@JsonKey() List<String> get selectedStrategies {
  if (_selectedStrategies is EqualUnmodifiableListView) return _selectedStrategies;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_selectedStrategies);
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskCreationRequest&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.criteria, criteria) || other.criteria == criteria)&&(identical(other.selectedDateTime, selectedDateTime) || other.selectedDateTime == selectedDateTime)&&(identical(other.taskStatus, taskStatus) || other.taskStatus == taskStatus)&&const DeepCollectionEquality().equals(other._selectedStrategies, _selectedStrategies));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,description,criteria,selectedDateTime,taskStatus,const DeepCollectionEquality().hash(_selectedStrategies));

@override
String toString() {
  return 'TaskCreationRequest(title: $title, description: $description, criteria: $criteria, selectedDateTime: $selectedDateTime, taskStatus: $taskStatus, selectedStrategies: $selectedStrategies)';
}


}

/// @nodoc
abstract mixin class _$TaskCreationRequestCopyWith<$Res> implements $TaskCreationRequestCopyWith<$Res> {
  factory _$TaskCreationRequestCopyWith(_TaskCreationRequest value, $Res Function(_TaskCreationRequest) _then) = __$TaskCreationRequestCopyWithImpl;
@override @useResult
$Res call({
 String title, String description, String criteria, DateTime? selectedDateTime, String taskStatus, List<String> selectedStrategies
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
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? description = null,Object? criteria = null,Object? selectedDateTime = freezed,Object? taskStatus = null,Object? selectedStrategies = null,}) {
  return _then(_TaskCreationRequest(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,criteria: null == criteria ? _self.criteria : criteria // ignore: cast_nullable_to_non_nullable
as String,selectedDateTime: freezed == selectedDateTime ? _self.selectedDateTime : selectedDateTime // ignore: cast_nullable_to_non_nullable
as DateTime?,taskStatus: null == taskStatus ? _self.taskStatus : taskStatus // ignore: cast_nullable_to_non_nullable
as String,selectedStrategies: null == selectedStrategies ? _self._selectedStrategies : selectedStrategies // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
