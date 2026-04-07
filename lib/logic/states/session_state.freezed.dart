// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$SessionPhase {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(
            int breathIndex, bool isInhaling, Duration currentBreathDuration)
        breathing,
    required TResult Function(Duration elapsed) retention,
    required TResult Function(Duration remaining) recovery,
    required TResult Function() finished,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(
            int breathIndex, bool isInhaling, Duration currentBreathDuration)?
        breathing,
    TResult? Function(Duration elapsed)? retention,
    TResult? Function(Duration remaining)? recovery,
    TResult? Function()? finished,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(
            int breathIndex, bool isInhaling, Duration currentBreathDuration)?
        breathing,
    TResult Function(Duration elapsed)? retention,
    TResult Function(Duration remaining)? recovery,
    TResult Function()? finished,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Idle value) idle,
    required TResult Function(_Breathing value) breathing,
    required TResult Function(_Retention value) retention,
    required TResult Function(_Recovery value) recovery,
    required TResult Function(_Finished value) finished,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Idle value)? idle,
    TResult? Function(_Breathing value)? breathing,
    TResult? Function(_Retention value)? retention,
    TResult? Function(_Recovery value)? recovery,
    TResult? Function(_Finished value)? finished,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Idle value)? idle,
    TResult Function(_Breathing value)? breathing,
    TResult Function(_Retention value)? retention,
    TResult Function(_Recovery value)? recovery,
    TResult Function(_Finished value)? finished,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionPhaseCopyWith<$Res> {
  factory $SessionPhaseCopyWith(
          SessionPhase value, $Res Function(SessionPhase) then) =
      _$SessionPhaseCopyWithImpl<$Res, SessionPhase>;
}

/// @nodoc
class _$SessionPhaseCopyWithImpl<$Res, $Val extends SessionPhase>
    implements $SessionPhaseCopyWith<$Res> {
  _$SessionPhaseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SessionPhase
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$IdleImplCopyWith<$Res> {
  factory _$$IdleImplCopyWith(
          _$IdleImpl value, $Res Function(_$IdleImpl) then) =
      __$$IdleImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$IdleImplCopyWithImpl<$Res>
    extends _$SessionPhaseCopyWithImpl<$Res, _$IdleImpl>
    implements _$$IdleImplCopyWith<$Res> {
  __$$IdleImplCopyWithImpl(_$IdleImpl _value, $Res Function(_$IdleImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionPhase
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$IdleImpl implements _Idle {
  const _$IdleImpl();

  @override
  String toString() {
    return 'SessionPhase.idle()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$IdleImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(
            int breathIndex, bool isInhaling, Duration currentBreathDuration)
        breathing,
    required TResult Function(Duration elapsed) retention,
    required TResult Function(Duration remaining) recovery,
    required TResult Function() finished,
  }) {
    return idle();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(
            int breathIndex, bool isInhaling, Duration currentBreathDuration)?
        breathing,
    TResult? Function(Duration elapsed)? retention,
    TResult? Function(Duration remaining)? recovery,
    TResult? Function()? finished,
  }) {
    return idle?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(
            int breathIndex, bool isInhaling, Duration currentBreathDuration)?
        breathing,
    TResult Function(Duration elapsed)? retention,
    TResult Function(Duration remaining)? recovery,
    TResult Function()? finished,
    required TResult orElse(),
  }) {
    if (idle != null) {
      return idle();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Idle value) idle,
    required TResult Function(_Breathing value) breathing,
    required TResult Function(_Retention value) retention,
    required TResult Function(_Recovery value) recovery,
    required TResult Function(_Finished value) finished,
  }) {
    return idle(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Idle value)? idle,
    TResult? Function(_Breathing value)? breathing,
    TResult? Function(_Retention value)? retention,
    TResult? Function(_Recovery value)? recovery,
    TResult? Function(_Finished value)? finished,
  }) {
    return idle?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Idle value)? idle,
    TResult Function(_Breathing value)? breathing,
    TResult Function(_Retention value)? retention,
    TResult Function(_Recovery value)? recovery,
    TResult Function(_Finished value)? finished,
    required TResult orElse(),
  }) {
    if (idle != null) {
      return idle(this);
    }
    return orElse();
  }
}

abstract class _Idle implements SessionPhase {
  const factory _Idle() = _$IdleImpl;
}

