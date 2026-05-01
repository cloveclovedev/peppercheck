// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'evidence_submission_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$EvidenceSubmissionState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EvidenceSubmissionState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'EvidenceSubmissionState()';
}


}

/// @nodoc
class $EvidenceSubmissionStateCopyWith<$Res>  {
$EvidenceSubmissionStateCopyWith(EvidenceSubmissionState _, $Res Function(EvidenceSubmissionState) __);
}


/// Adds pattern-matching-related methods to [EvidenceSubmissionState].
extension EvidenceSubmissionStatePatterns on EvidenceSubmissionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Idle value)?  idle,TResult Function( _Preparing value)?  preparing,TResult Function( _Uploading value)?  uploading,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Idle() when idle != null:
return idle(_that);case _Preparing() when preparing != null:
return preparing(_that);case _Uploading() when uploading != null:
return uploading(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Idle value)  idle,required TResult Function( _Preparing value)  preparing,required TResult Function( _Uploading value)  uploading,}){
final _that = this;
switch (_that) {
case _Idle():
return idle(_that);case _Preparing():
return preparing(_that);case _Uploading():
return uploading(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Idle value)?  idle,TResult? Function( _Preparing value)?  preparing,TResult? Function( _Uploading value)?  uploading,}){
final _that = this;
switch (_that) {
case _Idle() when idle != null:
return idle(_that);case _Preparing() when preparing != null:
return preparing(_that);case _Uploading() when uploading != null:
return uploading(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function( int current,  int total)?  preparing,TResult Function( int current,  int total)?  uploading,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Idle() when idle != null:
return idle();case _Preparing() when preparing != null:
return preparing(_that.current,_that.total);case _Uploading() when uploading != null:
return uploading(_that.current,_that.total);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function( int current,  int total)  preparing,required TResult Function( int current,  int total)  uploading,}) {final _that = this;
switch (_that) {
case _Idle():
return idle();case _Preparing():
return preparing(_that.current,_that.total);case _Uploading():
return uploading(_that.current,_that.total);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function( int current,  int total)?  preparing,TResult? Function( int current,  int total)?  uploading,}) {final _that = this;
switch (_that) {
case _Idle() when idle != null:
return idle();case _Preparing() when preparing != null:
return preparing(_that.current,_that.total);case _Uploading() when uploading != null:
return uploading(_that.current,_that.total);case _:
  return null;

}
}

}

/// @nodoc


class _Idle extends EvidenceSubmissionState {
  const _Idle(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Idle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'EvidenceSubmissionState.idle()';
}


}




/// @nodoc


class _Preparing extends EvidenceSubmissionState {
  const _Preparing({required this.current, required this.total}): super._();
  

 final  int current;
 final  int total;

/// Create a copy of EvidenceSubmissionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PreparingCopyWith<_Preparing> get copyWith => __$PreparingCopyWithImpl<_Preparing>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Preparing&&(identical(other.current, current) || other.current == current)&&(identical(other.total, total) || other.total == total));
}


@override
int get hashCode => Object.hash(runtimeType,current,total);

@override
String toString() {
  return 'EvidenceSubmissionState.preparing(current: $current, total: $total)';
}


}

/// @nodoc
abstract mixin class _$PreparingCopyWith<$Res> implements $EvidenceSubmissionStateCopyWith<$Res> {
  factory _$PreparingCopyWith(_Preparing value, $Res Function(_Preparing) _then) = __$PreparingCopyWithImpl;
@useResult
$Res call({
 int current, int total
});




}
/// @nodoc
class __$PreparingCopyWithImpl<$Res>
    implements _$PreparingCopyWith<$Res> {
  __$PreparingCopyWithImpl(this._self, this._then);

  final _Preparing _self;
  final $Res Function(_Preparing) _then;

/// Create a copy of EvidenceSubmissionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? current = null,Object? total = null,}) {
  return _then(_Preparing(
current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _Uploading extends EvidenceSubmissionState {
  const _Uploading({required this.current, required this.total}): super._();
  

 final  int current;
 final  int total;

/// Create a copy of EvidenceSubmissionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UploadingCopyWith<_Uploading> get copyWith => __$UploadingCopyWithImpl<_Uploading>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Uploading&&(identical(other.current, current) || other.current == current)&&(identical(other.total, total) || other.total == total));
}


@override
int get hashCode => Object.hash(runtimeType,current,total);

@override
String toString() {
  return 'EvidenceSubmissionState.uploading(current: $current, total: $total)';
}


}

/// @nodoc
abstract mixin class _$UploadingCopyWith<$Res> implements $EvidenceSubmissionStateCopyWith<$Res> {
  factory _$UploadingCopyWith(_Uploading value, $Res Function(_Uploading) _then) = __$UploadingCopyWithImpl;
@useResult
$Res call({
 int current, int total
});




}
/// @nodoc
class __$UploadingCopyWithImpl<$Res>
    implements _$UploadingCopyWith<$Res> {
  __$UploadingCopyWithImpl(this._self, this._then);

  final _Uploading _self;
  final $Res Function(_Uploading) _then;

/// Create a copy of EvidenceSubmissionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? current = null,Object? total = null,}) {
  return _then(_Uploading(
current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
