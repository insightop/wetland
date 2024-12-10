// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wetland_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$WetlandEvent {
  int get index => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int index) changeDestination,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int index)? changeDestination,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int index)? changeDestination,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_WetlandEventChangeDestination value)
        changeDestination,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_WetlandEventChangeDestination value)? changeDestination,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_WetlandEventChangeDestination value)? changeDestination,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Create a copy of WetlandEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WetlandEventCopyWith<WetlandEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WetlandEventCopyWith<$Res> {
  factory $WetlandEventCopyWith(
          WetlandEvent value, $Res Function(WetlandEvent) then) =
      _$WetlandEventCopyWithImpl<$Res, WetlandEvent>;
  @useResult
  $Res call({int index});
}

/// @nodoc
class _$WetlandEventCopyWithImpl<$Res, $Val extends WetlandEvent>
    implements $WetlandEventCopyWith<$Res> {
  _$WetlandEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WetlandEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? index = null,
  }) {
    return _then(_value.copyWith(
      index: null == index
          ? _value.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$WetlandEventChangeDestinationImplCopyWith<$Res>
    implements $WetlandEventCopyWith<$Res> {
  factory _$$WetlandEventChangeDestinationImplCopyWith(
          _$WetlandEventChangeDestinationImpl value,
          $Res Function(_$WetlandEventChangeDestinationImpl) then) =
      __$$WetlandEventChangeDestinationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int index});
}

/// @nodoc
class __$$WetlandEventChangeDestinationImplCopyWithImpl<$Res>
    extends _$WetlandEventCopyWithImpl<$Res,
        _$WetlandEventChangeDestinationImpl>
    implements _$$WetlandEventChangeDestinationImplCopyWith<$Res> {
  __$$WetlandEventChangeDestinationImplCopyWithImpl(
      _$WetlandEventChangeDestinationImpl _value,
      $Res Function(_$WetlandEventChangeDestinationImpl) _then)
      : super(_value, _then);

  /// Create a copy of WetlandEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? index = null,
  }) {
    return _then(_$WetlandEventChangeDestinationImpl(
      null == index
          ? _value.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$WetlandEventChangeDestinationImpl
    implements _WetlandEventChangeDestination {
  const _$WetlandEventChangeDestinationImpl(this.index);

  @override
  final int index;

  @override
  String toString() {
    return 'WetlandEvent.changeDestination(index: $index)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WetlandEventChangeDestinationImpl &&
            (identical(other.index, index) || other.index == index));
  }

  @override
  int get hashCode => Object.hash(runtimeType, index);

  /// Create a copy of WetlandEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WetlandEventChangeDestinationImplCopyWith<
          _$WetlandEventChangeDestinationImpl>
      get copyWith => __$$WetlandEventChangeDestinationImplCopyWithImpl<
          _$WetlandEventChangeDestinationImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int index) changeDestination,
  }) {
    return changeDestination(index);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int index)? changeDestination,
  }) {
    return changeDestination?.call(index);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int index)? changeDestination,
    required TResult orElse(),
  }) {
    if (changeDestination != null) {
      return changeDestination(index);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_WetlandEventChangeDestination value)
        changeDestination,
  }) {
    return changeDestination(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_WetlandEventChangeDestination value)? changeDestination,
  }) {
    return changeDestination?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_WetlandEventChangeDestination value)? changeDestination,
    required TResult orElse(),
  }) {
    if (changeDestination != null) {
      return changeDestination(this);
    }
    return orElse();
  }
}

abstract class _WetlandEventChangeDestination implements WetlandEvent {
  const factory _WetlandEventChangeDestination(final int index) =
      _$WetlandEventChangeDestinationImpl;

  @override
  int get index;

  /// Create a copy of WetlandEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WetlandEventChangeDestinationImplCopyWith<
          _$WetlandEventChangeDestinationImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$WetlandState {
  int get selectedDestination => throw _privateConstructorUsedError; // 当前选中的标签
  bool get isSecondaryActive => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int selectedDestination, bool isSecondaryActive)
        pageState,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int selectedDestination, bool isSecondaryActive)?
        pageState,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int selectedDestination, bool isSecondaryActive)?
        pageState,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_WetlandStatePageState value) pageState,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_WetlandStatePageState value)? pageState,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_WetlandStatePageState value)? pageState,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Create a copy of WetlandState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WetlandStateCopyWith<WetlandState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WetlandStateCopyWith<$Res> {
  factory $WetlandStateCopyWith(
          WetlandState value, $Res Function(WetlandState) then) =
      _$WetlandStateCopyWithImpl<$Res, WetlandState>;
  @useResult
  $Res call({int selectedDestination, bool isSecondaryActive});
}