/// @nodoc
abstract class _$$BreathingImplCopyWith<$Res> {
  factory _$$BreathingImplCopyWith(
          _$BreathingImpl value, $Res Function(_$BreathingImpl) then) =
      __$$BreathingImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int breathIndex, bool isInhaling, Duration currentBreathDuration});
}

/// @nodoc
class __$$BreathingImplCopyWithImpl<$Res>
    extends _$SessionPhaseCopyWithImpl<$Res, _$BreathingImpl>
    implements _$$BreathingImplCopyWith<$Res> {
  __$$BreathingImplCopyWithImpl(
      _$BreathingImpl _value, $Res Function(_$BreathingImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionPhase
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? breathIndex = null,
    Object? isInhaling = null,
    Object? currentBreathDuration = null,
  }) {
    return _then(_$BreathingImpl(
      breathIndex: null == breathIndex
          ? _value.breathIndex
          : breathIndex // ignore: cast_nullable_to_non_nullable
              as int,
      isInhaling: null == isInhaling
          ? _value.isInhaling
          : isInhaling // ignore: cast_nullable_to_non_nullable
              as bool,
      currentBreathDuration: null == currentBreathDuration
          ? _value.currentBreathDuration
          : currentBreathDuration // ignore: cast_nullable_to_non_nullable
              as Duration,
    ));
  }
}

/// @nodoc

class _$BreathingImpl implements _Breathing {
  const _$BreathingImpl(
      {required this.breathIndex,
      required this.isInhaling,
      required this.currentBreathDuration});

  @override
  final int breathIndex;
  @override
  final bool isInhaling;
  @override
  final Duration currentBreathDuration;

  @override
  String toString() {
    return 'SessionPhase.breathing(breathIndex: $breathIndex, isInhaling: $isInhaling, currentBreathDuration: $currentBreathDuration)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BreathingImpl &&
            (identical(other.breathIndex, breathIndex) ||
                other.breathIndex == breathIndex) &&
            (identical(other.isInhaling, isInhaling) ||
                other.isInhaling == isInhaling) &&
            (identical(other.currentBreathDuration, currentBreathDuration) ||
                other.currentBreathDuration == currentBreathDuration));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, breathIndex, isInhaling, currentBreathDuration);

  /// Create a copy of SessionPhase
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BreathingImplCopyWith<_$BreathingImpl> get copyWith =>
      __$$BreathingImplCopyWithImpl<_$BreathingImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(
            int breathIndex, bool isInhaling, Duration currentBreathDuration)
        breathing,
    required TResult Function(Duration elapsed) retention,
    required TResult Function(Duration remaining) recovery,
    required TResult Function() finished,
  }) {
    return breathing(breathIndex, isInhaling, currentBreathDuration);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(
            int breathIndex, bool isInhaling, Duration currentBreathDuration)?
        breathing,
    TResult? Function(Duration elapsed)? retention,
    TResult? Function(Duration remaining)? recovery,
    TResult? Function()? finished,
  }) {
    return breathing?.call(breathIndex, isInhaling, currentBreathDuration);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(
            int breathIndex, bool isInhaling, Duration currentBreathDuration)?
        breathing,
    TResult Function(Duration elapsed)? retention,
    TResult Function(Duration remaining)? recovery,
    TResult Function()? finished,
    required TResult orElse(),
  }) {
    if (breathing != null) {
      return breathing(breathIndex, isInhaling, currentBreathDuration);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Idle value) idle,
    required TResult Function(_Breathing value) breathing,
    required TResult Function(_Retention value) retention,
    required TResult Function(_Recovery value) recovery,
    required TResult Function(_Finished value) finished,
  }) {
    return breathing(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Idle value)? idle,
    TResult? Function(_Breathing value)? breathing,
    TResult? Function(_Retention value)? retention,
    TResult? Function(_Recovery value)? recovery,
    TResult? Function(_Finished value)? finished,
  }) {
    return breathing?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Idle value)? idle,
    TResult Function(_Breathing value)? breathing,
    TResult Function(_Retention value)? retention,
    TResult Function(_Recovery value)? recovery,
    TResult Function(_Finished value)? finished,
    required TResult orElse(),
  }) {
    if (breathing != null) {
      return breathing(this);
    }
    return orElse();
  }
}

