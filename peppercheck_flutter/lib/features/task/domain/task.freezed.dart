// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Task {

 String get id;@JsonKey(name: 'tasker_id') String get taskerId; String get title; String? get description; String? get criteria;@JsonKey(name: 'due_date') String? get dueDate;@JsonKey(name: 'fee_amount') double? get feeAmount;@JsonKey(name: 'fee_currency') String? get feeCurrency; String get status;@JsonKey(name: 'created_at') String? get createdAt;@JsonKey(name: 'updated_at') String? get updatedAt;// Aggregated fields
@JsonKey(name: 'task_referee_requests') List<RefereeRequest> get refereeRequests; TaskEvidence? get evidence;@JsonKey(name: 'tasker_profile') Profile? get tasker;
/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskCopyWith<Task> get copyWith => _$TaskCopyWithImpl<Task>(this as Task, _$identity);

  /// Serializes this Task to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Task&&(identical(other.id, id) || other.id == id)&&(identical(other.taskerId, taskerId) || other.taskerId == taskerId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.criteria, criteria) || other.criteria == criteria)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.feeAmount, feeAmount) || other.feeAmount == feeAmount)&&(identical(other.feeCurrency, feeCurrency) || other.feeCurrency == feeCurrency)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other.refereeRequests, refereeRequests)&&(identical(other.evidence, evidence) || other.evidence == evidence)&&(identical(other.tasker, tasker) || other.tasker == tasker));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,taskerId,title,description,criteria,dueDate,feeAmount,feeCurrency,status,createdAt,updatedAt,const DeepCollectionEquality().hash(refereeRequests),evidence,tasker);

@override
String toString() {
  return 'Task(id: $id, taskerId: $taskerId, title: $title, description: $description, criteria: $criteria, dueDate: $dueDate, feeAmount: $feeAmount, feeCurrency: $feeCurrency, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, refereeRequests: $refereeRequests, evidence: $evidence, tasker: $tasker)';
}


}

/// @nodoc
abstract mixin class $TaskCopyWith<$Res>  {
  factory $TaskCopyWith(Task value, $Res Function(Task) _then) = _$TaskCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'tasker_id') String taskerId, String title, String? description, String? criteria,@JsonKey(name: 'due_date') String? dueDate,@JsonKey(name: 'fee_amount') double? feeAmount,@JsonKey(name: 'fee_currency') String? feeCurrency, String status,@JsonKey(name: 'created_at') String? createdAt,@JsonKey(name: 'updated_at') String? updatedAt,@JsonKey(name: 'task_referee_requests') List<RefereeRequest> refereeRequests, TaskEvidence? evidence,@JsonKey(name: 'tasker_profile') Profile? tasker
});


$TaskEvidenceCopyWith<$Res>? get evidence;$ProfileCopyWith<$Res>? get tasker;

}
/// @nodoc
class _$TaskCopyWithImpl<$Res>
    implements $TaskCopyWith<$Res> {
  _$TaskCopyWithImpl(this._self, this._then);

  final Task _self;
  final $Res Function(Task) _then;

/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? taskerId = null,Object? title = null,Object? description = freezed,Object? criteria = freezed,Object? dueDate = freezed,Object? feeAmount = freezed,Object? feeCurrency = freezed,Object? status = null,Object? createdAt = freezed,Object? updatedAt = freezed,Object? refereeRequests = null,Object? evidence = freezed,Object? tasker = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,taskerId: null == taskerId ? _self.taskerId : taskerId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,criteria: freezed == criteria ? _self.criteria : criteria // ignore: cast_nullable_to_non_nullable
as String?,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as String?,feeAmount: freezed == feeAmount ? _self.feeAmount : feeAmount // ignore: cast_nullable_to_non_nullable
as double?,feeCurrency: freezed == feeCurrency ? _self.feeCurrency : feeCurrency // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,refereeRequests: null == refereeRequests ? _self.refereeRequests : refereeRequests // ignore: cast_nullable_to_non_nullable
as List<RefereeRequest>,evidence: freezed == evidence ? _self.evidence : evidence // ignore: cast_nullable_to_non_nullable
as TaskEvidence?,tasker: freezed == tasker ? _self.tasker : tasker // ignore: cast_nullable_to_non_nullable
as Profile?,
  ));
}
/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaskEvidenceCopyWith<$Res>? get evidence {
    if (_self.evidence == null) {
    return null;
  }

  return $TaskEvidenceCopyWith<$Res>(_self.evidence!, (value) {
    return _then(_self.copyWith(evidence: value));
  });
}/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileCopyWith<$Res>? get tasker {
    if (_self.tasker == null) {
    return null;
  }

  return $ProfileCopyWith<$Res>(_self.tasker!, (value) {
    return _then(_self.copyWith(tasker: value));
  });
}
}


