// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PaymentSummary {

 PointSummary get points;@JsonKey(name: 'trial_points') TrialPointSummary? get trialPoints;@JsonKey(name: 'obligations_remaining') int get obligationsRemaining; RewardSummary? get rewards;@JsonKey(name: 'recent_payout') RecentPayout? get recentPayout;@JsonKey(name: 'total_earned_minor') int get totalEarnedMinor;@JsonKey(name: 'total_earned_currency') String? get totalEarnedCurrency;@JsonKey(name: 'next_payout_date') String get nextPayoutDate;
/// Create a copy of PaymentSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentSummaryCopyWith<PaymentSummary> get copyWith => _$PaymentSummaryCopyWithImpl<PaymentSummary>(this as PaymentSummary, _$identity);

  /// Serializes this PaymentSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentSummary&&(identical(other.points, points) || other.points == points)&&(identical(other.trialPoints, trialPoints) || other.trialPoints == trialPoints)&&(identical(other.obligationsRemaining, obligationsRemaining) || other.obligationsRemaining == obligationsRemaining)&&(identical(other.rewards, rewards) || other.rewards == rewards)&&(identical(other.recentPayout, recentPayout) || other.recentPayout == recentPayout)&&(identical(other.totalEarnedMinor, totalEarnedMinor) || other.totalEarnedMinor == totalEarnedMinor)&&(identical(other.totalEarnedCurrency, totalEarnedCurrency) || other.totalEarnedCurrency == totalEarnedCurrency)&&(identical(other.nextPayoutDate, nextPayoutDate) || other.nextPayoutDate == nextPayoutDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,points,trialPoints,obligationsRemaining,rewards,recentPayout,totalEarnedMinor,totalEarnedCurrency,nextPayoutDate);

@override
String toString() {
  return 'PaymentSummary(points: $points, trialPoints: $trialPoints, obligationsRemaining: $obligationsRemaining, rewards: $rewards, recentPayout: $recentPayout, totalEarnedMinor: $totalEarnedMinor, totalEarnedCurrency: $totalEarnedCurrency, nextPayoutDate: $nextPayoutDate)';
}


}

/// @nodoc
abstract mixin class $PaymentSummaryCopyWith<$Res>  {
  factory $PaymentSummaryCopyWith(PaymentSummary value, $Res Function(PaymentSummary) _then) = _$PaymentSummaryCopyWithImpl;
@useResult
$Res call({
 PointSummary points,@JsonKey(name: 'trial_points') TrialPointSummary? trialPoints,@JsonKey(name: 'obligations_remaining') int obligationsRemaining, RewardSummary? rewards,@JsonKey(name: 'recent_payout') RecentPayout? recentPayout,@JsonKey(name: 'total_earned_minor') int totalEarnedMinor,@JsonKey(name: 'total_earned_currency') String? totalEarnedCurrency,@JsonKey(name: 'next_payout_date') String nextPayoutDate
});


$PointSummaryCopyWith<$Res> get points;$TrialPointSummaryCopyWith<$Res>? get trialPoints;$RewardSummaryCopyWith<$Res>? get rewards;$RecentPayoutCopyWith<$Res>? get recentPayout;

}
/// @nodoc
class _$PaymentSummaryCopyWithImpl<$Res>
    implements $PaymentSummaryCopyWith<$Res> {
  _$PaymentSummaryCopyWithImpl(this._self, this._then);

  final PaymentSummary _self;
  final $Res Function(PaymentSummary) _then;

/// Create a copy of PaymentSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? points = null,Object? trialPoints = freezed,Object? obligationsRemaining = null,Object? rewards = freezed,Object? recentPayout = freezed,Object? totalEarnedMinor = null,Object? totalEarnedCurrency = freezed,Object? nextPayoutDate = null,}) {
  return _then(_self.copyWith(
points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as PointSummary,trialPoints: freezed == trialPoints ? _self.trialPoints : trialPoints // ignore: cast_nullable_to_non_nullable
as TrialPointSummary?,obligationsRemaining: null == obligationsRemaining ? _self.obligationsRemaining : obligationsRemaining // ignore: cast_nullable_to_non_nullable
as int,rewards: freezed == rewards ? _self.rewards : rewards // ignore: cast_nullable_to_non_nullable
as RewardSummary?,recentPayout: freezed == recentPayout ? _self.recentPayout : recentPayout // ignore: cast_nullable_to_non_nullable
as RecentPayout?,totalEarnedMinor: null == totalEarnedMinor ? _self.totalEarnedMinor : totalEarnedMinor // ignore: cast_nullable_to_non_nullable
as int,totalEarnedCurrency: freezed == totalEarnedCurrency ? _self.totalEarnedCurrency : totalEarnedCurrency // ignore: cast_nullable_to_non_nullable
as String?,nextPayoutDate: null == nextPayoutDate ? _self.nextPayoutDate : nextPayoutDate // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of PaymentSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PointSummaryCopyWith<$Res> get points {
  
  return $PointSummaryCopyWith<$Res>(_self.points, (value) {
    return _then(_self.copyWith(points: value));
  });
}/// Create a copy of PaymentSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TrialPointSummaryCopyWith<$Res>? get trialPoints {
    if (_self.trialPoints == null) {
    return null;
  }

  return $TrialPointSummaryCopyWith<$Res>(_self.trialPoints!, (value) {
    return _then(_self.copyWith(trialPoints: value));
  });
}/// Create a copy of PaymentSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RewardSummaryCopyWith<$Res>? get rewards {
    if (_self.rewards == null) {
    return null;
  }

  return $RewardSummaryCopyWith<$Res>(_self.rewards!, (value) {
    return _then(_self.copyWith(rewards: value));
  });
}/// Create a copy of PaymentSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RecentPayoutCopyWith<$Res>? get recentPayout {
    if (_self.recentPayout == null) {
    return null;
  }

  return $RecentPayoutCopyWith<$Res>(_self.recentPayout!, (value) {
    return _then(_self.copyWith(recentPayout: value));
  });
}
}