/// @nodoc
class _$WetlandStateCopyWithImpl<$Res, $Val extends WetlandState>
    implements $WetlandStateCopyWith<$Res> {
  _$WetlandStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WetlandState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? selectedDestination = null,
    Object? isSecondaryActive = null,
  }) {
    return _then(_value.copyWith(
      selectedDestination: null == selectedDestination
          ? _value.selectedDestination
          : selectedDestination // ignore: cast_nullable_to_non_nullable
              as int,
      isSecondaryActive: null == isSecondaryActive
          ? _value.isSecondaryActive
          : isSecondaryActive // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$WetlandStatePageStateImplCopyWith<$Res>
    implements $WetlandStateCopyWith<$Res> {
  factory _$$WetlandStatePageStateImplCopyWith(
          _$WetlandStatePageStateImpl value,
          $Res Function(_$WetlandStatePageStateImpl) then) =
      __$$WetlandStatePageStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int selectedDestination, bool isSecondaryActive});
}

/// @nodoc
class __$$WetlandStatePageStateImplCopyWithImpl<$Res>
    extends _$WetlandStateCopyWithImpl<$Res, _$WetlandStatePageStateImpl>
    implements _$$WetlandStatePageStateImplCopyWith<$Res> {
  __$$WetlandStatePageStateImplCopyWithImpl(_$WetlandStatePageStateImpl _value,
      $Res Function(_$WetlandStatePageStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of WetlandState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? selectedDestination = null,
    Object? isSecondaryActive = null,
  }) {
    return _then(_$WetlandStatePageStateImpl(
      selectedDestination: null == selectedDestination
          ? _value.selectedDestination
          : selectedDestination // ignore: cast_nullable_to_non_nullable
              as int,
      isSecondaryActive: null == isSecondaryActive
          ? _value.isSecondaryActive
          : isSecondaryActive // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$WetlandStatePageStateImpl implements _WetlandStatePageState {
  const _$WetlandStatePageStateImpl(
      {this.selectedDestination = 0, this.isSecondaryActive = false});

  @override
  @JsonKey()
  final int selectedDestination;
// 当前选中的标签
  @override
  @JsonKey()
  final bool isSecondaryActive;

  @override
  String toString() {
    return 'WetlandState.pageState(selectedDestination: $selectedDestination, isSecondaryActive: $isSecondaryActive)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WetlandStatePageStateImpl &&
            (identical(other.selectedDestination, selectedDestination) ||
                other.selectedDestination == selectedDestination) &&
            (identical(other.isSecondaryActive, isSecondaryActive) ||
                other.isSecondaryActive == isSecondaryActive));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, selectedDestination, isSecondaryActive);

  /// Create a copy of WetlandState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WetlandStatePageStateImplCopyWith<_$WetlandStatePageStateImpl>
      get copyWith => __$$WetlandStatePageStateImplCopyWithImpl<
          _$WetlandStatePageStateImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int selectedDestination, bool isSecondaryActive)
        pageState,
  }) {
    return pageState(selectedDestination, isSecondaryActive);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int selectedDestination, bool isSecondaryActive)?
        pageState,
  }) {
    return pageState?.call(selectedDestination, isSecondaryActive);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int selectedDestination, bool isSecondaryActive)?
        pageState,
    required TResult orElse(),
  }) {
    if (pageState != null) {
      return pageState(selectedDestination, isSecondaryActive);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_WetlandStatePageState value) pageState,
  }) {
    return pageState(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_WetlandStatePageState value)? pageState,
  }) {
    return pageState?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_WetlandStatePageState value)? pageState,
    required TResult orElse(),
  }) {
    if (pageState != null) {
      return pageState(this);
    }
    return orElse();
  }
}

abstract class _WetlandStatePageState implements WetlandState {
  const factory _WetlandStatePageState(
      {final int selectedDestination,
      final bool isSecondaryActive}) = _$WetlandStatePageStateImpl;

  @override
  int get selectedDestination; // 当前选中的标签
  @override
  bool get isSecondaryActive;

  /// Create a copy of WetlandState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WetlandStatePageStateImplCopyWith<_$WetlandStatePageStateImpl>
      get copyWith => throw _privateConstructorUsedError;
}
