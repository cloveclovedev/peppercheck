// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_evidence.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TaskEvidence {

 String get id;@JsonKey(name: 'task_id') String get taskId; String get description; String get status;@JsonKey(name: 'created_at') String get createdAt;@JsonKey(name: 'updated_at') String get updatedAt;@JsonKey(name: 'task_evidence_assets') List<TaskEvidenceAsset> get assets;
/// Create a copy of TaskEvidence
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskEvidenceCopyWith<TaskEvidence> get copyWith => _$TaskEvidenceCopyWithImpl<TaskEvidence>(this as TaskEvidence, _$identity);

  /// Serializes this TaskEvidence to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskEvidence&&(identical(other.id, id) || other.id == id)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.description, description) || other.description == description)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other.assets, assets));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,taskId,description,status,createdAt,updatedAt,const DeepCollectionEquality().hash(assets));

@override
String toString() {
  return 'TaskEvidence(id: $id, taskId: $taskId, description: $description, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, assets: $assets)';
}


}

/// @nodoc
abstract mixin class $TaskEvidenceCopyWith<$Res>  {
  factory $TaskEvidenceCopyWith(TaskEvidence value, $Res Function(TaskEvidence) _then) = _$TaskEvidenceCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'task_id') String taskId, String description, String status,@JsonKey(name: 'created_at') String createdAt,@JsonKey(name: 'updated_at') String updatedAt,@JsonKey(name: 'task_evidence_assets') List<TaskEvidenceAsset> assets
});




}
/// @nodoc
class _$TaskEvidenceCopyWithImpl<$Res>
    implements $TaskEvidenceCopyWith<$Res> {
  _$TaskEvidenceCopyWithImpl(this._self, this._then);

  final TaskEvidence _self;
  final $Res Function(TaskEvidence) _then;

/// Create a copy of TaskEvidence
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? taskId = null,Object? description = null,Object? status = null,Object? createdAt = null,Object? updatedAt = null,Object? assets = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,assets: null == assets ? _self.assets : assets // ignore: cast_nullable_to_non_nullable
as List<TaskEvidenceAsset>,
  ));
}

}


/// Adds pattern-matching-related methods to [TaskEvidence].
extension TaskEvidencePatterns on TaskEvidence {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskEvidence value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskEvidence() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskEvidence value)  $default,){
final _that = this;
switch (_that) {
case _TaskEvidence():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskEvidence value)?  $default,){
final _that = this;
switch (_that) {
case _TaskEvidence() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'task_id')  String taskId,  String description,  String status, @JsonKey(name: 'created_at')  String createdAt, @JsonKey(name: 'updated_at')  String updatedAt, @JsonKey(name: 'task_evidence_assets')  List<TaskEvidenceAsset> assets)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskEvidence() when $default != null:
return $default(_that.id,_that.taskId,_that.description,_that.status,_that.createdAt,_that.updatedAt,_that.assets);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'task_id')  String taskId,  String description,  String status, @JsonKey(name: 'created_at')  String createdAt, @JsonKey(name: 'updated_at')  String updatedAt, @JsonKey(name: 'task_evidence_assets')  List<TaskEvidenceAsset> assets)  $default,) {final _that = this;
switch (_that) {
case _TaskEvidence():
return $default(_that.id,_that.taskId,_that.description,_that.status,_that.createdAt,_that.updatedAt,_that.assets);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'task_id')  String taskId,  String description,  String status, @JsonKey(name: 'created_at')  String createdAt, @JsonKey(name: 'updated_at')  String updatedAt, @JsonKey(name: 'task_evidence_assets')  List<TaskEvidenceAsset> assets)?  $default,) {final _that = this;
switch (_that) {
case _TaskEvidence() when $default != null:
return $default(_that.id,_that.taskId,_that.description,_that.status,_that.createdAt,_that.updatedAt,_that.assets);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaskEvidence implements TaskEvidence {
  const _TaskEvidence({required this.id, @JsonKey(name: 'task_id') required this.taskId, required this.description, this.status = 'pending_upload', @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'updated_at') required this.updatedAt, @JsonKey(name: 'task_evidence_assets') final  List<TaskEvidenceAsset> assets = const []}): _assets = assets;
  factory _TaskEvidence.fromJson(Map<String, dynamic> json) => _$TaskEvidenceFromJson(json);

@override final  String id;
@override@JsonKey(name: 'task_id') final  String taskId;
@override final  String description;
@override@JsonKey() final  String status;
@override@JsonKey(name: 'created_at') final  String createdAt;
@override@JsonKey(name: 'updated_at') final  String updatedAt;
 final  List<TaskEvidenceAsset> _assets;
@override@JsonKey(name: 'task_evidence_assets') List<TaskEvidenceAsset> get assets {
  if (_assets is EqualUnmodifiableListView) return _assets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_assets);
}


/// Create a copy of TaskEvidence
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskEvidenceCopyWith<_TaskEvidence> get copyWith => __$TaskEvidenceCopyWithImpl<_TaskEvidence>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskEvidenceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskEvidence&&(identical(other.id, id) || other.id == id)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.description, description) || other.description == description)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other._assets, _assets));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,taskId,description,status,createdAt,updatedAt,const DeepCollectionEquality().hash(_assets));

