// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'default_billing_method.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DefaultBillingMethod {

@JsonKey(name: 'pm_brand') String? get brand;@JsonKey(name: 'pm_last4') String? get last4;@JsonKey(name: 'pm_exp_month') int? get expMonth;@JsonKey(name: 'pm_exp_year') int? get expYear;
/// Create a copy of DefaultBillingMethod
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DefaultBillingMethodCopyWith<DefaultBillingMethod> get copyWith => _$DefaultBillingMethodCopyWithImpl<DefaultBillingMethod>(this as DefaultBillingMethod, _$identity);

  /// Serializes this DefaultBillingMethod to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DefaultBillingMethod&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.last4, last4) || other.last4 == last4)&&(identical(other.expMonth, expMonth) || other.expMonth == expMonth)&&(identical(other.expYear, expYear) || other.expYear == expYear));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,brand,last4,expMonth,expYear);

@override
String toString() {
  return 'DefaultBillingMethod(brand: $brand, last4: $last4, expMonth: $expMonth, expYear: $expYear)';
}


}

/// @nodoc
abstract mixin class $DefaultBillingMethodCopyWith<$Res>  {
  factory $DefaultBillingMethodCopyWith(DefaultBillingMethod value, $Res Function(DefaultBillingMethod) _then) = _$DefaultBillingMethodCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'pm_brand') String? brand,@JsonKey(name: 'pm_last4') String? last4,@JsonKey(name: 'pm_exp_month') int? expMonth,@JsonKey(name: 'pm_exp_year') int? expYear
});




}
/// @nodoc
class _$DefaultBillingMethodCopyWithImpl<$Res>
    implements $DefaultBillingMethodCopyWith<$Res> {
  _$DefaultBillingMethodCopyWithImpl(this._self, this._then);

  final DefaultBillingMethod _self;
  final $Res Function(DefaultBillingMethod) _then;

/// Create a copy of DefaultBillingMethod
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? brand = freezed,Object? last4 = freezed,Object? expMonth = freezed,Object? expYear = freezed,}) {
  return _then(_self.copyWith(
brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String?,last4: freezed == last4 ? _self.last4 : last4 // ignore: cast_nullable_to_non_nullable
as String?,expMonth: freezed == expMonth ? _self.expMonth : expMonth // ignore: cast_nullable_to_non_nullable
as int?,expYear: freezed == expYear ? _self.expYear : expYear // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [DefaultBillingMethod].
extension DefaultBillingMethodPatterns on DefaultBillingMethod {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DefaultBillingMethod value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DefaultBillingMethod() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DefaultBillingMethod value)  $default,){
final _that = this;
switch (_that) {
case _DefaultBillingMethod():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DefaultBillingMethod value)?  $default,){
final _that = this;
switch (_that) {
case _DefaultBillingMethod() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'pm_brand')  String? brand, @JsonKey(name: 'pm_last4')  String? last4, @JsonKey(name: 'pm_exp_month')  int? expMonth, @JsonKey(name: 'pm_exp_year')  int? expYear)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DefaultBillingMethod() when $default != null:
return $default(_that.brand,_that.last4,_that.expMonth,_that.expYear);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'pm_brand')  String? brand, @JsonKey(name: 'pm_last4')  String? last4, @JsonKey(name: 'pm_exp_month')  int? expMonth, @JsonKey(name: 'pm_exp_year')  int? expYear)  $default,) {final _that = this;
switch (_that) {
case _DefaultBillingMethod():
return $default(_that.brand,_that.last4,_that.expMonth,_that.expYear);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'pm_brand')  String? brand, @JsonKey(name: 'pm_last4')  String? last4, @JsonKey(name: 'pm_exp_month')  int? expMonth, @JsonKey(name: 'pm_exp_year')  int? expYear)?  $default,) {final _that = this;
switch (_that) {
case _DefaultBillingMethod() when $default != null:
return $default(_that.brand,_that.last4,_that.expMonth,_that.expYear);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DefaultBillingMethod extends DefaultBillingMethod {
  const _DefaultBillingMethod({@JsonKey(name: 'pm_brand') this.brand, @JsonKey(name: 'pm_last4') this.last4, @JsonKey(name: 'pm_exp_month') this.expMonth, @JsonKey(name: 'pm_exp_year') this.expYear}): super._();
  factory _DefaultBillingMethod.fromJson(Map<String, dynamic> json) => _$DefaultBillingMethodFromJson(json);

@override@JsonKey(name: 'pm_brand') final  String? brand;
@override@JsonKey(name: 'pm_last4') final  String? last4;
@override@JsonKey(name: 'pm_exp_month') final  int? expMonth;
@override@JsonKey(name: 'pm_exp_year') final  int? expYear;

/// Create a copy of DefaultBillingMethod
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DefaultBillingMethodCopyWith<_DefaultBillingMethod> get copyWith => __$DefaultBillingMethodCopyWithImpl<_DefaultBillingMethod>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DefaultBillingMethodToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DefaultBillingMethod&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.last4, last4) || other.last4 == last4)&&(identical(other.expMonth, expMonth) || other.expMonth == expMonth)&&(identical(other.expYear, expYear) || other.expYear == expYear));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,brand,last4,expMonth,expYear);

@override
String toString() {
  return 'DefaultBillingMethod(brand: $brand, last4: $last4, expMonth: $expMonth, expYear: $expYear)';
}


}

/// @nodoc
abstract mixin class _$DefaultBillingMethodCopyWith<$Res> implements $DefaultBillingMethodCopyWith<$Res> {
  factory _$DefaultBillingMethodCopyWith(_DefaultBillingMethod value, $Res Function(_DefaultBillingMethod) _then) = __$DefaultBillingMethodCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'pm_brand') String? brand,@JsonKey(name: 'pm_last4') String? last4,@JsonKey(name: 'pm_exp_month') int? expMonth,@JsonKey(name: 'pm_exp_year') int? expYear
});




}
/// @nodoc
class __$DefaultBillingMethodCopyWithImpl<$Res>
    implements _$DefaultBillingMethodCopyWith<$Res> {
  __$DefaultBillingMethodCopyWithImpl(this._self, this._then);

  final _DefaultBillingMethod _self;
  final $Res Function(_DefaultBillingMethod) _then;

/// Create a copy of DefaultBillingMethod
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? brand = freezed,Object? last4 = freezed,Object? expMonth = freezed,Object? expYear = freezed,}) {
  return _then(_DefaultBillingMethod(
brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String?,last4: freezed == last4 ? _self.last4 : last4 // ignore: cast_nullable_to_non_nullable
as String?,expMonth: freezed == expMonth ? _self.expMonth : expMonth // ignore: cast_nullable_to_non_nullable
as int?,expYear: freezed == expYear ? _self.expYear : expYear // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
