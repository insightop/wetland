// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wetland_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WetlandEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is WetlandEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'WetlandEvent()';
}


}

/// @nodoc
class $WetlandEventCopyWith<$Res>  {
$WetlandEventCopyWith(WetlandEvent _, $Res Function(WetlandEvent) __);
}


/// Adds pattern-matching-related methods to [WetlandEvent].
extension WetlandEventPatterns on WetlandEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _WetlandEventSetIndex value)?  setIndex,TResult Function( _WetlandEventSetMode value)?  setMode,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WetlandEventSetIndex() when setIndex != null:
return setIndex(_that);case _WetlandEventSetMode() when setMode != null:
return setMode(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _WetlandEventSetIndex value)  setIndex,required TResult Function( _WetlandEventSetMode value)  setMode,}){
final _that = this;
switch (_that) {
case _WetlandEventSetIndex():
return setIndex(_that);case _WetlandEventSetMode():
return setMode(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _WetlandEventSetIndex value)?  setIndex,TResult? Function( _WetlandEventSetMode value)?  setMode,}){
final _that = this;
switch (_that) {
case _WetlandEventSetIndex() when setIndex != null:
return setIndex(_that);case _WetlandEventSetMode() when setMode != null:
return setMode(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int index)?  setIndex,TResult Function( WetlandMode mode)?  setMode,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WetlandEventSetIndex() when setIndex != null:
return setIndex(_that.index);case _WetlandEventSetMode() when setMode != null:
return setMode(_that.mode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int index)  setIndex,required TResult Function( WetlandMode mode)  setMode,}) {final _that = this;
switch (_that) {
case _WetlandEventSetIndex():
return setIndex(_that.index);case _WetlandEventSetMode():
return setMode(_that.mode);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int index)?  setIndex,TResult? Function( WetlandMode mode)?  setMode,}) {final _that = this;
switch (_that) {
case _WetlandEventSetIndex() when setIndex != null:
return setIndex(_that.index);case _WetlandEventSetMode() when setMode != null:
return setMode(_that.mode);case _:
  return null;

}
}

}

/// @nodoc


class _WetlandEventSetIndex implements WetlandEvent {
  const _WetlandEventSetIndex(this.index);
  

 final  int index;

/// Create a copy of WetlandEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WetlandEventSetIndexCopyWith<_WetlandEventSetIndex> get copyWith => __$WetlandEventSetIndexCopyWithImpl<_WetlandEventSetIndex>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WetlandEventSetIndex&&(identical(other.index, index) || other.index == index));
}


@override
int get hashCode {
    return Object.hash(runtimeType,index);
}

@override
String toString() {
    return 'WetlandEvent.setIndex(index: $index)';
}


}

/// @nodoc
abstract mixin class _$WetlandEventSetIndexCopyWith<$Res> implements $WetlandEventCopyWith<$Res> {
  factory _$WetlandEventSetIndexCopyWith(_WetlandEventSetIndex value, $Res Function(_WetlandEventSetIndex) _then) = __$WetlandEventSetIndexCopyWithImpl;
@useResult
$Res call({
 int index
});




}
/// @nodoc
class __$WetlandEventSetIndexCopyWithImpl<$Res>
    implements _$WetlandEventSetIndexCopyWith<$Res> {
  __$WetlandEventSetIndexCopyWithImpl(this._self, this._then);

  final _WetlandEventSetIndex _self;
  final $Res Function(_WetlandEventSetIndex) _then;

/// Create a copy of WetlandEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? index = null,}) {
  return _then(_WetlandEventSetIndex(
null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _WetlandEventSetMode implements WetlandEvent {
  const _WetlandEventSetMode(this.mode);
  

 final  WetlandMode mode;

/// Create a copy of WetlandEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WetlandEventSetModeCopyWith<_WetlandEventSetMode> get copyWith => __$WetlandEventSetModeCopyWithImpl<_WetlandEventSetMode>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WetlandEventSetMode&&(identical(other.mode, mode) || other.mode == mode));
}


@override
int get hashCode {
    return Object.hash(runtimeType,mode);
}

@override
String toString() {
    return 'WetlandEvent.setMode(mode: $mode)';
}


}

/// @nodoc
abstract mixin class _$WetlandEventSetModeCopyWith<$Res> implements $WetlandEventCopyWith<$Res> {
  factory _$WetlandEventSetModeCopyWith(_WetlandEventSetMode value, $Res Function(_WetlandEventSetMode) _then) = __$WetlandEventSetModeCopyWithImpl;
@useResult
$Res call({
 WetlandMode mode
});




}
/// @nodoc
class __$WetlandEventSetModeCopyWithImpl<$Res>
    implements _$WetlandEventSetModeCopyWith<$Res> {
  __$WetlandEventSetModeCopyWithImpl(this._self, this._then);

  final _WetlandEventSetMode _self;
  final $Res Function(_WetlandEventSetMode) _then;

/// Create a copy of WetlandEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mode = null,}) {
  return _then(_WetlandEventSetMode(
null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as WetlandMode,
  ));
}


}

/// @nodoc
mixin _$WetlandState {

 int get index; WetlandMode get mode;
/// Create a copy of WetlandState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WetlandStateCopyWith<WetlandState> get copyWith => _$WetlandStateCopyWithImpl<WetlandState>(this as WetlandState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as WetlandState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WetlandState&&(identical(other.index, _this.index) || other.index == _this.index)&&(identical(other.mode, _this.mode) || other.mode == _this.mode));
}


@override
int get hashCode {
  final _this = this as WetlandState;
  return Object.hash(runtimeType,_this.index,_this.mode);
}

@override
String toString() {
  final _this = this as WetlandState;
  return 'WetlandState(index: ${_this.index}, mode: ${_this.mode})';
}


}