abstract class _Breathing implements SessionPhase {
  const factory _Breathing(
      {required final int breathIndex,
      required final bool isInhaling,
      required final Duration currentBreathDuration}) = _$BreathingImpl;

  int get breathIndex;
  bool get isInhaling;
  Duration get currentBreathDuration;

  /// Create a copy of SessionPhase
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BreathingImplCopyWith<_$BreathingImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RetentionImplCopyWith<$Res> {
  factory _$$RetentionImplCopyWith(
          _$RetentionImpl value, $Res Function(_$RetentionImpl) then) =
      __$$RetentionImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Duration elapsed});
}

/// @nodoc
class __$$RetentionImplCopyWithImpl<$Res>
    extends _$SessionPhaseCopyWithImpl<$Res, _$RetentionImpl>
    implements _$$RetentionImplCopyWith<$Res> {
  __$$RetentionImplCopyWithImpl(
      _$RetentionImpl _value, $Res Function(_$RetentionImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionPhase
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? elapsed = null,
  }) {
    return _then(_$RetentionImpl(
      elapsed: null == elapsed
          ? _value.elapsed
          : elapsed // ignore: cast_nullable_to_non_nullable
              as Duration,
    ));
  }
}

/// @nodoc

class _$RetentionImpl implements _Retention {
  const _$RetentionImpl({required this.elapsed});

  @override
  final Duration elapsed;

  @override
  String toString() {
    return 'SessionPhase.retention(elapsed: $elapsed)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RetentionImpl &&
            (identical(other.elapsed, elapsed) || other.elapsed == elapsed));
  }

  @override
  int get hashCode => Object.hash(runtimeType, elapsed);

  /// Create a copy of SessionPhase
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RetentionImplCopyWith<_$RetentionImpl> get copyWith =>
      __$$RetentionImplCopyWithImpl<_$RetentionImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(
            int breathIndex, bool isInhaling, Duration currentBreathDuration)
        breathing,
    required TResult Function(Duration elapsed) retention,
    required TResult Function(Duration remaining) recovery,
    required TResult Function() finished,
  }) {
    return retention(elapsed);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(
            int breathIndex, bool isInhaling, Duration currentBreathDuration)?
        breathing,
    TResult? Function(Duration elapsed)? retention,
    TResult? Function(Duration remaining)? recovery,
    TResult? Function()? finished,
  }) {
    return retention?.call(elapsed);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(
            int breathIndex, bool isInhaling, Duration currentBreathDuration)?
        breathing,
    TResult Function(Duration elapsed)? retention,
    TResult Function(Duration remaining)? recovery,
    TResult Function()? finished,
    required TResult orElse(),
  }) {
    if (retention != null) {
      return retention(elapsed);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Idle value) idle,
    required TResult Function(_Breathing value) breathing,
    required TResult Function(_Retention value) retention,
    required TResult Function(_Recovery value) recovery,
    required TResult Function(_Finished value) finished,
  }) {
    return retention(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Idle value)? idle,
    TResult? Function(_Breathing value)? breathing,
    TResult? Function(_Retention value)? retention,
    TResult? Function(_Recovery value)? recovery,
    TResult? Function(_Finished value)? finished,
  }) {
    return retention?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Idle value)? idle,
    TResult Function(_Breathing value)? breathing,
    TResult Function(_Retention value)? retention,
    TResult Function(_Recovery value)? recovery,
    TResult Function(_Finished value)? finished,
    required TResult orElse(),
  }) {
    if (retention != null) {
      return retention(this);
    }
    return orElse();
  }
}

abstract class _Retention implements SessionPhase {
  const factory _Retention({required final Duration elapsed}) = _$RetentionImpl;

  Duration get elapsed;

  /// Create a copy of SessionPhase
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RetentionImplCopyWith<_$RetentionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RecoveryImplCopyWith<$Res> {
  factory _$$RecoveryImplCopyWith(
          _$RecoveryImpl value, $Res Function(_$RecoveryImpl) then) =
      __$$RecoveryImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Duration remaining});
}