/// Adds pattern-matching-related methods to [Task].
extension TaskPatterns on Task {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Task value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Task() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Task value)  $default,){
final _that = this;
switch (_that) {
case _Task():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Task value)?  $default,){
final _that = this;
switch (_that) {
case _Task() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'tasker_id')  String taskerId,  String title,  String? description,  String? criteria, @JsonKey(name: 'due_date')  String? dueDate, @JsonKey(name: 'fee_amount')  double? feeAmount, @JsonKey(name: 'fee_currency')  String? feeCurrency,  String status, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'updated_at')  String? updatedAt, @JsonKey(name: 'task_referee_requests')  List<RefereeRequest> refereeRequests,  TaskEvidence? evidence, @JsonKey(name: 'tasker_profile')  Profile? tasker)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Task() when $default != null:
return $default(_that.id,_that.taskerId,_that.title,_that.description,_that.criteria,_that.dueDate,_that.feeAmount,_that.feeCurrency,_that.status,_that.createdAt,_that.updatedAt,_that.refereeRequests,_that.evidence,_that.tasker);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'tasker_id')  String taskerId,  String title,  String? description,  String? criteria, @JsonKey(name: 'due_date')  String? dueDate, @JsonKey(name: 'fee_amount')  double? feeAmount, @JsonKey(name: 'fee_currency')  String? feeCurrency,  String status, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'updated_at')  String? updatedAt, @JsonKey(name: 'task_referee_requests')  List<RefereeRequest> refereeRequests,  TaskEvidence? evidence, @JsonKey(name: 'tasker_profile')  Profile? tasker)  $default,) {final _that = this;
switch (_that) {
case _Task():
return $default(_that.id,_that.taskerId,_that.title,_that.description,_that.criteria,_that.dueDate,_that.feeAmount,_that.feeCurrency,_that.status,_that.createdAt,_that.updatedAt,_that.refereeRequests,_that.evidence,_that.tasker);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'tasker_id')  String taskerId,  String title,  String? description,  String? criteria, @JsonKey(name: 'due_date')  String? dueDate, @JsonKey(name: 'fee_amount')  double? feeAmount, @JsonKey(name: 'fee_currency')  String? feeCurrency,  String status, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'updated_at')  String? updatedAt, @JsonKey(name: 'task_referee_requests')  List<RefereeRequest> refereeRequests,  TaskEvidence? evidence, @JsonKey(name: 'tasker_profile')  Profile? tasker)?  $default,) {final _that = this;
switch (_that) {
case _Task() when $default != null:
return $default(_that.id,_that.taskerId,_that.title,_that.description,_that.criteria,_that.dueDate,_that.feeAmount,_that.feeCurrency,_that.status,_that.createdAt,_that.updatedAt,_that.refereeRequests,_that.evidence,_that.tasker);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Task extends Task {
  const _Task({required this.id, @JsonKey(name: 'tasker_id') required this.taskerId, required this.title, this.description, this.criteria, @JsonKey(name: 'due_date') this.dueDate, @JsonKey(name: 'fee_amount') this.feeAmount, @JsonKey(name: 'fee_currency') this.feeCurrency, required this.status, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt, @JsonKey(name: 'task_referee_requests') final  List<RefereeRequest> refereeRequests = const [], this.evidence, @JsonKey(name: 'tasker_profile') this.tasker}): _refereeRequests = refereeRequests,super._();
  factory _Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);

@override final  String id;
@override@JsonKey(name: 'tasker_id') final  String taskerId;
@override final  String title;
@override final  String? description;
@override final  String? criteria;
@override@JsonKey(name: 'due_date') final  String? dueDate;
@override@JsonKey(name: 'fee_amount') final  double? feeAmount;
@override@JsonKey(name: 'fee_currency') final  String? feeCurrency;
@override final  String status;
@override@JsonKey(name: 'created_at') final  String? createdAt;
@override@JsonKey(name: 'updated_at') final  String? updatedAt;
// Aggregated fields
 final  List<RefereeRequest> _refereeRequests;
// Aggregated fields
@override@JsonKey(name: 'task_referee_requests') List<RefereeRequest> get refereeRequests {
  if (_refereeRequests is EqualUnmodifiableListView) return _refereeRequests;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_refereeRequests);
}

@override final  TaskEvidence? evidence;
@override@JsonKey(name: 'tasker_profile') final  Profile? tasker;

/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskCopyWith<_Task> get copyWith => __$TaskCopyWithImpl<_Task>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Task&&(identical(other.id, id) || other.id == id)&&(identical(other.taskerId, taskerId) || other.taskerId == taskerId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.criteria, criteria) || other.criteria == criteria)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.feeAmount, feeAmount) || other.feeAmount == feeAmount)&&(identical(other.feeCurrency, feeCurrency) || other.feeCurrency == feeCurrency)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other._refereeRequests, _refereeRequests)&&(identical(other.evidence, evidence) || other.evidence == evidence)&&(identical(other.tasker, tasker) || other.tasker == tasker));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,taskerId,title,description,criteria,dueDate,feeAmount,feeCurrency,status,createdAt,updatedAt,const DeepCollectionEquality().hash(_refereeRequests),evidence,tasker);

