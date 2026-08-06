// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TaskDto {

 String get id; String get taskerId; String get title; String? get description; String? get criteria; String? get dueDate; String get status; String get createdAt; String get updatedAt; PublicProfileDto? get tasker; List<RefereeRequestDto> get refereeRequests;
/// Create a copy of TaskDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskDtoCopyWith<TaskDto> get copyWith => _$TaskDtoCopyWithImpl<TaskDto>(this as TaskDto, _$identity);

  /// Serializes this TaskDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskDto&&(identical(other.id, id) || other.id == id)&&(identical(other.taskerId, taskerId) || other.taskerId == taskerId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.criteria, criteria) || other.criteria == criteria)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.tasker, tasker) || other.tasker == tasker)&&const DeepCollectionEquality().equals(other.refereeRequests, refereeRequests));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,taskerId,title,description,criteria,dueDate,status,createdAt,updatedAt,tasker,const DeepCollectionEquality().hash(refereeRequests));

@override
String toString() {
  return 'TaskDto(id: $id, taskerId: $taskerId, title: $title, description: $description, criteria: $criteria, dueDate: $dueDate, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, tasker: $tasker, refereeRequests: $refereeRequests)';
}


}

/// @nodoc
abstract mixin class $TaskDtoCopyWith<$Res>  {
  factory $TaskDtoCopyWith(TaskDto value, $Res Function(TaskDto) _then) = _$TaskDtoCopyWithImpl;
@useResult
$Res call({
 String id, String taskerId, String title, String? description, String? criteria, String? dueDate, String status, String createdAt, String updatedAt, PublicProfileDto? tasker, List<RefereeRequestDto> refereeRequests
});


$PublicProfileDtoCopyWith<$Res>? get tasker;

}
/// @nodoc
class _$TaskDtoCopyWithImpl<$Res>
    implements $TaskDtoCopyWith<$Res> {
  _$TaskDtoCopyWithImpl(this._self, this._then);

  final TaskDto _self;
  final $Res Function(TaskDto) _then;

/// Create a copy of TaskDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? taskerId = null,Object? title = null,Object? description = freezed,Object? criteria = freezed,Object? dueDate = freezed,Object? status = null,Object? createdAt = null,Object? updatedAt = null,Object? tasker = freezed,Object? refereeRequests = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,taskerId: null == taskerId ? _self.taskerId : taskerId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,criteria: freezed == criteria ? _self.criteria : criteria // ignore: cast_nullable_to_non_nullable
as String?,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,tasker: freezed == tasker ? _self.tasker : tasker // ignore: cast_nullable_to_non_nullable
as PublicProfileDto?,refereeRequests: null == refereeRequests ? _self.refereeRequests : refereeRequests // ignore: cast_nullable_to_non_nullable
as List<RefereeRequestDto>,
  ));
}
/// Create a copy of TaskDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicProfileDtoCopyWith<$Res>? get tasker {
    if (_self.tasker == null) {
    return null;
  }

  return $PublicProfileDtoCopyWith<$Res>(_self.tasker!, (value) {
    return _then(_self.copyWith(tasker: value));
  });
}
}