@override
String toString() {
  return 'TaskEvidence(id: $id, taskId: $taskId, description: $description, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, assets: $assets)';
}


}

/// @nodoc
abstract mixin class _$TaskEvidenceCopyWith<$Res> implements $TaskEvidenceCopyWith<$Res> {
  factory _$TaskEvidenceCopyWith(_TaskEvidence value, $Res Function(_TaskEvidence) _then) = __$TaskEvidenceCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'task_id') String taskId, String description, String status,@JsonKey(name: 'created_at') String createdAt,@JsonKey(name: 'updated_at') String updatedAt,@JsonKey(name: 'task_evidence_assets') List<TaskEvidenceAsset> assets
});




}
/// @nodoc
class __$TaskEvidenceCopyWithImpl<$Res>
    implements _$TaskEvidenceCopyWith<$Res> {
  __$TaskEvidenceCopyWithImpl(this._self, this._then);

  final _TaskEvidence _self;
  final $Res Function(_TaskEvidence) _then;

/// Create a copy of TaskEvidence
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? taskId = null,Object? description = null,Object? status = null,Object? createdAt = null,Object? updatedAt = null,Object? assets = null,}) {
  return _then(_TaskEvidence(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,assets: null == assets ? _self._assets : assets // ignore: cast_nullable_to_non_nullable
as List<TaskEvidenceAsset>,
  ));
}


}