/// @nodoc
class __$$RecoveryImplCopyWithImpl<$Res>
    extends _$SessionPhaseCopyWithImpl<$Res, _$RecoveryImpl>
    implements _$$RecoveryImplCopyWith<$Res> {
  __$$RecoveryImplCopyWithImpl(
      _$RecoveryImpl _value, $Res Function(_$RecoveryImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionPhase
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? remaining = null,
  }) {
    return _then(_$RecoveryImpl(
      remaining: null == remaining
          ? _value.remaining
          : remaining // ignore: cast_nullable_to_non_nullable
              as Duration,
    ));
  }
}

/// @nodoc

class _$RecoveryImpl implements _Recovery {
  const _$RecoveryImpl({required this.remaining});

  @override
  final Duration remaining;

  @override
  String toString() {
    return 'SessionPhase.recovery(remaining: $remaining)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecoveryImpl &&
            (identical(other.remaining, remaining) ||
                other.remaining == remaining));
  }

  @override
  int get hashCode => Object.hash(runtimeType, remaining);

  /// Create a copy of SessionPhase
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecoveryImplCopyWith<_$RecoveryImpl> get copyWith =>
      __$$RecoveryImplCopyWithImpl<_$RecoveryImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(
            int breathIndex, bool isInhaling, Duration currentBreathDuration)
        breathing,
    required TResult Function(Duration elapsed) retention,
    required TResult Function(Duration remaining) recovery,
    required TResult Function() finished,
  }) {
    return recovery(remaining);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(
            int breathIndex, bool isInhaling, Duration currentBreathDuration)?
        breathing,
    TResult? Function(Duration elapsed)? retention,
    TResult? Function(Duration remaining)? recovery,
    TResult? Function()? finished,
  }) {
    return recovery?.call(remaining);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(
            int breathIndex, bool isInhaling, Duration currentBreathDuration)?
        breathing,
    TResult Function(Duration elapsed)? retention,
    TResult Function(Duration remaining)? recovery,
    TResult Function()? finished,
    required TResult orElse(),
  }) {
    if (recovery != null) {
      return recovery(remaining);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Idle value) idle,
    required TResult Function(_Breathing value) breathing,
    required TResult Function(_Retention value) retention,
    required TResult Function(_Recovery value) recovery,
    required TResult Function(_Finished value) finished,
  }) {
    return recovery(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Idle value)? idle,
    TResult? Function(_Breathing value)? breathing,
    TResult? Function(_Retention value)? retention,
    TResult? Function(_Recovery value)? recovery,
    TResult? Function(_Finished value)? finished,
  }) {
    return recovery?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Idle value)? idle,
    TResult Function(_Breathing value)? breathing,
    TResult Function(_Retention value)? retention,
    TResult Function(_Recovery value)? recovery,
    TResult Function(_Finished value)? finished,
    required TResult orElse(),
  }) {
    if (recovery != null) {
      return recovery(this);
    }
    return orElse();
  }
}

abstract class _Recovery implements SessionPhase {
  const factory _Recovery({required final Duration remaining}) = _$RecoveryImpl;

  Duration get remaining;

  /// Create a copy of SessionPhase
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecoveryImplCopyWith<_$RecoveryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FinishedImplCopyWith<$Res> {
  factory _$$FinishedImplCopyWith(
          _$FinishedImpl value, $Res Function(_$FinishedImpl) then) =
      __$$FinishedImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$FinishedImplCopyWithImpl<$Res>
    extends _$SessionPhaseCopyWithImpl<$Res, _$FinishedImpl>
    implements _$$FinishedImplCopyWith<$Res> {
  __$$FinishedImplCopyWithImpl(
      _$FinishedImpl _value, $Res Function(_$FinishedImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionPhase
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$FinishedImpl implements _Finished {
  const _$FinishedImpl();

  @override
  String toString() {
    return 'SessionPhase.finished()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$FinishedImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(
            int breathIndex, bool isInhaling, Duration currentBreathDuration)
        breathing,
    required TResult Function(Duration elapsed) retention,
    required TResult Function(Duration remaining) recovery,
    required TResult Function() finished,
  }) {
    return finished();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(
            int breathIndex, bool isInhaling, Duration currentBreathDuration)?
        breathing,
    TResult? Function(Duration elapsed)? retention,
    TResult? Function(Duration remaining)? recovery,
    TResult? Function()? finished,
  }) {
    return finished?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(
            int breathIndex, bool isInhaling, Duration currentBreathDuration)?
        breathing,
    TResult Function(Duration elapsed)? retention,
    TResult Function(Duration remaining)? recovery,
    TResult Function()? finished,
    required TResult orElse(),
  }) {
    if (finished != null) {
      return finished();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Idle value) idle,
    required TResult Function(_Breathing value) breathing,
    required TResult Function(_Retention value) retention,
    required TResult Function(_Recovery value) recovery,
    required TResult Function(_Finished value) finished,
  }) {
    return finished(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Idle value)? idle,
    TResult? Function(_Breathing value)? breathing,
    TResult? Function(_Retention value)? retention,
    TResult? Function(_Recovery value)? recovery,
    TResult? Function(_Finished value)? finished,
  }) {
    return finished?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Idle value)? idle,
    TResult Function(_Breathing value)? breathing,
    TResult Function(_Retention value)? retention,
    TResult Function(_Recovery value)? recovery,
    TResult Function(_Finished value)? finished,
    required TResult orElse(),
  }) {
    if (finished != null) {
      return finished(this);
    }
    return orElse();
  }
}