/// Adds pattern-matching-related methods to [TaskDto].
extension TaskDtoPatterns on TaskDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskDto value)  $default,){
final _that = this;
switch (_that) {
case _TaskDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskDto value)?  $default,){
final _that = this;
switch (_that) {
case _TaskDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String taskerId,  String title,  String? description,  String? criteria,  String? dueDate,  String status,  String createdAt,  String updatedAt,  PublicProfileDto? tasker,  List<RefereeRequestDto> refereeRequests)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskDto() when $default != null:
return $default(_that.id,_that.taskerId,_that.title,_that.description,_that.criteria,_that.dueDate,_that.status,_that.createdAt,_that.updatedAt,_that.tasker,_that.refereeRequests);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String taskerId,  String title,  String? description,  String? criteria,  String? dueDate,  String status,  String createdAt,  String updatedAt,  PublicProfileDto? tasker,  List<RefereeRequestDto> refereeRequests)  $default,) {final _that = this;
switch (_that) {
case _TaskDto():
return $default(_that.id,_that.taskerId,_that.title,_that.description,_that.criteria,_that.dueDate,_that.status,_that.createdAt,_that.updatedAt,_that.tasker,_that.refereeRequests);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String taskerId,  String title,  String? description,  String? criteria,  String? dueDate,  String status,  String createdAt,  String updatedAt,  PublicProfileDto? tasker,  List<RefereeRequestDto> refereeRequests)?  $default,) {final _that = this;
switch (_that) {
case _TaskDto() when $default != null:
return $default(_that.id,_that.taskerId,_that.title,_that.description,_that.criteria,_that.dueDate,_that.status,_that.createdAt,_that.updatedAt,_that.tasker,_that.refereeRequests);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaskDto extends TaskDto {
  const _TaskDto({required this.id, required this.taskerId, required this.title, this.description, this.criteria, this.dueDate, required this.status, required this.createdAt, required this.updatedAt, this.tasker, final  List<RefereeRequestDto> refereeRequests = const <RefereeRequestDto>[]}): _refereeRequests = refereeRequests,super._();
  factory _TaskDto.fromJson(Map<String, dynamic> json) => _$TaskDtoFromJson(json);

@override final  String id;
@override final  String taskerId;
@override final  String title;
@override final  String? description;
@override final  String? criteria;
@override final  String? dueDate;
@override final  String status;
@override final  String createdAt;
@override final  String updatedAt;
@override final  PublicProfileDto? tasker;
 final  List<RefereeRequestDto> _refereeRequests;
@override@JsonKey() List<RefereeRequestDto> get refereeRequests {
  if (_refereeRequests is EqualUnmodifiableListView) return _refereeRequests;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_refereeRequests);
}


/// Create a copy of TaskDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskDtoCopyWith<_TaskDto> get copyWith => __$TaskDtoCopyWithImpl<_TaskDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskDto&&(identical(other.id, id) || other.id == id)&&(identical(other.taskerId, taskerId) || other.taskerId == taskerId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.criteria, criteria) || other.criteria == criteria)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.tasker, tasker) || other.tasker == tasker)&&const DeepCollectionEquality().equals(other._refereeRequests, _refereeRequests));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,taskerId,title,description,criteria,dueDate,status,createdAt,updatedAt,tasker,const DeepCollectionEquality().hash(_refereeRequests));

@override
String toString() {
  return 'TaskDto(id: $id, taskerId: $taskerId, title: $title, description: $description, criteria: $criteria, dueDate: $dueDate, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, tasker: $tasker, refereeRequests: $refereeRequests)';
}


}

/// @nodoc
abstract mixin class _$TaskDtoCopyWith<$Res> implements $TaskDtoCopyWith<$Res> {
  factory _$TaskDtoCopyWith(_TaskDto value, $Res Function(_TaskDto) _then) = __$TaskDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String taskerId, String title, String? description, String? criteria, String? dueDate, String status, String createdAt, String updatedAt, PublicProfileDto? tasker, List<RefereeRequestDto> refereeRequests
});


@override $PublicProfileDtoCopyWith<$Res>? get tasker;

}
/// @nodoc
class __$TaskDtoCopyWithImpl<$Res>
    implements _$TaskDtoCopyWith<$Res> {
  __$TaskDtoCopyWithImpl(this._self, this._then);

  final _TaskDto _self;
  final $Res Function(_TaskDto) _then;

/// Create a copy of TaskDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? taskerId = null,Object? title = null,Object? description = freezed,Object? criteria = freezed,Object? dueDate = freezed,Object? status = null,Object? createdAt = null,Object? updatedAt = null,Object? tasker = freezed,Object? refereeRequests = null,}) {
  return _then(_TaskDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,taskerId: null == taskerId ? _self.taskerId : taskerId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,criteria: freezed == criteria ? _self.criteria : criteria // ignore: cast_nullable_to_non_nullable
as String?,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,tasker: freezed == tasker ? _self.tasker : tasker // ignore: cast_nullable_to_non_nullable
as PublicProfileDto?,refereeRequests: null == refereeRequests ? _self._refereeRequests : refereeRequests // ignore: cast_nullable_to_non_nullable
as List<RefereeRequestDto>,
  ));
}

/// Create a copy of TaskDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicProfileDtoCopyWith<$Res>? get tasker {
    if (_self.tasker == null) {
    return null;
  }

  return $PublicProfileDtoCopyWith<$Res>(_self.tasker!, (value) {
    return _then(_self.copyWith(tasker: value));
  });
}
}

// dart format on
