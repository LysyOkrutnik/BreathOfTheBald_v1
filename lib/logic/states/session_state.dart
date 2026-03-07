import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_state.freezed.dart';

@freezed
class SessionPhase with _$SessionPhase {
  const factory SessionPhase.idle() = _Idle;
  const factory SessionPhase.breathing({
    required int breathIndex,
    required bool isInhaling,
    required Duration currentBreathDuration,
  }) = _Breathing;
  const factory SessionPhase.retention({required Duration elapsed}) = _Retention;
  const factory SessionPhase.recovery({required Duration remaining}) = _Recovery;
  const factory SessionPhase.finished() = _Finished;
}

@freezed
class SessionState with _$SessionState {
  const factory SessionState({
    required SessionPhase phase,
    required int currentRound,
    required int totalRounds,
    required int totalBreathsInRound,
    required bool isGhostMode,
    required bool isPanicMode,
    required List<Duration> retentionLogs,
    required DateTime? startTime,

    Duration? sessionDuration,

    // Override default phase UI with custom text and sizing for specialized exercises.
    String? customLabel,
    String? customDescription,
    bool? customIsBig,
  }) = _SessionState;

  factory SessionState.initial() => const SessionState(
    phase: SessionPhase.idle(),
    currentRound: 1,
    totalRounds: 3,
    totalBreathsInRound: 30,
    isGhostMode: false,
    isPanicMode: false,
    retentionLogs: [],
    startTime: null,
    sessionDuration: null,
    customLabel: null,
    customDescription: null,
    customIsBig: null,
  );
}