abstract class _Finished implements SessionPhase {
  const factory _Finished() = _$FinishedImpl;
}

/// @nodoc
mixin _$SessionState {
  SessionPhase get phase => throw _privateConstructorUsedError;
  int get currentRound => throw _privateConstructorUsedError;
  int get totalRounds => throw _privateConstructorUsedError;
  int get totalBreathsInRound => throw _privateConstructorUsedError;
  bool get isGhostMode => throw _privateConstructorUsedError;
  bool get isPanicMode => throw _privateConstructorUsedError;
  List<Duration> get retentionLogs => throw _privateConstructorUsedError;
  DateTime? get startTime => throw _privateConstructorUsedError;
  Duration? get sessionDuration =>
      throw _privateConstructorUsedError; // Override the default phase UI with custom text and sizing for specialized exercises like Box Breathing.
  String? get customLabel => throw _privateConstructorUsedError;
  String? get customDescription => throw _privateConstructorUsedError;
  bool? get customIsBig => throw _privateConstructorUsedError;

  /// Create a copy of SessionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SessionStateCopyWith<SessionState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionStateCopyWith<$Res> {
  factory $SessionStateCopyWith(
          SessionState value, $Res Function(SessionState) then) =
      _$SessionStateCopyWithImpl<$Res, SessionState>;
  @useResult
  $Res call(
      {SessionPhase phase,
      int currentRound,
      int totalRounds,
      int totalBreathsInRound,
      bool isGhostMode,
      bool isPanicMode,
      List<Duration> retentionLogs,
      DateTime? startTime,
      Duration? sessionDuration,
      String? customLabel,
      String? customDescription,
      bool? customIsBig});

  $SessionPhaseCopyWith<$Res> get phase;
}

