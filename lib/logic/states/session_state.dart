import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:okrutnik_breath/config/levels.dart' show CycleStep;

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

    // Override the default phase UI with custom text and sizing for specialized exercises like Box Breathing.
    String? customLabel,
    String? customDescription,
    bool? customIsBig,

    // True right after a freediving table round was ended early (the user
    // tapped "I need to breathe"), once that round's exhale has finished —
    // the flow pauses here for an explicit continue-or-end decision instead
    // of silently ending the whole table.
    @Default(false) bool awaitingRoundDecision,

    // Live count of "first contraction" taps marked during the *current*
    // freediving hold — reset to 0 at the start of every round's hold. Only
    // meaningful while `phase` is `retention` during a freediving table.
    @Default(0) int contractionMarkCount,

    // The live cycle-diagram definition and current node, copied from
    // `LevelData.cycleSteps` once at session start — null for exercise
    // types with no diagram (see that field's doc for why). Kept on
    // `SessionState` rather than read from `LevelData` directly so
    // `session_screen.dart` stays driven purely by session state, same as
    // every other display field here.
    List<CycleStep>? cycleSteps,
    int? cycleStepIndex,
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
    cycleSteps: null,
    cycleStepIndex: null,
    awaitingRoundDecision: false,
    contractionMarkCount: 0,
  );
}