/// @nodoc
mixin _$TaskEvidenceAsset {

 String get id;@JsonKey(name: 'evidence_id') String get evidenceId;@JsonKey(name: 'file_url') String get fileUrl;@JsonKey(name: 'file_size_bytes') int? get fileSizeBytes;@JsonKey(name: 'content_type') String? get contentType;@JsonKey(name: 'public_url') String? get publicUrl;@JsonKey(name: 'processing_status') String get processingStatus;@JsonKey(name: 'error_message') String? get errorMessage;@JsonKey(name: 'created_at') String get createdAt;
/// Create a copy of TaskEvidenceAsset
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskEvidenceAssetCopyWith<TaskEvidenceAsset> get copyWith => _$TaskEvidenceAssetCopyWithImpl<TaskEvidenceAsset>(this as TaskEvidenceAsset, _$identity);

  /// Serializes this TaskEvidenceAsset to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskEvidenceAsset&&(identical(other.id, id) || other.id == id)&&(identical(other.evidenceId, evidenceId) || other.evidenceId == evidenceId)&&(identical(other.fileUrl, fileUrl) || other.fileUrl == fileUrl)&&(identical(other.fileSizeBytes, fileSizeBytes) || other.fileSizeBytes == fileSizeBytes)&&(identical(other.contentType, contentType) || other.contentType == contentType)&&(identical(other.publicUrl, publicUrl) || other.publicUrl == publicUrl)&&(identical(other.processingStatus, processingStatus) || other.processingStatus == processingStatus)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,evidenceId,fileUrl,fileSizeBytes,contentType,publicUrl,processingStatus,errorMessage,createdAt);

@override
String toString() {
  return 'TaskEvidenceAsset(id: $id, evidenceId: $evidenceId, fileUrl: $fileUrl, fileSizeBytes: $fileSizeBytes, contentType: $contentType, publicUrl: $publicUrl, processingStatus: $processingStatus, errorMessage: $errorMessage, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $TaskEvidenceAssetCopyWith<$Res>  {
  factory $TaskEvidenceAssetCopyWith(TaskEvidenceAsset value, $Res Function(TaskEvidenceAsset) _then) = _$TaskEvidenceAssetCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'evidence_id') String evidenceId,@JsonKey(name: 'file_url') String fileUrl,@JsonKey(name: 'file_size_bytes') int? fileSizeBytes,@JsonKey(name: 'content_type') String? contentType,@JsonKey(name: 'public_url') String? publicUrl,@JsonKey(name: 'processing_status') String processingStatus,@JsonKey(name: 'error_message') String? errorMessage,@JsonKey(name: 'created_at') String createdAt
});




}
/// @nodoc
class _$TaskEvidenceAssetCopyWithImpl<$Res>
    implements $TaskEvidenceAssetCopyWith<$Res> {
  _$TaskEvidenceAssetCopyWithImpl(this._self, this._then);

  final TaskEvidenceAsset _self;
  final $Res Function(TaskEvidenceAsset) _then;

/// Create a copy of TaskEvidenceAsset
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? evidenceId = null,Object? fileUrl = null,Object? fileSizeBytes = freezed,Object? contentType = freezed,Object? publicUrl = freezed,Object? processingStatus = null,Object? errorMessage = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,evidenceId: null == evidenceId ? _self.evidenceId : evidenceId // ignore: cast_nullable_to_non_nullable
as String,fileUrl: null == fileUrl ? _self.fileUrl : fileUrl // ignore: cast_nullable_to_non_nullable
as String,fileSizeBytes: freezed == fileSizeBytes ? _self.fileSizeBytes : fileSizeBytes // ignore: cast_nullable_to_non_nullable
as int?,contentType: freezed == contentType ? _self.contentType : contentType // ignore: cast_nullable_to_non_nullable
as String?,publicUrl: freezed == publicUrl ? _self.publicUrl : publicUrl // ignore: cast_nullable_to_non_nullable
as String?,processingStatus: null == processingStatus ? _self.processingStatus : processingStatus // ignore: cast_nullable_to_non_nullable
as String,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TaskEvidenceAsset].
extension TaskEvidenceAssetPatterns on TaskEvidenceAsset {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskEvidenceAsset value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskEvidenceAsset() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskEvidenceAsset value)  $default,){
final _that = this;
switch (_that) {
case _TaskEvidenceAsset():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskEvidenceAsset value)?  $default,){
final _that = this;
switch (_that) {
case _TaskEvidenceAsset() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'evidence_id')  String evidenceId, @JsonKey(name: 'file_url')  String fileUrl, @JsonKey(name: 'file_size_bytes')  int? fileSizeBytes, @JsonKey(name: 'content_type')  String? contentType, @JsonKey(name: 'public_url')  String? publicUrl, @JsonKey(name: 'processing_status')  String processingStatus, @JsonKey(name: 'error_message')  String? errorMessage, @JsonKey(name: 'created_at')  String createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskEvidenceAsset() when $default != null:
return $default(_that.id,_that.evidenceId,_that.fileUrl,_that.fileSizeBytes,_that.contentType,_that.publicUrl,_that.processingStatus,_that.errorMessage,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'evidence_id')  String evidenceId, @JsonKey(name: 'file_url')  String fileUrl, @JsonKey(name: 'file_size_bytes')  int? fileSizeBytes, @JsonKey(name: 'content_type')  String? contentType, @JsonKey(name: 'public_url')  String? publicUrl, @JsonKey(name: 'processing_status')  String processingStatus, @JsonKey(name: 'error_message')  String? errorMessage, @JsonKey(name: 'created_at')  String createdAt)  $default,) {final _that = this;
switch (_that) {
case _TaskEvidenceAsset():
return $default(_that.id,_that.evidenceId,_that.fileUrl,_that.fileSizeBytes,_that.contentType,_that.publicUrl,_that.processingStatus,_that.errorMessage,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'evidence_id')  String evidenceId, @JsonKey(name: 'file_url')  String fileUrl, @JsonKey(name: 'file_size_bytes')  int? fileSizeBytes, @JsonKey(name: 'content_type')  String? contentType, @JsonKey(name: 'public_url')  String? publicUrl, @JsonKey(name: 'processing_status')  String processingStatus, @JsonKey(name: 'error_message')  String? errorMessage, @JsonKey(name: 'created_at')  String createdAt)?  $default,) {final _that = this;
switch (_that) {
case _TaskEvidenceAsset() when $default != null:
return $default(_that.id,_that.evidenceId,_that.fileUrl,_that.fileSizeBytes,_that.contentType,_that.publicUrl,_that.processingStatus,_that.errorMessage,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaskEvidenceAsset implements TaskEvidenceAsset {
  const _TaskEvidenceAsset({required this.id, @JsonKey(name: 'evidence_id') required this.evidenceId, @JsonKey(name: 'file_url') required this.fileUrl, @JsonKey(name: 'file_size_bytes') this.fileSizeBytes, @JsonKey(name: 'content_type') this.contentType, @JsonKey(name: 'public_url') this.publicUrl, @JsonKey(name: 'processing_status') this.processingStatus = 'pending', @JsonKey(name: 'error_message') this.errorMessage, @JsonKey(name: 'created_at') required this.createdAt});
  factory _TaskEvidenceAsset.fromJson(Map<String, dynamic> json) => _$TaskEvidenceAssetFromJson(json);

@override final  String id;
@override@JsonKey(name: 'evidence_id') final  String evidenceId;
@override@JsonKey(name: 'file_url') final  String fileUrl;
@override@JsonKey(name: 'file_size_bytes') final  int? fileSizeBytes;
@override@JsonKey(name: 'content_type') final  String? contentType;
@override@JsonKey(name: 'public_url') final  String? publicUrl;
@override@JsonKey(name: 'processing_status') final  String processingStatus;
@override@JsonKey(name: 'error_message') final  String? errorMessage;
@override@JsonKey(name: 'created_at') final  String createdAt;

/// Create a copy of TaskEvidenceAsset
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskEvidenceAssetCopyWith<_TaskEvidenceAsset> get copyWith => __$TaskEvidenceAssetCopyWithImpl<_TaskEvidenceAsset>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskEvidenceAssetToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskEvidenceAsset&&(identical(other.id, id) || other.id == id)&&(identical(other.evidenceId, evidenceId) || other.evidenceId == evidenceId)&&(identical(other.fileUrl, fileUrl) || other.fileUrl == fileUrl)&&(identical(other.fileSizeBytes, fileSizeBytes) || other.fileSizeBytes == fileSizeBytes)&&(identical(other.contentType, contentType) || other.contentType == contentType)&&(identical(other.publicUrl, publicUrl) || other.publicUrl == publicUrl)&&(identical(other.processingStatus, processingStatus) || other.processingStatus == processingStatus)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,evidenceId,fileUrl,fileSizeBytes,contentType,publicUrl,processingStatus,errorMessage,createdAt);

@override
String toString() {
  return 'TaskEvidenceAsset(id: $id, evidenceId: $evidenceId, fileUrl: $fileUrl, fileSizeBytes: $fileSizeBytes, contentType: $contentType, publicUrl: $publicUrl, processingStatus: $processingStatus, errorMessage: $errorMessage, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$TaskEvidenceAssetCopyWith<$Res> implements $TaskEvidenceAssetCopyWith<$Res> {
  factory _$TaskEvidenceAssetCopyWith(_TaskEvidenceAsset value, $Res Function(_TaskEvidenceAsset) _then) = __$TaskEvidenceAssetCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'evidence_id') String evidenceId,@JsonKey(name: 'file_url') String fileUrl,@JsonKey(name: 'file_size_bytes') int? fileSizeBytes,@JsonKey(name: 'content_type') String? contentType,@JsonKey(name: 'public_url') String? publicUrl,@JsonKey(name: 'processing_status') String processingStatus,@JsonKey(name: 'error_message') String? errorMessage,@JsonKey(name: 'created_at') String createdAt
});




}
/// @nodoc
class __$TaskEvidenceAssetCopyWithImpl<$Res>
    implements _$TaskEvidenceAssetCopyWith<$Res> {
  __$TaskEvidenceAssetCopyWithImpl(this._self, this._then);

  final _TaskEvidenceAsset _self;
  final $Res Function(_TaskEvidenceAsset) _then;

/// Create a copy of TaskEvidenceAsset
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? evidenceId = null,Object? fileUrl = null,Object? fileSizeBytes = freezed,Object? contentType = freezed,Object? publicUrl = freezed,Object? processingStatus = null,Object? errorMessage = freezed,Object? createdAt = null,}) {
  return _then(_TaskEvidenceAsset(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,evidenceId: null == evidenceId ? _self.evidenceId : evidenceId // ignore: cast_nullable_to_non_nullable
as String,fileUrl: null == fileUrl ? _self.fileUrl : fileUrl // ignore: cast_nullable_to_non_nullable
as String,fileSizeBytes: freezed == fileSizeBytes ? _self.fileSizeBytes : fileSizeBytes // ignore: cast_nullable_to_non_nullable
as int?,contentType: freezed == contentType ? _self.contentType : contentType // ignore: cast_nullable_to_non_nullable
as String?,publicUrl: freezed == publicUrl ? _self.publicUrl : publicUrl // ignore: cast_nullable_to_non_nullable
as String?,processingStatus: null == processingStatus ? _self.processingStatus : processingStatus // ignore: cast_nullable_to_non_nullable
as String,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