/// @nodoc
abstract mixin class $WetlandStateCopyWith<$Res>  {
  factory $WetlandStateCopyWith(WetlandState value, $Res Function(WetlandState) _then) = _$WetlandStateCopyWithImpl;
@useResult
$Res call({
 int index, WetlandMode mode
});




}
/// @nodoc
class _$WetlandStateCopyWithImpl<$Res>
    implements $WetlandStateCopyWith<$Res> {
  _$WetlandStateCopyWithImpl(this._self, this._then);

  final WetlandState _self;
  final $Res Function(WetlandState) _then;

/// Create a copy of WetlandState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? mode = null,}) {
  return _then(WetlandState.pageState(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as WetlandMode,
  ));
}

}


/// Adds pattern-matching-related methods to [WetlandState].
extension WetlandStatePatterns on WetlandState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _WetlandStatePageState value)?  pageState,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WetlandStatePageState() when pageState != null:
return pageState(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _WetlandStatePageState value)  pageState,}){
final _that = this;
switch (_that) {
case _WetlandStatePageState():
return pageState(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _WetlandStatePageState value)?  pageState,}){
final _that = this;
switch (_that) {
case _WetlandStatePageState() when pageState != null:
return pageState(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int index,  WetlandMode mode)?  pageState,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WetlandStatePageState() when pageState != null:
return pageState(_that.index,_that.mode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int index,  WetlandMode mode)  pageState,}) {final _that = this;
switch (_that) {
case _WetlandStatePageState():
return pageState(_that.index,_that.mode);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int index,  WetlandMode mode)?  pageState,}) {final _that = this;
switch (_that) {
case _WetlandStatePageState() when pageState != null:
return pageState(_that.index,_that.mode);case _:
  return null;

}
}

}

/// @nodoc


class _WetlandStatePageState implements WetlandState {
  const _WetlandStatePageState({this.index = 0, this.mode = WetlandMode.dual});
  

@override@JsonKey() final  int index;
@override@JsonKey() final  WetlandMode mode;

/// Create a copy of WetlandState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WetlandStatePageStateCopyWith<_WetlandStatePageState> get copyWith => __$WetlandStatePageStateCopyWithImpl<_WetlandStatePageState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WetlandStatePageState&&(identical(other.index, index) || other.index == index)&&(identical(other.mode, mode) || other.mode == mode));
}


@override
int get hashCode {
    return Object.hash(runtimeType,index,mode);
}

@override
String toString() {
    return 'WetlandState.pageState(index: $index, mode: $mode)';
}


}

/// @nodoc
abstract mixin class _$WetlandStatePageStateCopyWith<$Res> implements $WetlandStateCopyWith<$Res> {
  factory _$WetlandStatePageStateCopyWith(_WetlandStatePageState value, $Res Function(_WetlandStatePageState) _then) = __$WetlandStatePageStateCopyWithImpl;
@override @useResult
$Res call({
 int index, WetlandMode mode
});




}
/// @nodoc
class __$WetlandStatePageStateCopyWithImpl<$Res>
    implements _$WetlandStatePageStateCopyWith<$Res> {
  __$WetlandStatePageStateCopyWithImpl(this._self, this._then);

  final _WetlandStatePageState _self;
  final $Res Function(_WetlandStatePageState) _then;

/// Create a copy of WetlandState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? mode = null,}) {
  return _then(_WetlandStatePageState(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as WetlandMode,
  ));
}


}

// dart format on