/// @nodoc
class _$SessionStateCopyWithImpl<$Res, $Val extends SessionState>
    implements $SessionStateCopyWith<$Res> {
  _$SessionStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SessionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? phase = null,
    Object? currentRound = null,
    Object? totalRounds = null,
    Object? totalBreathsInRound = null,
    Object? isGhostMode = null,
    Object? isPanicMode = null,
    Object? retentionLogs = null,
    Object? startTime = freezed,
    Object? sessionDuration = freezed,
    Object? customLabel = freezed,
    Object? customDescription = freezed,
    Object? customIsBig = freezed,
  }) {
    return _then(_value.copyWith(
      phase: null == phase
          ? _value.phase
          : phase // ignore: cast_nullable_to_non_nullable
              as SessionPhase,
      currentRound: null == currentRound
          ? _value.currentRound
          : currentRound // ignore: cast_nullable_to_non_nullable
              as int,
      totalRounds: null == totalRounds
          ? _value.totalRounds
          : totalRounds // ignore: cast_nullable_to_non_nullable
              as int,
      totalBreathsInRound: null == totalBreathsInRound
          ? _value.totalBreathsInRound
          : totalBreathsInRound // ignore: cast_nullable_to_non_nullable
              as int,
      isGhostMode: null == isGhostMode
          ? _value.isGhostMode
          : isGhostMode // ignore: cast_nullable_to_non_nullable
              as bool,
      isPanicMode: null == isPanicMode
          ? _value.isPanicMode
          : isPanicMode // ignore: cast_nullable_to_non_nullable
              as bool,
      retentionLogs: null == retentionLogs
          ? _value.retentionLogs
          : retentionLogs // ignore: cast_nullable_to_non_nullable
              as List<Duration>,
      startTime: freezed == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      sessionDuration: freezed == sessionDuration
          ? _value.sessionDuration
          : sessionDuration // ignore: cast_nullable_to_non_nullable
              as Duration?,
      customLabel: freezed == customLabel
          ? _value.customLabel
          : customLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      customDescription: freezed == customDescription
          ? _value.customDescription
          : customDescription // ignore: cast_nullable_to_non_nullable
              as String?,
      customIsBig: freezed == customIsBig
          ? _value.customIsBig
          : customIsBig // ignore: cast_nullable_to_non_nullable
              as bool?,
    ) as $Val);
  }

  /// Create a copy of SessionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SessionPhaseCopyWith<$Res> get phase {
    return $SessionPhaseCopyWith<$Res>(_value.phase, (value) {
      return _then(_value.copyWith(phase: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SessionStateImplCopyWith<$Res>
    implements $SessionStateCopyWith<$Res> {
  factory _$$SessionStateImplCopyWith(
          _$SessionStateImpl value, $Res Function(_$SessionStateImpl) then) =
      __$$SessionStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {SessionPhase phase,
      int currentRound,
      int totalRounds,
      int totalBreathsInRound,
      bool isGhostMode,
      bool isPanicMode,
      List<Duration> retentionLogs,
      DateTime? startTime,
      Duration? sessionDuration,
      String? customLabel,
      String? customDescription,
      bool? customIsBig});

  @override
  $SessionPhaseCopyWith<$Res> get phase;
}

/// @nodoc
class __$$SessionStateImplCopyWithImpl<$Res>
    extends _$SessionStateCopyWithImpl<$Res, _$SessionStateImpl>
    implements _$$SessionStateImplCopyWith<$Res> {
  __$$SessionStateImplCopyWithImpl(
      _$SessionStateImpl _value, $Res Function(_$SessionStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? phase = null,
    Object? currentRound = null,
    Object? totalRounds = null,
    Object? totalBreathsInRound = null,
    Object? isGhostMode = null,
    Object? isPanicMode = null,
    Object? retentionLogs = null,
    Object? startTime = freezed,
    Object? sessionDuration = freezed,
    Object? customLabel = freezed,
    Object? customDescription = freezed,
    Object? customIsBig = freezed,
  }) {
    return _then(_$SessionStateImpl(
      phase: null == phase
          ? _value.phase
          : phase // ignore: cast_nullable_to_non_nullable
              as SessionPhase,
      currentRound: null == currentRound
          ? _value.currentRound
          : currentRound // ignore: cast_nullable_to_non_nullable
              as int,
      totalRounds: null == totalRounds
          ? _value.totalRounds
          : totalRounds // ignore: cast_nullable_to_non_nullable
              as int,
      totalBreathsInRound: null == totalBreathsInRound
          ? _value.totalBreathsInRound
          : totalBreathsInRound // ignore: cast_nullable_to_non_nullable
              as int,
      isGhostMode: null == isGhostMode
          ? _value.isGhostMode
          : isGhostMode // ignore: cast_nullable_to_non_nullable
              as bool,
      isPanicMode: null == isPanicMode
          ? _value.isPanicMode
          : isPanicMode // ignore: cast_nullable_to_non_nullable
              as bool,
      retentionLogs: null == retentionLogs
          ? _value._retentionLogs
          : retentionLogs // ignore: cast_nullable_to_non_nullable
              as List<Duration>,
      startTime: freezed == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      sessionDuration: freezed == sessionDuration
          ? _value.sessionDuration
          : sessionDuration // ignore: cast_nullable_to_non_nullable
              as Duration?,
      customLabel: freezed == customLabel
          ? _value.customLabel
          : customLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      customDescription: freezed == customDescription
          ? _value.customDescription
          : customDescription // ignore: cast_nullable_to_non_nullable
              as String?,
      customIsBig: freezed == customIsBig
          ? _value.customIsBig
          : customIsBig // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// @nodoc

class _$SessionStateImpl implements _SessionState {
  const _$SessionStateImpl(
      {required this.phase,
      required this.currentRound,
      required this.totalRounds,
      required this.totalBreathsInRound,
      required this.isGhostMode,
      required this.isPanicMode,
      required final List<Duration> retentionLogs,
      required this.startTime,
      this.sessionDuration,
      this.customLabel,
      this.customDescription,
      this.customIsBig})
      : _retentionLogs = retentionLogs;

  @override
  final SessionPhase phase;
  @override
  final int currentRound;
  @override
  final int totalRounds;
  @override
  final int totalBreathsInRound;
  @override
  final bool isGhostMode;
  @override
  final bool isPanicMode;
  final List<Duration> _retentionLogs;
  @override
  List<Duration> get retentionLogs {
    if (_retentionLogs is EqualUnmodifiableListView) return _retentionLogs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_retentionLogs);
  }

  @override
  final DateTime? startTime;
  @override
  final Duration? sessionDuration;
// Override the default phase UI with custom text and sizing for specialized exercises like Box Breathing.
  @override
  final String? customLabel;
  @override
  final String? customDescription;
  @override
  final bool? customIsBig;

  @override
  String toString() {
    return 'SessionState(phase: $phase, currentRound: $currentRound, totalRounds: $totalRounds, totalBreathsInRound: $totalBreathsInRound, isGhostMode: $isGhostMode, isPanicMode: $isPanicMode, retentionLogs: $retentionLogs, startTime: $startTime, sessionDuration: $sessionDuration, customLabel: $customLabel, customDescription: $customDescription, customIsBig: $customIsBig)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionStateImpl &&
            (identical(other.phase, phase) || other.phase == phase) &&
            (identical(other.currentRound, currentRound) ||
                other.currentRound == currentRound) &&
            (identical(other.totalRounds, totalRounds) ||
                other.totalRounds == totalRounds) &&
            (identical(other.totalBreathsInRound, totalBreathsInRound) ||
                other.totalBreathsInRound == totalBreathsInRound) &&
            (identical(other.isGhostMode, isGhostMode) ||
                other.isGhostMode == isGhostMode) &&
            (identical(other.isPanicMode, isPanicMode) ||
                other.isPanicMode == isPanicMode) &&
            const DeepCollectionEquality()
                .equals(other._retentionLogs, _retentionLogs) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.sessionDuration, sessionDuration) ||
                other.sessionDuration == sessionDuration) &&
            (identical(other.customLabel, customLabel) ||
                other.customLabel == customLabel) &&
            (identical(other.customDescription, customDescription) ||
                other.customDescription == customDescription) &&
            (identical(other.customIsBig, customIsBig) ||
                other.customIsBig == customIsBig));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      phase,
      currentRound,
      totalRounds,
      totalBreathsInRound,
      isGhostMode,
      isPanicMode,
      const DeepCollectionEquality().hash(_retentionLogs),
      startTime,
      sessionDuration,
      customLabel,
      customDescription,
      customIsBig);

  /// Create a copy of SessionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionStateImplCopyWith<_$SessionStateImpl> get copyWith =>
      __$$SessionStateImplCopyWithImpl<_$SessionStateImpl>(this, _$identity);
}

abstract class _SessionState implements SessionState {
  const factory _SessionState(
      {required final SessionPhase phase,
      required final int currentRound,
      required final int totalRounds,
      required final int totalBreathsInRound,
      required final bool isGhostMode,
      required final bool isPanicMode,
      required final List<Duration> retentionLogs,
      required final DateTime? startTime,
      final Duration? sessionDuration,
      final String? customLabel,
      final String? customDescription,
      final bool? customIsBig}) = _$SessionStateImpl;

  @override
  SessionPhase get phase;
  @override
  int get currentRound;
  @override
  int get totalRounds;
  @override
  int get totalBreathsInRound;
  @override
  bool get isGhostMode;
  @override
  bool get isPanicMode;
  @override
  List<Duration> get retentionLogs;
  @override
  DateTime? get startTime;
  @override
  Duration?
      get sessionDuration; // Override the default phase UI with custom text and sizing for specialized exercises like Box Breathing.
  @override
  String? get customLabel;
  @override
  String? get customDescription;
  @override
  bool? get customIsBig;

  /// Create a copy of SessionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionStateImplCopyWith<_$SessionStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