/// Adds pattern-matching-related methods to [PaymentSummary].
extension PaymentSummaryPatterns on PaymentSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentSummary value)  $default,){
final _that = this;
switch (_that) {
case _PaymentSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentSummary value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PointSummary points, @JsonKey(name: 'trial_points')  TrialPointSummary? trialPoints, @JsonKey(name: 'obligations_remaining')  int obligationsRemaining,  RewardSummary? rewards, @JsonKey(name: 'recent_payout')  RecentPayout? recentPayout, @JsonKey(name: 'total_earned_minor')  int totalEarnedMinor, @JsonKey(name: 'total_earned_currency')  String? totalEarnedCurrency, @JsonKey(name: 'next_payout_date')  String nextPayoutDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentSummary() when $default != null:
return $default(_that.points,_that.trialPoints,_that.obligationsRemaining,_that.rewards,_that.recentPayout,_that.totalEarnedMinor,_that.totalEarnedCurrency,_that.nextPayoutDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PointSummary points, @JsonKey(name: 'trial_points')  TrialPointSummary? trialPoints, @JsonKey(name: 'obligations_remaining')  int obligationsRemaining,  RewardSummary? rewards, @JsonKey(name: 'recent_payout')  RecentPayout? recentPayout, @JsonKey(name: 'total_earned_minor')  int totalEarnedMinor, @JsonKey(name: 'total_earned_currency')  String? totalEarnedCurrency, @JsonKey(name: 'next_payout_date')  String nextPayoutDate)  $default,) {final _that = this;
switch (_that) {
case _PaymentSummary():
return $default(_that.points,_that.trialPoints,_that.obligationsRemaining,_that.rewards,_that.recentPayout,_that.totalEarnedMinor,_that.totalEarnedCurrency,_that.nextPayoutDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PointSummary points, @JsonKey(name: 'trial_points')  TrialPointSummary? trialPoints, @JsonKey(name: 'obligations_remaining')  int obligationsRemaining,  RewardSummary? rewards, @JsonKey(name: 'recent_payout')  RecentPayout? recentPayout, @JsonKey(name: 'total_earned_minor')  int totalEarnedMinor, @JsonKey(name: 'total_earned_currency')  String? totalEarnedCurrency, @JsonKey(name: 'next_payout_date')  String nextPayoutDate)?  $default,) {final _that = this;
switch (_that) {
case _PaymentSummary() when $default != null:
return $default(_that.points,_that.trialPoints,_that.obligationsRemaining,_that.rewards,_that.recentPayout,_that.totalEarnedMinor,_that.totalEarnedCurrency,_that.nextPayoutDate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaymentSummary implements PaymentSummary {
  const _PaymentSummary({required this.points, @JsonKey(name: 'trial_points') this.trialPoints, @JsonKey(name: 'obligations_remaining') required this.obligationsRemaining, this.rewards, @JsonKey(name: 'recent_payout') this.recentPayout, @JsonKey(name: 'total_earned_minor') required this.totalEarnedMinor, @JsonKey(name: 'total_earned_currency') this.totalEarnedCurrency, @JsonKey(name: 'next_payout_date') required this.nextPayoutDate});
  factory _PaymentSummary.fromJson(Map<String, dynamic> json) => _$PaymentSummaryFromJson(json);

@override final  PointSummary points;
@override@JsonKey(name: 'trial_points') final  TrialPointSummary? trialPoints;
@override@JsonKey(name: 'obligations_remaining') final  int obligationsRemaining;
@override final  RewardSummary? rewards;
@override@JsonKey(name: 'recent_payout') final  RecentPayout? recentPayout;
@override@JsonKey(name: 'total_earned_minor') final  int totalEarnedMinor;
@override@JsonKey(name: 'total_earned_currency') final  String? totalEarnedCurrency;
@override@JsonKey(name: 'next_payout_date') final  String nextPayoutDate;

/// Create a copy of PaymentSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentSummaryCopyWith<_PaymentSummary> get copyWith => __$PaymentSummaryCopyWithImpl<_PaymentSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentSummary&&(identical(other.points, points) || other.points == points)&&(identical(other.trialPoints, trialPoints) || other.trialPoints == trialPoints)&&(identical(other.obligationsRemaining, obligationsRemaining) || other.obligationsRemaining == obligationsRemaining)&&(identical(other.rewards, rewards) || other.rewards == rewards)&&(identical(other.recentPayout, recentPayout) || other.recentPayout == recentPayout)&&(identical(other.totalEarnedMinor, totalEarnedMinor) || other.totalEarnedMinor == totalEarnedMinor)&&(identical(other.totalEarnedCurrency, totalEarnedCurrency) || other.totalEarnedCurrency == totalEarnedCurrency)&&(identical(other.nextPayoutDate, nextPayoutDate) || other.nextPayoutDate == nextPayoutDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,points,trialPoints,obligationsRemaining,rewards,recentPayout,totalEarnedMinor,totalEarnedCurrency,nextPayoutDate);

@override
String toString() {
  return 'PaymentSummary(points: $points, trialPoints: $trialPoints, obligationsRemaining: $obligationsRemaining, rewards: $rewards, recentPayout: $recentPayout, totalEarnedMinor: $totalEarnedMinor, totalEarnedCurrency: $totalEarnedCurrency, nextPayoutDate: $nextPayoutDate)';
}


}

/// @nodoc
abstract mixin class _$PaymentSummaryCopyWith<$Res> implements $PaymentSummaryCopyWith<$Res> {
  factory _$PaymentSummaryCopyWith(_PaymentSummary value, $Res Function(_PaymentSummary) _then) = __$PaymentSummaryCopyWithImpl;
@override @useResult
$Res call({
 PointSummary points,@JsonKey(name: 'trial_points') TrialPointSummary? trialPoints,@JsonKey(name: 'obligations_remaining') int obligationsRemaining, RewardSummary? rewards,@JsonKey(name: 'recent_payout') RecentPayout? recentPayout,@JsonKey(name: 'total_earned_minor') int totalEarnedMinor,@JsonKey(name: 'total_earned_currency') String? totalEarnedCurrency,@JsonKey(name: 'next_payout_date') String nextPayoutDate
});


@override $PointSummaryCopyWith<$Res> get points;@override $TrialPointSummaryCopyWith<$Res>? get trialPoints;@override $RewardSummaryCopyWith<$Res>? get rewards;@override $RecentPayoutCopyWith<$Res>? get recentPayout;

}
/// @nodoc
class __$PaymentSummaryCopyWithImpl<$Res>
    implements _$PaymentSummaryCopyWith<$Res> {
  __$PaymentSummaryCopyWithImpl(this._self, this._then);

  final _PaymentSummary _self;
  final $Res Function(_PaymentSummary) _then;

/// Create a copy of PaymentSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? points = null,Object? trialPoints = freezed,Object? obligationsRemaining = null,Object? rewards = freezed,Object? recentPayout = freezed,Object? totalEarnedMinor = null,Object? totalEarnedCurrency = freezed,Object? nextPayoutDate = null,}) {
  return _then(_PaymentSummary(
points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as PointSummary,trialPoints: freezed == trialPoints ? _self.trialPoints : trialPoints // ignore: cast_nullable_to_non_nullable
as TrialPointSummary?,obligationsRemaining: null == obligationsRemaining ? _self.obligationsRemaining : obligationsRemaining // ignore: cast_nullable_to_non_nullable
as int,rewards: freezed == rewards ? _self.rewards : rewards // ignore: cast_nullable_to_non_nullable
as RewardSummary?,recentPayout: freezed == recentPayout ? _self.recentPayout : recentPayout // ignore: cast_nullable_to_non_nullable
as RecentPayout?,totalEarnedMinor: null == totalEarnedMinor ? _self.totalEarnedMinor : totalEarnedMinor // ignore: cast_nullable_to_non_nullable
as int,totalEarnedCurrency: freezed == totalEarnedCurrency ? _self.totalEarnedCurrency : totalEarnedCurrency // ignore: cast_nullable_to_non_nullable
as String?,nextPayoutDate: null == nextPayoutDate ? _self.nextPayoutDate : nextPayoutDate // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of PaymentSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PointSummaryCopyWith<$Res> get points {
  
  return $PointSummaryCopyWith<$Res>(_self.points, (value) {
    return _then(_self.copyWith(points: value));
  });
}/// Create a copy of PaymentSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TrialPointSummaryCopyWith<$Res>? get trialPoints {
    if (_self.trialPoints == null) {
    return null;
  }

  return $TrialPointSummaryCopyWith<$Res>(_self.trialPoints!, (value) {
    return _then(_self.copyWith(trialPoints: value));
  });
}/// Create a copy of PaymentSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RewardSummaryCopyWith<$Res>? get rewards {
    if (_self.rewards == null) {
    return null;
  }

  return $RewardSummaryCopyWith<$Res>(_self.rewards!, (value) {
    return _then(_self.copyWith(rewards: value));
  });
}/// Create a copy of PaymentSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RecentPayoutCopyWith<$Res>? get recentPayout {
    if (_self.recentPayout == null) {
    return null;
  }

  return $RecentPayoutCopyWith<$Res>(_self.recentPayout!, (value) {
    return _then(_self.copyWith(recentPayout: value));
  });
}
}


/// @nodoc
mixin _$PointSummary {

 int get balance; int get locked; int get available;
/// Create a copy of PointSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PointSummaryCopyWith<PointSummary> get copyWith => _$PointSummaryCopyWithImpl<PointSummary>(this as PointSummary, _$identity);

  /// Serializes this PointSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PointSummary&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.locked, locked) || other.locked == locked)&&(identical(other.available, available) || other.available == available));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,balance,locked,available);

@override
String toString() {
  return 'PointSummary(balance: $balance, locked: $locked, available: $available)';
}


}

/// @nodoc
abstract mixin class $PointSummaryCopyWith<$Res>  {
  factory $PointSummaryCopyWith(PointSummary value, $Res Function(PointSummary) _then) = _$PointSummaryCopyWithImpl;
@useResult
$Res call({
 int balance, int locked, int available
});




}
/// @nodoc
class _$PointSummaryCopyWithImpl<$Res>
    implements $PointSummaryCopyWith<$Res> {
  _$PointSummaryCopyWithImpl(this._self, this._then);

  final PointSummary _self;
  final $Res Function(PointSummary) _then;

/// Create a copy of PointSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? balance = null,Object? locked = null,Object? available = null,}) {
  return _then(_self.copyWith(
balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as int,locked: null == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as int,available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PointSummary].
extension PointSummaryPatterns on PointSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PointSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PointSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PointSummary value)  $default,){
final _that = this;
switch (_that) {
case _PointSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PointSummary value)?  $default,){
final _that = this;
switch (_that) {
case _PointSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int balance,  int locked,  int available)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PointSummary() when $default != null:
return $default(_that.balance,_that.locked,_that.available);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int balance,  int locked,  int available)  $default,) {final _that = this;
switch (_that) {
case _PointSummary():
return $default(_that.balance,_that.locked,_that.available);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int balance,  int locked,  int available)?  $default,) {final _that = this;
switch (_that) {
case _PointSummary() when $default != null:
return $default(_that.balance,_that.locked,_that.available);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PointSummary implements PointSummary {
  const _PointSummary({required this.balance, required this.locked, required this.available});
  factory _PointSummary.fromJson(Map<String, dynamic> json) => _$PointSummaryFromJson(json);

@override final  int balance;
@override final  int locked;
@override final  int available;

/// Create a copy of PointSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PointSummaryCopyWith<_PointSummary> get copyWith => __$PointSummaryCopyWithImpl<_PointSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PointSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PointSummary&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.locked, locked) || other.locked == locked)&&(identical(other.available, available) || other.available == available));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,balance,locked,available);

@override
String toString() {
  return 'PointSummary(balance: $balance, locked: $locked, available: $available)';
}


}

/// @nodoc
abstract mixin class _$PointSummaryCopyWith<$Res> implements $PointSummaryCopyWith<$Res> {
  factory _$PointSummaryCopyWith(_PointSummary value, $Res Function(_PointSummary) _then) = __$PointSummaryCopyWithImpl;
@override @useResult
$Res call({
 int balance, int locked, int available
});




}
/// @nodoc
class __$PointSummaryCopyWithImpl<$Res>
    implements _$PointSummaryCopyWith<$Res> {
  __$PointSummaryCopyWithImpl(this._self, this._then);

  final _PointSummary _self;
  final $Res Function(_PointSummary) _then;

/// Create a copy of PointSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? balance = null,Object? locked = null,Object? available = null,}) {
  return _then(_PointSummary(
balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as int,locked: null == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as int,available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$TrialPointSummary {

 int get balance; int get locked; int get available;
/// Create a copy of TrialPointSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrialPointSummaryCopyWith<TrialPointSummary> get copyWith => _$TrialPointSummaryCopyWithImpl<TrialPointSummary>(this as TrialPointSummary, _$identity);

  /// Serializes this TrialPointSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrialPointSummary&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.locked, locked) || other.locked == locked)&&(identical(other.available, available) || other.available == available));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,balance,locked,available);

@override
String toString() {
  return 'TrialPointSummary(balance: $balance, locked: $locked, available: $available)';
}


}

/// @nodoc
abstract mixin class $TrialPointSummaryCopyWith<$Res>  {
  factory $TrialPointSummaryCopyWith(TrialPointSummary value, $Res Function(TrialPointSummary) _then) = _$TrialPointSummaryCopyWithImpl;
@useResult
$Res call({
 int balance, int locked, int available
});




}
/// @nodoc
class _$TrialPointSummaryCopyWithImpl<$Res>
    implements $TrialPointSummaryCopyWith<$Res> {
  _$TrialPointSummaryCopyWithImpl(this._self, this._then);

  final TrialPointSummary _self;
  final $Res Function(TrialPointSummary) _then;

/// Create a copy of TrialPointSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? balance = null,Object? locked = null,Object? available = null,}) {
  return _then(_self.copyWith(
balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as int,locked: null == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as int,available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TrialPointSummary].
extension TrialPointSummaryPatterns on TrialPointSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrialPointSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrialPointSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrialPointSummary value)  $default,){
final _that = this;
switch (_that) {
case _TrialPointSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrialPointSummary value)?  $default,){
final _that = this;
switch (_that) {
case _TrialPointSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int balance,  int locked,  int available)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrialPointSummary() when $default != null:
return $default(_that.balance,_that.locked,_that.available);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int balance,  int locked,  int available)  $default,) {final _that = this;
switch (_that) {
case _TrialPointSummary():
return $default(_that.balance,_that.locked,_that.available);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int balance,  int locked,  int available)?  $default,) {final _that = this;
switch (_that) {
case _TrialPointSummary() when $default != null:
return $default(_that.balance,_that.locked,_that.available);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TrialPointSummary implements TrialPointSummary {
  const _TrialPointSummary({required this.balance, required this.locked, required this.available});
  factory _TrialPointSummary.fromJson(Map<String, dynamic> json) => _$TrialPointSummaryFromJson(json);

@override final  int balance;
@override final  int locked;
@override final  int available;

/// Create a copy of TrialPointSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrialPointSummaryCopyWith<_TrialPointSummary> get copyWith => __$TrialPointSummaryCopyWithImpl<_TrialPointSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrialPointSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrialPointSummary&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.locked, locked) || other.locked == locked)&&(identical(other.available, available) || other.available == available));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,balance,locked,available);

@override
String toString() {
  return 'TrialPointSummary(balance: $balance, locked: $locked, available: $available)';
}


}

/// @nodoc
abstract mixin class _$TrialPointSummaryCopyWith<$Res> implements $TrialPointSummaryCopyWith<$Res> {
  factory _$TrialPointSummaryCopyWith(_TrialPointSummary value, $Res Function(_TrialPointSummary) _then) = __$TrialPointSummaryCopyWithImpl;
@override @useResult
$Res call({
 int balance, int locked, int available
});




}
/// @nodoc
class __$TrialPointSummaryCopyWithImpl<$Res>
    implements _$TrialPointSummaryCopyWith<$Res> {
  __$TrialPointSummaryCopyWithImpl(this._self, this._then);

  final _TrialPointSummary _self;
  final $Res Function(_TrialPointSummary) _then;

/// Create a copy of TrialPointSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? balance = null,Object? locked = null,Object? available = null,}) {
  return _then(_TrialPointSummary(
balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as int,locked: null == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as int,available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$RewardSummary {

 int get balance;@JsonKey(name: 'currency_code') String get currencyCode;@JsonKey(name: 'currency_exponent') int get currencyExponent;@JsonKey(name: 'amount_minor') int get amountMinor;@JsonKey(name: 'rate_per_point') int get ratePerPoint;
/// Create a copy of RewardSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RewardSummaryCopyWith<RewardSummary> get copyWith => _$RewardSummaryCopyWithImpl<RewardSummary>(this as RewardSummary, _$identity);

  /// Serializes this RewardSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RewardSummary&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.currencyExponent, currencyExponent) || other.currencyExponent == currencyExponent)&&(identical(other.amountMinor, amountMinor) || other.amountMinor == amountMinor)&&(identical(other.ratePerPoint, ratePerPoint) || other.ratePerPoint == ratePerPoint));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,balance,currencyCode,currencyExponent,amountMinor,ratePerPoint);

@override
String toString() {
  return 'RewardSummary(balance: $balance, currencyCode: $currencyCode, currencyExponent: $currencyExponent, amountMinor: $amountMinor, ratePerPoint: $ratePerPoint)';
}


}

/// @nodoc
abstract mixin class $RewardSummaryCopyWith<$Res>  {
  factory $RewardSummaryCopyWith(RewardSummary value, $Res Function(RewardSummary) _then) = _$RewardSummaryCopyWithImpl;
@useResult
$Res call({
 int balance,@JsonKey(name: 'currency_code') String currencyCode,@JsonKey(name: 'currency_exponent') int currencyExponent,@JsonKey(name: 'amount_minor') int amountMinor,@JsonKey(name: 'rate_per_point') int ratePerPoint
});




}
/// @nodoc
class _$RewardSummaryCopyWithImpl<$Res>
    implements $RewardSummaryCopyWith<$Res> {
  _$RewardSummaryCopyWithImpl(this._self, this._then);

  final RewardSummary _self;
  final $Res Function(RewardSummary) _then;

/// Create a copy of RewardSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? balance = null,Object? currencyCode = null,Object? currencyExponent = null,Object? amountMinor = null,Object? ratePerPoint = null,}) {
  return _then(_self.copyWith(
balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as int,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,currencyExponent: null == currencyExponent ? _self.currencyExponent : currencyExponent // ignore: cast_nullable_to_non_nullable
as int,amountMinor: null == amountMinor ? _self.amountMinor : amountMinor // ignore: cast_nullable_to_non_nullable
as int,ratePerPoint: null == ratePerPoint ? _self.ratePerPoint : ratePerPoint // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RewardSummary].
extension RewardSummaryPatterns on RewardSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RewardSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RewardSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RewardSummary value)  $default,){
final _that = this;
switch (_that) {
case _RewardSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RewardSummary value)?  $default,){
final _that = this;
switch (_that) {
case _RewardSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int balance, @JsonKey(name: 'currency_code')  String currencyCode, @JsonKey(name: 'currency_exponent')  int currencyExponent, @JsonKey(name: 'amount_minor')  int amountMinor, @JsonKey(name: 'rate_per_point')  int ratePerPoint)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RewardSummary() when $default != null:
return $default(_that.balance,_that.currencyCode,_that.currencyExponent,_that.amountMinor,_that.ratePerPoint);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int balance, @JsonKey(name: 'currency_code')  String currencyCode, @JsonKey(name: 'currency_exponent')  int currencyExponent, @JsonKey(name: 'amount_minor')  int amountMinor, @JsonKey(name: 'rate_per_point')  int ratePerPoint)  $default,) {final _that = this;
switch (_that) {
case _RewardSummary():
return $default(_that.balance,_that.currencyCode,_that.currencyExponent,_that.amountMinor,_that.ratePerPoint);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int balance, @JsonKey(name: 'currency_code')  String currencyCode, @JsonKey(name: 'currency_exponent')  int currencyExponent, @JsonKey(name: 'amount_minor')  int amountMinor, @JsonKey(name: 'rate_per_point')  int ratePerPoint)?  $default,) {final _that = this;
switch (_that) {
case _RewardSummary() when $default != null:
return $default(_that.balance,_that.currencyCode,_that.currencyExponent,_that.amountMinor,_that.ratePerPoint);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RewardSummary implements RewardSummary {
  const _RewardSummary({required this.balance, @JsonKey(name: 'currency_code') required this.currencyCode, @JsonKey(name: 'currency_exponent') required this.currencyExponent, @JsonKey(name: 'amount_minor') required this.amountMinor, @JsonKey(name: 'rate_per_point') required this.ratePerPoint});
  factory _RewardSummary.fromJson(Map<String, dynamic> json) => _$RewardSummaryFromJson(json);

@override final  int balance;
@override@JsonKey(name: 'currency_code') final  String currencyCode;
@override@JsonKey(name: 'currency_exponent') final  int currencyExponent;
@override@JsonKey(name: 'amount_minor') final  int amountMinor;
@override@JsonKey(name: 'rate_per_point') final  int ratePerPoint;

/// Create a copy of RewardSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RewardSummaryCopyWith<_RewardSummary> get copyWith => __$RewardSummaryCopyWithImpl<_RewardSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RewardSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RewardSummary&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.currencyExponent, currencyExponent) || other.currencyExponent == currencyExponent)&&(identical(other.amountMinor, amountMinor) || other.amountMinor == amountMinor)&&(identical(other.ratePerPoint, ratePerPoint) || other.ratePerPoint == ratePerPoint));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,balance,currencyCode,currencyExponent,amountMinor,ratePerPoint);

@override
String toString() {
  return 'RewardSummary(balance: $balance, currencyCode: $currencyCode, currencyExponent: $currencyExponent, amountMinor: $amountMinor, ratePerPoint: $ratePerPoint)';
}


}

/// @nodoc
abstract mixin class _$RewardSummaryCopyWith<$Res> implements $RewardSummaryCopyWith<$Res> {
  factory _$RewardSummaryCopyWith(_RewardSummary value, $Res Function(_RewardSummary) _then) = __$RewardSummaryCopyWithImpl;
@override @useResult
$Res call({
 int balance,@JsonKey(name: 'currency_code') String currencyCode,@JsonKey(name: 'currency_exponent') int currencyExponent,@JsonKey(name: 'amount_minor') int amountMinor,@JsonKey(name: 'rate_per_point') int ratePerPoint
});




}
/// @nodoc
class __$RewardSummaryCopyWithImpl<$Res>
    implements _$RewardSummaryCopyWith<$Res> {
  __$RewardSummaryCopyWithImpl(this._self, this._then);

  final _RewardSummary _self;
  final $Res Function(_RewardSummary) _then;

/// Create a copy of RewardSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? balance = null,Object? currencyCode = null,Object? currencyExponent = null,Object? amountMinor = null,Object? ratePerPoint = null,}) {
  return _then(_RewardSummary(
balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as int,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,currencyExponent: null == currencyExponent ? _self.currencyExponent : currencyExponent // ignore: cast_nullable_to_non_nullable
as int,amountMinor: null == amountMinor ? _self.amountMinor : amountMinor // ignore: cast_nullable_to_non_nullable
as int,ratePerPoint: null == ratePerPoint ? _self.ratePerPoint : ratePerPoint // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$RecentPayout {

@JsonKey(name: 'amount_minor') int get amountMinor;@JsonKey(name: 'currency_code') String get currencyCode;@JsonKey(name: 'currency_exponent') int get currencyExponent; String get status;@JsonKey(name: 'batch_date') String get batchDate;
/// Create a copy of RecentPayout
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecentPayoutCopyWith<RecentPayout> get copyWith => _$RecentPayoutCopyWithImpl<RecentPayout>(this as RecentPayout, _$identity);

  /// Serializes this RecentPayout to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecentPayout&&(identical(other.amountMinor, amountMinor) || other.amountMinor == amountMinor)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.currencyExponent, currencyExponent) || other.currencyExponent == currencyExponent)&&(identical(other.status, status) || other.status == status)&&(identical(other.batchDate, batchDate) || other.batchDate == batchDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,amountMinor,currencyCode,currencyExponent,status,batchDate);

@override
String toString() {
  return 'RecentPayout(amountMinor: $amountMinor, currencyCode: $currencyCode, currencyExponent: $currencyExponent, status: $status, batchDate: $batchDate)';
}


}

/// @nodoc
abstract mixin class $RecentPayoutCopyWith<$Res>  {
  factory $RecentPayoutCopyWith(RecentPayout value, $Res Function(RecentPayout) _then) = _$RecentPayoutCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'amount_minor') int amountMinor,@JsonKey(name: 'currency_code') String currencyCode,@JsonKey(name: 'currency_exponent') int currencyExponent, String status,@JsonKey(name: 'batch_date') String batchDate
});




}
/// @nodoc
class _$RecentPayoutCopyWithImpl<$Res>
    implements $RecentPayoutCopyWith<$Res> {
  _$RecentPayoutCopyWithImpl(this._self, this._then);

  final RecentPayout _self;
  final $Res Function(RecentPayout) _then;

/// Create a copy of RecentPayout
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? amountMinor = null,Object? currencyCode = null,Object? currencyExponent = null,Object? status = null,Object? batchDate = null,}) {
  return _then(_self.copyWith(
amountMinor: null == amountMinor ? _self.amountMinor : amountMinor // ignore: cast_nullable_to_non_nullable
as int,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,currencyExponent: null == currencyExponent ? _self.currencyExponent : currencyExponent // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,batchDate: null == batchDate ? _self.batchDate : batchDate // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RecentPayout].
extension RecentPayoutPatterns on RecentPayout {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RecentPayout value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RecentPayout() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RecentPayout value)  $default,){
final _that = this;
switch (_that) {
case _RecentPayout():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RecentPayout value)?  $default,){
final _that = this;
switch (_that) {
case _RecentPayout() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'amount_minor')  int amountMinor, @JsonKey(name: 'currency_code')  String currencyCode, @JsonKey(name: 'currency_exponent')  int currencyExponent,  String status, @JsonKey(name: 'batch_date')  String batchDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RecentPayout() when $default != null:
return $default(_that.amountMinor,_that.currencyCode,_that.currencyExponent,_that.status,_that.batchDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'amount_minor')  int amountMinor, @JsonKey(name: 'currency_code')  String currencyCode, @JsonKey(name: 'currency_exponent')  int currencyExponent,  String status, @JsonKey(name: 'batch_date')  String batchDate)  $default,) {final _that = this;
switch (_that) {
case _RecentPayout():
return $default(_that.amountMinor,_that.currencyCode,_that.currencyExponent,_that.status,_that.batchDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'amount_minor')  int amountMinor, @JsonKey(name: 'currency_code')  String currencyCode, @JsonKey(name: 'currency_exponent')  int currencyExponent,  String status, @JsonKey(name: 'batch_date')  String batchDate)?  $default,) {final _that = this;
switch (_that) {
case _RecentPayout() when $default != null:
return $default(_that.amountMinor,_that.currencyCode,_that.currencyExponent,_that.status,_that.batchDate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RecentPayout implements RecentPayout {
  const _RecentPayout({@JsonKey(name: 'amount_minor') required this.amountMinor, @JsonKey(name: 'currency_code') required this.currencyCode, @JsonKey(name: 'currency_exponent') required this.currencyExponent, required this.status, @JsonKey(name: 'batch_date') required this.batchDate});
  factory _RecentPayout.fromJson(Map<String, dynamic> json) => _$RecentPayoutFromJson(json);

@override@JsonKey(name: 'amount_minor') final  int amountMinor;
@override@JsonKey(name: 'currency_code') final  String currencyCode;
@override@JsonKey(name: 'currency_exponent') final  int currencyExponent;
@override final  String status;
@override@JsonKey(name: 'batch_date') final  String batchDate;

/// Create a copy of RecentPayout
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecentPayoutCopyWith<_RecentPayout> get copyWith => __$RecentPayoutCopyWithImpl<_RecentPayout>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RecentPayoutToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecentPayout&&(identical(other.amountMinor, amountMinor) || other.amountMinor == amountMinor)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.currencyExponent, currencyExponent) || other.currencyExponent == currencyExponent)&&(identical(other.status, status) || other.status == status)&&(identical(other.batchDate, batchDate) || other.batchDate == batchDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,amountMinor,currencyCode,currencyExponent,status,batchDate);

@override
String toString() {
  return 'RecentPayout(amountMinor: $amountMinor, currencyCode: $currencyCode, currencyExponent: $currencyExponent, status: $status, batchDate: $batchDate)';
}


}

/// @nodoc
abstract mixin class _$RecentPayoutCopyWith<$Res> implements $RecentPayoutCopyWith<$Res> {
  factory _$RecentPayoutCopyWith(_RecentPayout value, $Res Function(_RecentPayout) _then) = __$RecentPayoutCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'amount_minor') int amountMinor,@JsonKey(name: 'currency_code') String currencyCode,@JsonKey(name: 'currency_exponent') int currencyExponent, String status,@JsonKey(name: 'batch_date') String batchDate
});




}
/// @nodoc
class __$RecentPayoutCopyWithImpl<$Res>
    implements _$RecentPayoutCopyWith<$Res> {
  __$RecentPayoutCopyWithImpl(this._self, this._then);

  final _RecentPayout _self;
  final $Res Function(_RecentPayout) _then;

/// Create a copy of RecentPayout
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? amountMinor = null,Object? currencyCode = null,Object? currencyExponent = null,Object? status = null,Object? batchDate = null,}) {
  return _then(_RecentPayout(
amountMinor: null == amountMinor ? _self.amountMinor : amountMinor // ignore: cast_nullable_to_non_nullable
as int,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,currencyExponent: null == currencyExponent ? _self.currencyExponent : currencyExponent // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,batchDate: null == batchDate ? _self.batchDate : batchDate // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