@override
String toString() {
  return 'Task(id: $id, taskerId: $taskerId, title: $title, description: $description, criteria: $criteria, dueDate: $dueDate, feeAmount: $feeAmount, feeCurrency: $feeCurrency, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, refereeRequests: $refereeRequests, evidence: $evidence, tasker: $tasker)';
}


}

/// @nodoc
abstract mixin class _$TaskCopyWith<$Res> implements $TaskCopyWith<$Res> {
  factory _$TaskCopyWith(_Task value, $Res Function(_Task) _then) = __$TaskCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'tasker_id') String taskerId, String title, String? description, String? criteria,@JsonKey(name: 'due_date') String? dueDate,@JsonKey(name: 'fee_amount') double? feeAmount,@JsonKey(name: 'fee_currency') String? feeCurrency, String status,@JsonKey(name: 'created_at') String? createdAt,@JsonKey(name: 'updated_at') String? updatedAt,@JsonKey(name: 'task_referee_requests') List<RefereeRequest> refereeRequests, TaskEvidence? evidence,@JsonKey(name: 'tasker_profile') Profile? tasker
});


@override $TaskEvidenceCopyWith<$Res>? get evidence;@override $ProfileCopyWith<$Res>? get tasker;

}
/// @nodoc
class __$TaskCopyWithImpl<$Res>
    implements _$TaskCopyWith<$Res> {
  __$TaskCopyWithImpl(this._self, this._then);

  final _Task _self;
  final $Res Function(_Task) _then;

/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? taskerId = null,Object? title = null,Object? description = freezed,Object? criteria = freezed,Object? dueDate = freezed,Object? feeAmount = freezed,Object? feeCurrency = freezed,Object? status = null,Object? createdAt = freezed,Object? updatedAt = freezed,Object? refereeRequests = null,Object? evidence = freezed,Object? tasker = freezed,}) {
  return _then(_Task(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,taskerId: null == taskerId ? _self.taskerId : taskerId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,criteria: freezed == criteria ? _self.criteria : criteria // ignore: cast_nullable_to_non_nullable
as String?,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as String?,feeAmount: freezed == feeAmount ? _self.feeAmount : feeAmount // ignore: cast_nullable_to_non_nullable
as double?,feeCurrency: freezed == feeCurrency ? _self.feeCurrency : feeCurrency // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,refereeRequests: null == refereeRequests ? _self._refereeRequests : refereeRequests // ignore: cast_nullable_to_non_nullable
as List<RefereeRequest>,evidence: freezed == evidence ? _self.evidence : evidence // ignore: cast_nullable_to_non_nullable
as TaskEvidence?,tasker: freezed == tasker ? _self.tasker : tasker // ignore: cast_nullable_to_non_nullable
as Profile?,
  ));
}

/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaskEvidenceCopyWith<$Res>? get evidence {
    if (_self.evidence == null) {
    return null;
  }

  return $TaskEvidenceCopyWith<$Res>(_self.evidence!, (value) {
    return _then(_self.copyWith(evidence: value));
  });
}/// Create a copy of Task
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileCopyWith<$Res>? get tasker {
    if (_self.tasker == null) {
    return null;
  }

  return $ProfileCopyWith<$Res>(_self.tasker!, (value) {
    return _then(_self.copyWith(tasker: value));
  });
}
}

// dart format on
