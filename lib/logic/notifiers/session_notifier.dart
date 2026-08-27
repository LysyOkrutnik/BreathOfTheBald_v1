import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/core/audio/audio_manager.dart';
import 'package:okrutnik_breath/core/haptic/haptic_engine.dart';
import 'package:okrutnik_breath/core/notifications/notification_service.dart';
import 'package:okrutnik_breath/logic/freediving/co2_o2_table_generator.dart';
import 'package:okrutnik_breath/logic/notifiers/ramp_up_calculator.dart';
import 'package:okrutnik_breath/logic/path/weekly_plan.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/logic/services/gamification_service.dart';
import 'package:okrutnik_breath/logic/providers/locale_provider.dart';
import 'package:okrutnik_breath/logic/providers/settings_provider.dart';
import 'package:okrutnik_breath/logic/states/session_state.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// One step of a fixed breathing pattern (box breathing, 4-7-8) — see
/// [SessionNotifier._runPhaseCycle].
class _BreathPhase {
  const _BreathPhase({
    required this.label,
    required this.desc,
    required this.isBig,
    required this.isInhaling,
    required this.duration,
    this.signal,
    this.haptic = false,
  });

  final String label;
  final String desc;
  final bool isBig;
  final bool isInhaling;
  final Duration duration;

  /// Whether to play the inhale/exhale breath signal on entering this phase
  /// (`true`/`false`), or nothing (`null`).
  final bool? signal;

  /// Whether to play a plain haptic tick on entering this phase (used for
  /// hold phases, which have no inhale/exhale signal of their own).
  final bool haptic;
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  final audioManager = ref.read(audioManagerProvider);
  return SessionNotifier(audioManager, ref);
});

class SessionNotifier extends StateNotifier<SessionState> with WidgetsBindingObserver {
  final AudioManager _audioManager;
  final HapticEngine _hapticEngine = HapticEngine();
  final Ref _ref;

  final Stopwatch _sessionTimer = Stopwatch();

  LevelData? _currentLevel;
  bool _isSessionActive = false;
  Timer? _phaseTimer;

  /// Set when this session was started from a saved calendar entry — the
  /// row gets marked done (not deleted) once the session actually finishes,
  /// so the calendar/today views can render it as completed instead of it
  /// simply vanishing. Null for a session started any other way (a level
  /// tapped directly from a grid, "Twoja Ścieżka"'s Dziś card, etc.), which
  /// has no calendar row to mark.
  int? _plannedSessionId;

  // --- Freediving CO2/O2 table state ---
  List<BreathHoldRound>? _freedivingRounds;
  int _freedivingRoundIndex = 0;
  int _freedivingRoundsCompleted = 0;

  // --- "Fala kontrakcji" (first-contraction marking), freediving only ---
  DateTime? _currentHoldStart;
  List<Duration> _currentRoundContractions = [];
  final List<RoundContraction> _contractionsByRound = [];

  /// Set once, right when a freediving table session finishes — read once by
  /// the summary screen, same lifecycle as [justLeveledUpTo]. Null for any
  /// other exercise type, or if no round was ever marked.
  RoundContractionSummary? lastFreedivingContractionSummary;

  /// The exercise type of the most recently finished session, so the summary
  /// screen can decide whether to show the post-session RPE prompt (Wim Hof
  /// levels and CO2/O2 tables). Set once, at the moment a session finishes.
  ExerciseType? lastFinishedExerciseType;

  /// The `LevelData.key` of the most recently finished session — needed
  /// alongside [lastFinishedExerciseType] to single out one specific
  /// `guidedRoutine` exercise (packing) from its siblings, which all share
  /// that same [ExerciseType].
  String? lastFinishedLevelKey;

  /// The new level, if the just-finished session pushed the user's total XP
  /// into a new level bracket — null otherwise. Read once by the summary
  /// screen, same lifecycle as [lastFinishedExerciseType].
  int? justLeveledUpTo;

  /// True if the just-finished session's streak update used its one-day
  /// grace (a missed day forgiven rather than resetting the streak).
  bool justUsedStreakGrace = false;

  /// Resolves to the just-finished session's row id once the background
  /// persist completes (or null if there was nothing to persist) — the
  /// summary screen awaits this before attaching a Wim Hof RPE rating,
  /// since the insert can still be in flight when the user answers.
  Completer<int?> _lastSessionIdCompleter = Completer<int?>();
  Future<int?> get lastSessionIdFuture => _lastSessionIdCompleter.future;

  /// True only while a session is active *and* this notifier is still mounted.
  /// Writing `state` after disposal throws, so every async continuation guards
  /// on this before touching state.
  bool get _isRunning => _isSessionActive && mounted;

  /// Set by [endGuidedHoldEarly], checked once per second by the guided-hold
  /// countdown in `_guidedStepPhase` — reset to false whenever a new hold
  /// step starts.
  bool _skipCurrentGuidedHold = false;

  SessionNotifier(this._audioManager, this._ref) : super(SessionState.initial()) {
    WidgetsBinding.instance.addObserver(this);
  }

  // Named `appState`, not `state` — this class already has a `state` member
  // (the current SessionState) and shadowing it here would be a trap.
  @override
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (!_isSessionActive) return;

    // Deliberately does nothing beyond pacing the drone — a session is
    // meant to keep running exactly as timed whether the screen is on or
    // locked (e.g. a passive Wim Hof/meditation session on a bus or with
    // eyes closed). Phase timing is wall-clock based (`DateTime.now()`
    // diffs), so nothing drifts while backgrounded. This used to also flag
    // any backgrounding of 20+ seconds as a suspicious "interruption" and
    // force the exit-confirmation dialog on resume — which fired on every
    // ordinary screen lock, since locking the screen for the whole session
    // is exactly what a real breathing/meditation practice looks like.
    if (appState == AppLifecycleState.paused) {
      // Silences the ambient drone while backgrounded — nothing is visible
      // to pace against anyway, and it's the one part of a session that
      // would otherwise keep audibly running from inside a pocket or bag.
      try {
        _audioManager.stopDrone();
      } catch (_) {}
    } else if (appState == AppLifecycleState.resumed) {
      if (!_isRunning) return;
      try {
        _audioManager.startDrone();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> startSession(LevelData level, {int? plannedSessionId}) async {
    // Ignore a duplicate start while a session is already running (e.g. a
    // double-tapped Start button or the widget delivering its launch twice) —
    // otherwise two breathing loops run concurrently and cues double up.
    if (_isSessionActive) return;

    _isSessionActive = true;
    _currentLevel = level;
    _plannedSessionId = plannedSessionId;

    // Apply the user's sound/haptics preferences for this session.
    final settings = _ref.read(settingsProvider);
    _audioManager.soundEnabled = settings.soundEnabled;
    _hapticEngine.enabled = settings.hapticsEnabled;

    // Prevent timer duplication if a new session is started before the old one is fully disposed.
    _phaseTimer?.cancel();
    _sessionTimer.reset();

    Future(() async {
      try {
        await WakelockPlus.enable();
        await _audioManager.init();
        await _audioManager.startDrone();
        await _audioManager.unduckDrone();
      } catch (_) {}
    });

    // Fire breathing now carries a real totalBreaths (breaths per round,
    // same meaning as Wim Hof's) since its round restructure, so it no
    // longer needs a special-cased estimate here.
    int totalBreaths = level.totalBreaths;
    if (level.type == ExerciseType.boxBreathing) {
      totalBreaths = level.loopCount ?? 16;
    } else if (level.type == ExerciseType.relax478) {
      totalBreaths = level.loopCount ?? 32;
    } else if (level.type == ExerciseType.custom) {
      totalBreaths = level.loopCount ?? 8;
    }

    state = SessionState.initial().copyWith(
      startTime: DateTime.now(),
      sessionDuration: null,
      totalRounds: level.totalRounds > 0 ? level.totalRounds : 1,
      totalBreathsInRound: totalBreaths,
      phase: const SessionPhase.breathing(
          breathIndex: 1,
          isInhaling: false,
          currentBreathDuration: Duration.zero
      ),
      customLabel: "session_prepare",
      customDescription: "3...",
      customIsBig: false,
      // Copied once here rather than read from `_currentLevel` on every
      // build — session_screen.dart stays driven purely by SessionState,
      // same as every other display field. Null for exercise types with no
      // diagram (freediving tables/PB test — see LevelData.cycleSteps).
      cycleSteps: level.cycleSteps,
    );

    // --- COUNTDOWN ---
    for (int i = 3; i > 0; i--) {
      if (!_isRunning) return;
      if (i == 1) {
        try { _audioManager.playGong(); } catch (_) {}
      }
      state = state.copyWith(customDescription: "$i...");
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!_isRunning) return;
    state = state.copyWith(customDescription: "");

    _sessionTimer.start();

    if (level.type == ExerciseType.wimHof) {
      _startWimHof(level);
    } else if (level.type == ExerciseType.boxBreathing) {
      _startBoxBreathing(level);
    } else if (level.type == ExerciseType.relax478) {
      _startRelax478(level);
    } else if (level.type == ExerciseType.fireBreathing) {
      _startFireBreathing(level);
    } else if (level.type == ExerciseType.custom) {
      _startCustom(level);
    } else if (level.type.isFreedivingTable) {
      _startFreedivingTable(level);
    } else if (level.type == ExerciseType.guidedRoutine) {
      _startGuidedRoutine(level);
    }
  }

  // ==========================================================
  // CO2/O2 FREEDIVING TABLES
  // ==========================================================

  // Tunable timings for the guided CO2/O2 experience. Per-round overhead
  // beyond the generated table's exact apnea/rest seconds (breathe-up +
  // final inhale + exhale) lives in FreedivingSessionTiming, shared with the
  // pre-start preview — warm-up and cool-down are separate, skippable
  // bookends and stay local to the runner.
  static const _freedivingWarmupSec = 60;
  static const _freedivingInhaleSec = FreedivingSessionTiming.finalInhaleSec;
  static const _freedivingExhaleSec = FreedivingSessionTiming.exhaleSec;
  static const _freedivingCooldownSec = 30;

  /// True while a skippable pause (warm-up/cool-down) is active and can react
  /// to [skipFreedivingPause]. False during rest — the whole point of rest is
  /// that it isn't optional.
  bool _freedivingPauseSkippable = false;
  bool _freedivingSkipRequested = false;

  /// True right after a round's hold was ended early (rather than reaching
  /// its full planned duration) — consumed the moment exhale finishes, by
  /// pausing in [_advanceFreedivingRound] for an explicit continue-or-end
  /// decision instead of silently pushing into (or skipping) the rest of the
  /// table.
  bool _lastRoundMissed = false;

  /// Runs a pre-generated CO2/O2 breath-hold table end to end: a skippable
  /// warm-up, then per round an explicit inhale → fixed-duration hold →
  /// exhale → rest, and a skippable cool-down after the final round.
  void _startFreedivingTable(LevelData level) {
    final rounds = level.freedivingRounds;
    if (rounds == null || rounds.isEmpty) {
      if (_isRunning) _finishSession();
      return;
    }
    _freedivingRounds = rounds;
    _freedivingRoundIndex = 0;
    _freedivingRoundsCompleted = 0;
    state = state.copyWith(totalRounds: rounds.length, currentRound: 1);
    _runFreedivingPause(
      seconds: _freedivingWarmupSec,
      labelKey: 'freediving_warmup_label',
      hintKey: 'freediving_warmup_hint',
      onDone: _runFreedivingBreatheUp,
    );
  }

  /// A skippable countdown (warm-up before round 1, or cool-down after the
  /// last one). Deliberately *not* wired to the hold's tap-to-abort gesture —
  /// it uses the explicit, unambiguous [skipFreedivingPause] control instead,
  /// so it can never be confused with "I need to breathe now".
  void _runFreedivingPause({
    required int seconds,
    required String labelKey,
    required String hintKey,
    required void Function() onDone,
  }) {
    if (!_isRunning) return;
    _freedivingPauseSkippable = true;
    _freedivingSkipRequested = false;
    int sec = seconds;
    state = state.copyWith(
      customLabel: labelKey,
      customDescription: hintKey,
      customIsBig: false,
      phase: SessionPhase.recovery(remaining: Duration(seconds: sec)),
    );
    _phaseTimer?.cancel();
    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isRunning) {
        t.cancel();
        return;
      }
      if (_freedivingSkipRequested) {
        t.cancel();
        _freedivingPauseSkippable = false;
        onDone();
        return;
      }
      sec--;
      state = state.copyWith(phase: SessionPhase.recovery(remaining: Duration(seconds: sec)));
      if (sec <= 0) {
        t.cancel();
        _freedivingPauseSkippable = false;
        onDone();
      }
    });
  }

  /// Called by the "skip" control shown only during warm-up/cool-down.
  void skipFreedivingPause() {
    if (_freedivingPauseSkippable) _freedivingSkipRequested = true;
  }

  /// User chose "continue" on the post-missed-round dialog: proceeds exactly
  /// as a fully-completed round would (rest + next hold, or cool-down if
  /// that was the last round).
  void continueAfterMissedRound() {
    if (!state.awaitingRoundDecision) return;
    state = state.copyWith(awaitingRoundDecision: false);
    _advanceFreedivingRound();
  }

  /// User chose "end" on the post-missed-round dialog: stops the table here
  /// rather than attempting the remaining rounds.
  void endSessionAfterMissedRound() {
    if (!state.awaitingRoundDecision) return;
    state = state.copyWith(awaitingRoundDecision: false);
    _finishSession();
  }

  static const _freedivingBreatheUpCycles = FreedivingSessionTiming.breatheUpCycles;
  static const _freedivingBreatheUpBreathSec = FreedivingSessionTiming.breatheUpBreathSec;

  /// A handful of slow, calm breaths right before the final full inhale —
  /// deliberately distinct from Wim Hof's power breathing (fast, forceful,
  /// meant to build a CO2/O2 buffer through hyperventilation). A freediving
  /// breathe-up does the opposite: it lowers heart rate and CO2 production
  /// going into the hold, so the pace here is slow on purpose.
  void _runFreedivingBreatheUp({int cycle = 1}) {
    if (!_isRunning || _freedivingRounds == null) return;
    if (cycle > _freedivingBreatheUpCycles) {
      _runFreedivingInhale();
      return;
    }
    state = state.copyWith(
      customLabel: 'session_inhale',
      customDescription: 'freediving_breatheup_hint',
      customIsBig: true,
      phase: SessionPhase.breathing(
        breathIndex: cycle,
        isInhaling: true,
        currentBreathDuration: const Duration(seconds: _freedivingBreatheUpBreathSec),
      ),
    );
    try {
      _audioManager.playInhale();
    } catch (_) {}
    _phaseTimer?.cancel();
    _phaseTimer = Timer(const Duration(seconds: _freedivingBreatheUpBreathSec), () {
      if (!_isRunning) return;
      state = state.copyWith(
        customLabel: 'session_exhale',
        customDescription: 'freediving_breatheup_hint',
        customIsBig: false,
        phase: SessionPhase.breathing(
          breathIndex: cycle,
          isInhaling: false,
          currentBreathDuration: const Duration(seconds: _freedivingBreatheUpBreathSec),
        ),
      );
      try {
        _audioManager.playExhale();
      } catch (_) {}
      _phaseTimer = Timer(const Duration(seconds: _freedivingBreatheUpBreathSec), () {
        if (_isRunning) _runFreedivingBreatheUp(cycle: cycle + 1);
      });
    });
  }

  void _runFreedivingInhale() {
    if (!_isRunning || _freedivingRounds == null) return;
    state = state.copyWith(
      customLabel: 'session_inhale',
      customDescription: null,
      customIsBig: true,
      phase: SessionPhase.breathing(
        breathIndex: _freedivingRoundIndex + 1,
        isInhaling: true,
        currentBreathDuration: const Duration(seconds: _freedivingInhaleSec),
      ),
    );
    try {
      _audioManager.playInhale();
    } catch (_) {}
    _phaseTimer?.cancel();
    _phaseTimer = Timer(const Duration(seconds: _freedivingInhaleSec), () {
      if (_isRunning) _runFreedivingHold();
    });
  }

  void _runFreedivingHold() {
    if (!_isRunning || _freedivingRounds == null) return;
    final round = _freedivingRounds![_freedivingRoundIndex];
    _currentRoundContractions = [];
    state = state.copyWith(
      currentRound: _freedivingRoundIndex + 1,
      customLabel: 'freediving_hold_label',
      customDescription: null,
      customIsBig: true,
      phase: const SessionPhase.retention(elapsed: Duration.zero),
      contractionMarkCount: 0,
    );
    try {
      _hapticEngine.playRetentionPeak();
      _audioManager.playGong();
      _audioManager.duckDrone();
    } catch (_) {}

    final start = DateTime.now();
    _currentHoldStart = start;
    final target = Duration(seconds: round.apneaSec);
    _phaseTimer?.cancel();
    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isRunning) {
        t.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(start);
      // Update state with the real `elapsed` *before* checking completion —
      // `_finishFreedivingHold` reads the hold's duration back out of
      // `state.phase`'s retention value, so on the tick that actually
      // reaches `target`, that value needs to already reflect this tick's
      // elapsed time. The old order skipped this update whenever the target
      // was reached (only the `else` path updated state), so every fully
      // completed hold logged the *previous* tick's elapsed time — up to
      // ~1s short of the real/planned duration.
      state = state.copyWith(phase: SessionPhase.retention(elapsed: elapsed));
      if (elapsed >= target) {
        t.cancel();
        _finishFreedivingHold(completedFull: true);
      }
    });
  }

  /// Ends the current round's hold — either it reached its planned duration,
  /// or the user tapped the early-abort control via `finishRetention()`. The
  /// hold itself always ends immediately either way (a physiological "I need
  /// to breathe now" signal must never wait on anything); exhale still runs
  /// as normal, and only afterwards — in [_advanceFreedivingRound] — does an
  /// early ending pause for an explicit continue-or-end decision.
  void _finishFreedivingHold({required bool completedFull}) {
    _phaseTimer?.cancel();
    final round = _freedivingRounds![_freedivingRoundIndex];
    final actualElapsed = state.phase.maybeWhen(
      retention: (elapsed) => elapsed,
      orElse: () => Duration(seconds: round.apneaSec),
    );
    final logs = List<Duration>.from(state.retentionLogs)..add(actualElapsed);
    state = state.copyWith(retentionLogs: logs);

    _contractionsByRound.add(RoundContraction(
      firstContractionSec:
          _currentRoundContractions.isEmpty ? null : _currentRoundContractions.first.inSeconds,
      markCount: _currentRoundContractions.length,
    ));
    _currentRoundContractions = [];
    _currentHoldStart = null;

    if (completedFull) {
      _freedivingRoundsCompleted++;
    } else {
      _lastRoundMissed = true;
    }
    _runFreedivingExhale();
  }

  /// Marks a "first contraction" moment during a freediving hold — a tap
  /// that never ends the hold, just timestamps how far into it the
  /// diaphragm's urge-to-breathe reflex first showed up. A no-op outside an
  /// actual freediving hold (the UI only ever offers the control there, but
  /// this guards the state transition itself rather than trusting the
  /// caller).
  void markContraction() {
    final start = _currentHoldStart;
    if (start == null) return;
    final isFreedivingHold = state.phase.maybeMap(retention: (_) => true, orElse: () => false) &&
        (_currentLevel?.type.isFreedivingTable ?? false);
    if (!isFreedivingHold) return;

    _currentRoundContractions =
        List<Duration>.from(_currentRoundContractions)..add(DateTime.now().difference(start));
    state = state.copyWith(contractionMarkCount: _currentRoundContractions.length);
    try {
      _hapticEngine.playTick();
    } catch (_) {}
  }

  void _runFreedivingExhale() {
    if (!_isRunning || _freedivingRounds == null) return;
    state = state.copyWith(
      customLabel: 'session_exhale',
      customDescription: null,
      customIsBig: false,
      phase: SessionPhase.breathing(
        breathIndex: _freedivingRoundIndex + 1,
        isInhaling: false,
        currentBreathDuration: const Duration(seconds: _freedivingExhaleSec),
      ),
    );
    try {
      _audioManager.playExhale();
      _audioManager.unduckDrone();
    } catch (_) {}
    _phaseTimer?.cancel();
    _phaseTimer = Timer(const Duration(seconds: _freedivingExhaleSec), () {
      if (_isRunning) _advanceFreedivingRound();
    });
  }

  void _advanceFreedivingRound() {
    if (!_isRunning || _freedivingRounds == null) return;

    // The round that just finished was ended early — pause here for an
    // explicit continue-or-end decision (surfaced as a dialog by
    // SessionScreen) rather than silently deciding either way.
    if (_lastRoundMissed) {
      _lastRoundMissed = false;
      state = state.copyWith(awaitingRoundDecision: true);
      return;
    }

    final isLastRound = _freedivingRoundIndex >= _freedivingRounds!.length - 1;
    if (isLastRound) {
      _runFreedivingPause(
        seconds: _freedivingCooldownSec,
        labelKey: 'freediving_cooldown_label',
        hintKey: 'freediving_cooldown_hint',
        onDone: _finishSession,
      );
      return;
    }

    final round = _freedivingRounds![_freedivingRoundIndex];
    _freedivingRoundIndex++;
    state = state.copyWith(currentRound: _freedivingRoundIndex + 1);
    _runFreedivingPause(
      seconds: round.restSec,
      labelKey: 'freediving_rest_label',
      hintKey: 'freediving_rest_hint',
      onDone: _runFreedivingBreatheUp,
    );
  }

  // ==========================================================
  // CUSTOM (USER-DEFINED PATTERN)
  // ==========================================================
  Future<void> _startCustom(LevelData level) async {
    final cycles = level.loopCount ?? 8;
    final rounds = level.totalRounds > 0 ? level.totalRounds : 1;

    // Zero-duration phases are skipped entirely below — the cycle-diagram
    // index for each phase must skip them the exact same way, so it always
    // points at the right node in `level.cycleSteps` (built with the same
    // skip rule, see LevelData.custom).
    final phaseSeconds = [
      level.inhaleSec,
      level.holdInSec,
      level.exhaleSec,
      level.holdOutSec,
    ];
    final cycleIndices = <int?>[];
    var nextCycleIndex = 0;
    for (final sec in phaseSeconds) {
      cycleIndices.add(sec > 0 ? nextCycleIndex++ : null);
    }

    for (int r = 1; r <= rounds; r++) {
      if (!_isRunning) return;
      state = state.copyWith(
          currentRound: r, totalRounds: rounds, totalBreathsInRound: cycles);

      for (int i = 1; i <= cycles; i++) {
        if (!await _customPhase("session_inhale", level.inhaleSec,
            isBig: true, isInhale: true, index: i, cycles: cycles,
            cycleStepIndex: cycleIndices[0])) {
          return;
        }
        if (!await _customPhase("session_hold", level.holdInSec,
            isBig: true, isInhale: null, index: i, cycles: cycles,
            cycleStepIndex: cycleIndices[1])) {
          return;
        }
        if (!await _customPhase("session_exhale", level.exhaleSec,
            isBig: false, isInhale: false, index: i, cycles: cycles,
            cycleStepIndex: cycleIndices[2])) {
          return;
        }
        if (!await _customPhase("session_hold", level.holdOutSec,
            isBig: false, isInhale: null, index: i, cycles: cycles,
            cycleStepIndex: cycleIndices[3])) {
          return;
        }
      }
    }

    if (_isRunning) _finishSession();
  }

  /// Runs one phase of a custom pattern. Returns false if the session was
  /// stopped (so the caller should bail). A [seconds] of 0 is skipped.
  Future<bool> _customPhase(
    String labelKey,
    int seconds, {
    required bool isBig,
    required bool? isInhale,
    required int index,
    required int cycles,
    int? cycleStepIndex,
  }) async {
    if (seconds <= 0) return _isRunning;
    if (!_isRunning) return false;

    _updateCustomState(
      labelKey,
      "${seconds}s",
      isBig: isBig,
      isInhaling: isBig,
      duration: Duration(seconds: seconds),
      index: index,
      cycleStepIndex: cycleStepIndex,
    );
    if (isInhale != null) {
      _playBreathSignal(isInhale: isInhale, progress: 1.0);
    }
    await Future.delayed(Duration(seconds: seconds));
    return _isRunning;
  }

  // ==========================================================
  // GUIDED ROUTINE (lung-mobility/diaphragm exercises + packing)
  // ==========================================================
  /// Below this, a hold step is a transitional pause (e.g. "return to
  /// center"), not the moment the exercise is actually about — see the
  /// gong-gating comment in [_guidedStepPhase].
  static const int _kSignificantGuidedHoldThresholdSec = 5;

  /// Generalizes [_startCustom]'s "labeled, timed phases repeated over
  /// rounds" loop to a data-driven [GuidedStep] list instead of a hardcoded
  /// 4-phase inhale/hold/exhale/hold cycle — one engine for every guided
  /// lung-mobility exercise and packing, instead of a bespoke method each.
  Future<void> _startGuidedRoutine(LevelData level) async {
    final steps = level.guidedSteps ?? const <GuidedStep>[];
    if (steps.isEmpty) {
      if (_isRunning) _finishSession();
      return;
    }
    final rounds = level.totalRounds > 0 ? level.totalRounds : 1;
    // Only breath-phase steps belong in the "x/y" counter's denominator —
    // hold steps have no place in it (they show their own countdown), so
    // counting them too made the number skip past holds and never reach
    // "y/y" on an actual breath step.
    final breathStepsCount =
        steps.where((s) => s.phase == GuidedStepPhase.breath).length;

    for (int r = 1; r <= rounds; r++) {
      if (!_isRunning) return;
      state = state.copyWith(
          currentRound: r, totalRounds: rounds, totalBreathsInRound: breathStepsCount);

      var breathIndex = 0;
      for (int i = 0; i < steps.length; i++) {
        final step = steps[i];
        if (step.skipOnFinalRound && r == rounds) continue;
        if (step.phase == GuidedStepPhase.breath) breathIndex++;
        if (!await _guidedStepPhase(step, index: breathIndex)) return;
      }
    }

    if (_isRunning) _finishSession();
  }

  /// Runs one step of a guided routine. Returns false if the session was
  /// stopped meanwhile (caller bails). A step with `durationSec <= 0` is
  /// skipped. [GuidedStepPhase.hold] steps show a live countdown (reusing
  /// the `recovery` phase, same visual as freediving's rest/pause) instead
  /// of a silent delay, so a 25-second stretch hold doesn't look frozen.
  Future<bool> _guidedStepPhase(GuidedStep step, {required int index}) async {
    if (step.durationSec <= 0) return _isRunning;
    if (!_isRunning) return false;

    if (step.phase == GuidedStepPhase.hold) {
      var remaining = step.durationSec;
      // A quiet cue that a hold actually started — Wim Hof/freediving holds
      // get a gong+haptic on entry (_startRetention); guided-routine holds
      // had none, so a user with eyes closed got no signal the phase changed.
      // Gated on duration: a brief transitional pause (a 3s "return to
      // center", a 5s "rest, breathe normally") isn't the moment the
      // exercise is actually about, and firing the same dramatic cue for
      // those too dilutes what it means for the holds that really are.
      if (step.durationSec > _kSignificantGuidedHoldThresholdSec) {
        try { _hapticEngine.playRetentionPeak(); _audioManager.playGong(); } catch (_) {}
      }
      _skipCurrentGuidedHold = false;
      state = state.copyWith(
        customLabel: step.labelKey,
        customDescription: "${step.labelKey}_desc",
        // Null, not false — a fixed `false` short-circuits _Visuals.from
        // into treating this like a static custom-labelled step, which
        // froze the orb deflated for the whole hold. Null lets it fall
        // through to the same "breathe slowly in place" recovery-phase
        // animation freediving's rest/pause already uses.
        customIsBig: null,
        cycleStepIndex: step.cycleStepIndex,
        phase: SessionPhase.recovery(remaining: Duration(seconds: remaining)),
        // Only a real breath-hold (packing, Uddiyana) offers the early-abort
        // tap — a brief transitional pause ("return to center", "rest")
        // isn't a moment anyone needs to escape early from.
        isAbortableGuidedHold: step.recordAsRetention,
      );
      final holdStart = remaining;
      while (remaining > 0 && !_skipCurrentGuidedHold) {
        if (!_isRunning) return false;
        await Future.delayed(const Duration(seconds: 1));
        remaining--;
        if (_isRunning) {
          state = state.copyWith(
              phase: SessionPhase.recovery(remaining: Duration(seconds: remaining)));
        }
      }
      if (_isRunning && step.recordAsRetention) {
        state = state.copyWith(retentionLogs: [
          ...state.retentionLogs,
          Duration(seconds: holdStart - remaining),
        ]);
      }
      state = state.copyWith(isAbortableGuidedHold: false);
      return _isRunning;
    }

    _updateCustomState(
      step.labelKey,
      "${step.labelKey}_desc",
      isBig: step.isInhale ?? true,
      isInhaling: step.isInhale ?? true,
      duration: Duration(seconds: step.durationSec),
      index: index,
      cycleStepIndex: step.cycleStepIndex,
    );
    if (step.isInhale != null) {
      _playBreathSignal(isInhale: step.isInhale!, progress: 1.0);
    }
    await Future.delayed(Duration(seconds: step.durationSec));
    return _isRunning;
  }

  // ==========================================================
  // 1. WIM HOF
  // ==========================================================
  void _startWimHof(LevelData level) {
    state = state.copyWith(
      customLabel: null,
      customDescription: null,
      customIsBig: null,
      cycleStepIndex: 0,
      phase: SessionPhase.breathing(
          breathIndex: 1,
          isInhaling: false,
          currentBreathDuration: level.breathPace
      ),
      currentRound: 1,
    );
    Future.delayed(const Duration(milliseconds: 50), _runBreathingLoop);
  }

  Future<void> _runBreathingLoop() async {
    if (_currentLevel == null) return;
    final pace = _currentLevel!.breathPace;

    for (int i = 1; i <= _currentLevel!.totalBreaths; i++) {
      if (!_isRunning) return;

      // Ensure the phase has not been manually advanced (e.g., by finishing retention early).
      if (!state.phase.maybeMap(breathing: (_) => true, orElse: () => false)) return;

      final Duration duration = RampUpCalculator.getDuration(i - 1, pace);
      final half = duration ~/ 2;

      state = state.copyWith(phase: SessionPhase.breathing(breathIndex: i, isInhaling: true, currentBreathDuration: duration));
      _playBreathSignal(isInhale: true, progress: i / _currentLevel!.totalBreaths);
      await Future.delayed(half);

      if (!_isRunning) return;

      state = state.copyWith(phase: SessionPhase.breathing(breathIndex: i, isInhaling: false, currentBreathDuration: duration));
      _playBreathSignal(isInhale: false, progress: 1.0);
      await Future.delayed(half);
    }

    if (_isRunning) _startRetention();
  }

  void _startRetention() {
    try { _hapticEngine.playRetentionPeak(); _audioManager.playGong(); _audioManager.duckDrone(); } catch (_) {}

    final start = DateTime.now();
    state = state.copyWith(
        cycleStepIndex: 1, phase: SessionPhase.retention(elapsed: Duration.zero));

    _phaseTimer?.cancel();
    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isRunning) { t.cancel(); return; }
      final elapsed = DateTime.now().difference(start);
      state = state.copyWith(phase: SessionPhase.retention(elapsed: elapsed));

      if (state.isGhostMode && elapsed.inSeconds % 15 == 0 && elapsed.inSeconds > 0) {
        _hapticEngine.playHeartbeat();
      }
    });
  }

  void finishRetention() {
    // In a CO2/O2 table, the same "tap to end" gesture doubles as the
    // low-friction "I need to breathe now" early-abort for the current round
    // — a different continuation (its own rest duration, or ending the whole
    // table) than Wim Hof's fixed 15s recovery.
    if (_currentLevel?.type.isFreedivingTable ?? false) {
      // Only the hold itself is abortable — during breathing (inhale/exhale)
      // or a countdown pause, phase is never `retention`, so this branch (and
      // the UI gesture that calls it) is simply inert at those moments.
      state.phase.maybeWhen(
        retention: (_) => _finishFreedivingHold(completedFull: false),
        orElse: () {},
      );
      return;
    }

    _phaseTimer?.cancel();
    state.phase.maybeWhen(
      retention: (elapsed) {
        final logs = List<Duration>.from(state.retentionLogs)..add(elapsed);
        state = state.copyWith(retentionLogs: logs);
      },
      orElse: () {},
    );
    _startRecovery();
  }

  /// Early-abort for a guided-routine breath-hold (packing, Uddiyana) —
  /// the counterpart to [finishRetention] for holds that run through
  /// `_guidedStepPhase`'s `recovery`-phase countdown instead of the
  /// `retention` phase. A no-op unless [SessionState.isAbortableGuidedHold]
  /// is actually true, so the UI gesture that calls this is always safe to
  /// wire up unconditionally.
  void endGuidedHoldEarly() {
    if (!state.isAbortableGuidedHold) return;
    _skipCurrentGuidedHold = true;
  }

  void _startRecovery() {
    try { _audioManager.playInhale(); _audioManager.unduckDrone(); } catch (_) {}
    // Recovery is a fixed 15s at every level/round by classic-method
    // design, plus this level's own `finalRoundExtraRecoverySec` (only
    // guru sets one, non-zero) on its own final round specifically — not a
    // change to the method's core rhythm everywhere else.
    final level = _currentLevel!;
    final isFinalRound = state.currentRound == level.totalRounds - 1;
    int sec = 15 + (isFinalRound ? level.finalRoundExtraRecoverySec : 0);
    state = state.copyWith(
        cycleStepIndex: 2, phase: SessionPhase.recovery(remaining: Duration(seconds: sec)));

    _phaseTimer?.cancel();
    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isRunning) { t.cancel(); return; }
      sec--;
      state = state.copyWith(phase: SessionPhase.recovery(remaining: Duration(seconds: sec)));

      if (sec == 2) try { _audioManager.playExhale(); } catch (_) {}

      if (sec <= 0) {
        t.cancel();
        _nextRound();
      }
    });
  }

  Future<void> _nextRound() async {
    if (state.currentRound >= _currentLevel!.totalRounds) {
      await _wimHofCooldown();
      if (_isRunning) _finishSession();
    } else {
      state = state.copyWith(
        currentRound: state.currentRound + 1,
        cycleStepIndex: 0,
        phase: SessionPhase.breathing(breathIndex: 1, isInhaling: false, currentBreathDuration: _currentLevel!.breathPace),
      );
      Future.delayed(const Duration(milliseconds: 50), _runBreathingLoop);
    }
  }

  /// A brief wind-down after the final round's recovery — previously the
  /// session went straight from a full cycle of hyperventilation+retention
  /// to the summary screen with nothing in between. A few slow, unpaced
  /// breaths give the body an actual transition instead of an abrupt stop.
  Future<void> _wimHofCooldown() async {
    const cycles = 3;
    const phaseDuration = Duration(seconds: 4);
    for (int i = 1; i <= cycles; i++) {
      if (!_isRunning) return;
      _updateCustomState(
        "session_inhale",
        "session_cooldown_desc",
        isBig: true,
        isInhaling: true,
        duration: phaseDuration,
        index: i,
        cycleStepIndex: null,
      );
      _playBreathSignal(isInhale: true, progress: 1.0);
      await Future.delayed(phaseDuration);
      if (!_isRunning) return;

      _updateCustomState(
        "session_exhale",
        "session_cooldown_desc",
        isBig: false,
        isInhaling: false,
        duration: phaseDuration,
        index: i,
        cycleStepIndex: null,
      );
      _playBreathSignal(isInhale: false, progress: 1.0);
      await Future.delayed(phaseDuration);
    }
  }

  // ==========================================================
  // 2. BOX BREATHING (SNIPER)
  // ==========================================================
  Future<void> _startBoxBreathing(LevelData level) => _runPhaseCycle(
        loops: level.loopCount ?? 16,
        resetToSingleRound: true,
        phases: const [
          _BreathPhase(
            label: "session_inhale",
            desc: "session_box_inhale_desc",
            isBig: true,
            isInhaling: true,
            duration: Duration(seconds: 4),
            signal: true,
          ),
          _BreathPhase(
            label: "session_hold",
            desc: "session_box_hold_full_desc",
            isBig: true,
            isInhaling: true,
            duration: Duration(seconds: 4),
            // A light cue that the hold phase actually started — every
            // other "hold" moment in the app signals its start; box
            // breathing's two holds had none, leaving eyes-closed practice
            // with no feedback that the phase changed.
            haptic: true,
          ),
          _BreathPhase(
            label: "session_exhale",
            desc: "session_box_exhale_desc",
            isBig: false,
            isInhaling: false,
            duration: Duration(seconds: 4),
            signal: false,
          ),
          _BreathPhase(
            label: "session_hold",
            desc: "session_box_hold_empty_desc",
            isBig: false,
            isInhaling: false,
            duration: Duration(seconds: 4),
            haptic: true,
          ),
        ],
      );

  // ==========================================================
  // 3. RELAX 4-7-8
  // ==========================================================
  Future<void> _startRelax478(LevelData level) => _runPhaseCycle(
        loops: level.loopCount ?? 32,
        phases: const [
          _BreathPhase(
            label: "session_inhale",
            desc: "session_relax_inhale_desc",
            isBig: true,
            isInhaling: true,
            duration: Duration(seconds: 4),
            signal: true,
          ),
          _BreathPhase(
            label: "session_hold",
            desc: "session_relax_hold_desc",
            isBig: true,
            isInhaling: true,
            duration: Duration(seconds: 7),
            haptic: true,
          ),
          _BreathPhase(
            label: "session_exhale",
            desc: "session_relax_exhale_desc",
            isBig: false,
            isInhaling: false,
            duration: Duration(seconds: 8),
            signal: false,
          ),
        ],
      );

  /// Shared driver for a fixed breathing pattern (box breathing, 4-7-8)
  /// repeated for [loops] cycles — each cycle steps through [phases] in
  /// order, updating the session UI, playing the phase's cue (a breath
  /// signal or a plain haptic tick), and waiting out its duration.
  Future<void> _runPhaseCycle({
    required int loops,
    required List<_BreathPhase> phases,
    bool resetToSingleRound = false,
  }) async {
    for (int i = 1; i <= loops; i++) {
      if (!_isRunning) return;
      if (resetToSingleRound) {
        state = state.copyWith(currentRound: 1, totalRounds: 1);
      }
      for (var stepIndex = 0; stepIndex < phases.length; stepIndex++) {
        final phase = phases[stepIndex];
        _updateCustomState(
          phase.label,
          phase.desc,
          isBig: phase.isBig,
          isInhaling: phase.isInhaling,
          duration: phase.duration,
          index: i,
          cycleStepIndex: stepIndex,
        );
        if (phase.signal != null) {
          _playBreathSignal(isInhale: phase.signal!, progress: 1.0);
        }
        if (phase.haptic) {
          try { _hapticEngine.playTick(); } catch (_) {}
        }
        await Future.delayed(phase.duration);
        // Matches the original hand-rolled loops: skipping the check after
        // a cycle's last phase is fine — the next cycle's top-of-loop check
        // (or, on the final cycle, nothing at all) covers it.
        if (stepIndex < phases.length - 1 && !_isRunning) return;
      }
    }
    _finishSession();
  }

  // ==========================================================
  // 4. FIRE BREATHING (BHASTRIKA)
  // ==========================================================
  /// Kapalabhati/Bhastrika's own reference pattern: a short series of fast
  /// breaths, then a full inhale, a hold, an exhale, a rest — repeated for
  /// [LevelData.totalRounds] rounds — rather than one uninterrupted block of
  /// rapid breathing for the whole session (the previous implementation),
  /// which meant a much longer continuous hyperventilation exposure than
  /// the technique's own pattern and no natural point to reassess mid-way.
  Future<void> _startFireBreathing(LevelData level) async {
    final rounds = level.totalRounds > 0 ? level.totalRounds : 3;
    final breathsPerRound = level.totalBreaths > 0 ? level.totalBreaths : 30;
    final tickDuration =
        level.breathPace > Duration.zero ? level.breathPace : const Duration(milliseconds: 1400);
    final halfTick = tickDuration ~/ 2;
    const holdSec = 12;
    const restSec = 15;

    for (int r = 1; r <= rounds; r++) {
      if (!_isRunning) return;
      state = state.copyWith(
          currentRound: r, totalRounds: rounds, totalBreathsInRound: breathsPerRound);

      // The fast-breathing series. Kapalabhati/Bhastrika is exhale-active,
      // inhale-passive (the belly pump is on the exhale) — kept as an
      // explicit hint under the label, same as before this restructure.
      for (int i = 1; i <= breathsPerRound; i++) {
        if (!_isRunning) return;
        _updateCustomState(
          "session_inhale",
          "session_fire_inhale_desc",
          isBig: true,
          isInhaling: true,
          duration: halfTick,
          index: i,
          cycleStepIndex: 0,
        );
        try {
          _hapticEngine.playInhalePulse(i / breathsPerRound);
          _audioManager.playInhale();
        } catch (_) {}
        await Future.delayed(halfTick);
        if (!_isRunning) return;

        _updateCustomState(
          "session_exhale",
          "session_fire_exhale_desc",
          isBig: false,
          isInhaling: false,
          duration: halfTick,
          index: i,
          cycleStepIndex: 0,
        );
        try {
          _hapticEngine.playTick();
          _audioManager.playExhale();
        } catch (_) {}
        await Future.delayed(halfTick);
      }
      if (!_isRunning) return;

      // Full inhale before the hold.
      _updateCustomState(
        "session_inhale",
        "session_fire_full_inhale_desc",
        isBig: true,
        isInhaling: true,
        duration: const Duration(seconds: 3),
        index: r,
        cycleStepIndex: 1,
      );
      _playBreathSignal(isInhale: true, progress: 1.0);
      await Future.delayed(const Duration(seconds: 3));
      if (!await _fireHold(holdSec)) return;
      if (!_isRunning) return;

      // Exhale.
      _updateCustomState(
        "session_exhale",
        "session_fire_exhale_desc",
        isBig: false,
        isInhaling: false,
        duration: const Duration(seconds: 2),
        index: r,
        cycleStepIndex: 3,
      );
      _playBreathSignal(isInhale: false, progress: 1.0);
      await Future.delayed(const Duration(seconds: 2));

      // Rest before the next round — none after the last one.
      if (r < rounds) {
        if (!_isRunning) return;
        var remaining = restSec;
        state = state.copyWith(
          customLabel: "session_recovery",
          customDescription: null,
          customIsBig: null,
          cycleStepIndex: 4,
          phase: SessionPhase.recovery(remaining: Duration(seconds: remaining)),
        );
        while (remaining > 0) {
          if (!_isRunning) return;
          await Future.delayed(const Duration(seconds: 1));
          remaining--;
          if (_isRunning) {
            state = state.copyWith(
                phase: SessionPhase.recovery(remaining: Duration(seconds: remaining)));
          }
        }
      }
    }
    if (_isRunning) _finishSession();
  }

  /// Fire breathing's post-round hold — a fixed countdown with the same
  /// early-abort tap a real breath-hold anywhere else in the app offers,
  /// reusing [_skipCurrentGuidedHold]/[endGuidedHoldEarly] directly rather
  /// than a second abort mechanism just for this one caller.
  Future<bool> _fireHold(int seconds) async {
    _skipCurrentGuidedHold = false;
    var remaining = seconds;
    state = state.copyWith(
      customLabel: "session_hold",
      customDescription: null,
      customIsBig: null,
      cycleStepIndex: 2,
      phase: SessionPhase.recovery(remaining: Duration(seconds: remaining)),
      isAbortableGuidedHold: true,
    );
    try {
      _hapticEngine.playRetentionPeak();
      _audioManager.playGong();
    } catch (_) {}
    while (remaining > 0 && !_skipCurrentGuidedHold) {
      if (!_isRunning) return false;
      await Future.delayed(const Duration(seconds: 1));
      remaining--;
      if (_isRunning) {
        state = state.copyWith(
            phase: SessionPhase.recovery(remaining: Duration(seconds: remaining)));
      }
    }
    state = state.copyWith(isAbortableGuidedHold: false);
    return _isRunning;
  }

  // ==========================================================
  // HELPERS & TEARDOWN
  // ==========================================================

  void _updateCustomState(String labelKey, String? descKey, {
    required bool isBig,
    required bool isInhaling,
    required Duration duration,
    required int index,
    int? cycleStepIndex,
  }) {
    state = state.copyWith(
      customLabel: labelKey,
      customDescription: descKey,
      customIsBig: isBig,
      cycleStepIndex: cycleStepIndex,
      phase: SessionPhase.breathing(
        breathIndex: index,
        isInhaling: isInhaling,
        currentBreathDuration: duration,
      ),
    );
  }

  void _playBreathSignal({required bool isInhale, required double progress}) {
    try {
      if (isInhale) {
        _hapticEngine.playInhalePulse(progress);
        _audioManager.playInhale();
      } else {
        _hapticEngine.playTick();
        _audioManager.playExhale();
      }
    } catch (_) {}
  }

  // Finalize the session and prepare for navigation to the summary screen.
  void _finishSession() {
    _sessionTimer.stop();
    final duration = _sessionTimer.elapsed;
    final level = _currentLevel;
    // Persist the rounds actually completed (not the planned total) so an
    // early finish never inflates history/XP.
    final totalRounds = state.currentRound;
    final retentionLogs = List<Duration>.from(state.retentionLogs);
    final freedivingRoundsCompleted = _freedivingRoundsCompleted;
    final contractionsByRound = List<RoundContraction>.from(_contractionsByRound);

    // Set before the state change below so it's already visible to the
    // summary screen's very first build after navigation.
    lastFinishedExerciseType = level?.type;
    lastFinishedLevelKey = level?.key;
    lastFreedivingContractionSummary = (level?.type.isFreedivingTable ?? false)
        ? RoundContractionSummary.fromRounds(contractionsByRound)
        : null;
    // Captured into a local so the background persist below completes
    // *this* session's own completer specifically — reading back through
    // `_lastSessionIdCompleter` (a mutable field) at completion time would
    // instead complete whatever the *field* currently holds, which a
    // second session finishing first (before this one's persist resolves)
    // would have already reassigned. That mixed up which session's id
    // reached which summary screen's RPE prompt.
    final completer = Completer<int?>();
    _lastSessionIdCompleter = completer;

    state = state.copyWith(
      phase: const SessionPhase.finished(),
      sessionDuration: duration,
    );

    // The UI has already advanced to the summary; persist results in the
    // background so a slow disk write never blocks the transition.
    if (level != null) {
      unawaited(_persistSessionResults(level, duration, totalRounds, retentionLogs,
          freedivingRoundsCompleted, contractionsByRound, completer));
    } else {
      completer.complete(null);
    }

    if (_plannedSessionId case final id?) {
      unawaited(_ref.read(plannerRepositoryProvider).completePlan(id));
    }

    stopSession(resetState: false);
  }

  Future<void> _persistSessionResults(
    LevelData level,
    Duration duration,
    int totalRounds,
    List<Duration> retentionLogs,
    int freedivingRoundsCompleted,
    List<RoundContraction> contractionsByRound,
    Completer<int?> completer,
  ) async {
    try {
      final totalRetention =
          retentionLogs.fold<int>(0, (sum, d) => sum + d.inSeconds);

      final isFreedivingTable = level.type.isFreedivingTable;

      // Weekly discipline-diversity bonus: Twoja Ścieżka's own weekly plan
      // already deliberately interleaves Wim Hof/CO2/O2/cold shower/
      // mobility, but XP never reflected that variety — training the same
      // single discipline all week earned exactly as much as spreading it
      // across several. `disciplineFamilyFor` returning null (a level this
      // session's own family can't be placed for, which shouldn't happen
      // for a real session) safely just contributes nothing extra.
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentSessions = await _ref.read(sessionRepositoryProvider).getAllSessions();
      final familiesThisWeek = <String>{
        for (final s in recentSessions)
          if (s.timestamp.isAfter(weekAgo))
            if (disciplineFamilyFor(s.levelKey) case final family?) family,
        if (disciplineFamilyFor(level.key) case final family?) family,
      };
      final diversityMultiplier = diversityXpMultiplier(familiesThisWeek.length);

      // A CO2/O2 table's "retention" is the sum of several near-maximal
      // breath-holds and would otherwise dwarf every other exercise's XP
      // (the generic formula is retentionSeconds * 2, uncapped) — dampen the
      // XP-calculation input for these two types only, a little. This used
      // to dampen by *0.3, which had the opposite effect from what was
      // intended: a full CO2/O2 table worked out to the worst XP/second of
      // any exercise in the app (~0.27 XP/s, against ~1.27 XP/s for a Wim
      // Hof guru session of comparable length) despite carrying the
      // highest real risk — the exact opposite of what the XP curve should
      // reward. 0.9 keeps a token safety margin against a pathologically
      // long custom table dominating XP outright, without punishing the
      // exercise that's actually asking the most of the user. The full,
      // honest hold time is still stored as the session's real retentionSec
      // below regardless of this multiplier.
      final gamification = _ref.read(gamificationServiceProvider);
      // Guided routines (lung-mobility exercises + packing), box breathing,
      // and 4-7-8 have no meaningful `totalBreaths`/retention of their own
      // — `levels.dart` never sets `totalBreaths` for any of them, so the
      // generic breathCount*multiplier formula below always evaluated to a
      // flat 0 XP, regardless of how long or how many reps were actually
      // completed. Fire breathing is grouped in here too even though it now
      // has a real per-round `totalBreaths` (since its round restructure)
      // — its XP is still better driven by real elapsed time than by a
      // breath count that no longer scales with total session length the
      // way it used to. Award flat XP scaled by real elapsed time instead
      // (same helper cold shower already uses for a duration-less
      // activity, just with a computed amount instead of a constant).
      final noNaturalBreathCount = level.type == ExerciseType.guidedRoutine ||
          level.type == ExerciseType.boxBreathing ||
          level.type == ExerciseType.relax478 ||
          level.type == ExerciseType.fireBreathing;
      final xpResult = noNaturalBreathCount
          ? await gamification.awardFlatXp(
              // Real recorded holds inside a guided routine (packing's
              // hold, Uddiyana's vacuum — the ones with recordAsRetention:
              // true) used to earn nothing beyond the flat per-second rate
              // every step of the routine already got, even though the
              // hold is the one part of the exercise actually carrying its
              // own risk. Zero for box/relax/fire, which never log a
              // retention at all, so this is additive only where it should
              // be. `totalRetention` is already computed above.
              (duration.inSeconds * 0.5 + totalRetention * 1.0)
                  .round()
                  .clamp(1, 1000),
              bonusMultiplier: diversityMultiplier,
            )
          : await gamification.updateXpAndLevel(
              breathCount: level.totalBreaths * totalRounds,
              // A freediving table's breathCount is always 0 above (no
              // natural breath count for a breath-hold table) — retention
              // alone drives its XP. `multiplier` only ever affects Wim
              // Hof/custom sessions, whose breathCount is real; it used to
              // read `isFreedivingTable ? 0.5 : 1.5` as if it dampened
              // freediving XP, but multiplied against an always-0
              // breathCount, that branch never did anything.
              retentionSeconds: isFreedivingTable
                  ? (totalRetention * 0.9).round()
                  : totalRetention,
              multiplier: 1.5,
              bonusMultiplier: diversityMultiplier,
            );
      justLeveledUpTo = xpResult.leveledUp ? xpResult.newLevel : null;
      final streakResult = await gamification.updateStreak();
      justUsedStreakGrace = streakResult.graceUsed;

      // Custom sessions share one key per type ('custom', 'custom_freediving');
      // persist their user-given name instead so history and stats show the
      // real name, not the generic shared key.
      final levelKey = level.type == ExerciseType.custom ||
              level.type == ExerciseType.customFreedivingTable
          ? level.title
          : level.key;

      final sessionId = await _ref.read(sessionRepositoryProvider).addSession(
            levelKey: levelKey,
            timestamp: DateTime.now(),
            durationSec: duration.inSeconds,
            rounds: totalRounds,
            retentionSec: totalRetention,
            xpEarned: xpResult.xpEarned,
          );
      if (!completer.isCompleted) {
        completer.complete(sessionId);
      }

      if (isFreedivingTable && level.freedivingRounds != null) {
        // Custom tables carry no PB cap, so freedivingPbUsedSec is never set
        // for them — logged with a 0 sentinel instead of being excluded
        // entirely, so they still count toward history/progress and can get
        // a post-session symptom check-in like every other freediving table.
        final tableType = level.type == ExerciseType.co2Table
            ? FreedivingTableType.co2
            : level.type == ExerciseType.o2Table
                ? FreedivingTableType.o2
                : FreedivingTableType.custom;
        await _ref.read(freedivingRepositoryProvider).logTableSession(
              tableType: tableType,
              pbUsedSec: level.freedivingPbUsedSec ?? 0,
              rounds: level.freedivingRounds!,
              roundsCompleted: freedivingRoundsCompleted,
              durationSec: duration.inSeconds,
              contractions: contractionsByRound,
            );
      } else if (level.recordsSafetyLog && retentionLogs.isNotEmpty) {
        // Packing/Uddiyana carry the same real risks the audit called out
        // for CO2/O2 tables (barotrauma, gas embolism, blackout for
        // packing; a genuine vacuum hold for Uddiyana) — they get the same
        // safety-signal logging even though they're a guidedRoutine, not a
        // table, and have no PB of their own to log against. Only the
        // session's first hold is logged (Uddiyana has one per round,
        // packing just one total) — this only needs to be *a*
        // representative sample for the post-session symptom check-in to
        // attach to, not a complete record of every hold.
        await _ref.read(freedivingRepositoryProvider).logTableSession(
              tableType: level.key == 'freediving_packing'
                  ? FreedivingTableType.packing
                  : FreedivingTableType.uddiyana,
              pbUsedSec: 0,
              rounds: [
                BreathHoldRound(
                    index: 1,
                    apneaSec: retentionLogs.first.inSeconds,
                    restSec: 0)
              ],
              roundsCompleted: 1,
              durationSec: duration.inSeconds,
            );
      }

      refreshDailyReminderContent();
    } catch (e, st) {
      developer.log('Failed to persist session results',
          name: 'SessionNotifier', error: e, stackTrace: st);
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }
  }

  /// Refreshes the recurring daily reminder's body to reflect today's
  /// "Twoja Ścieżka" suggestion. Called right after a session finishes (the
  /// moment most likely to have just changed it) and also from the app root
  /// on every foreground resume — otherwise a user who doesn't finish a
  /// session for a few days would keep seeing an already-stale plan summary
  /// in the alarm's text indefinitely.
  ///
  /// This ONLY updates the content of an alarm the user has already turned
  /// on — it never enables or disables the reminder itself. That distinction
  /// matters: an earlier bug had a splash-screen guard silently
  /// re-scheduling this same alarm on every cold start regardless of the
  /// user's real preference, with no way to turn it off (see
  /// SettingsNotifier's `_kMigratedV2` migration). `setDailyReminderEnabled`
  /// remains the only place that can flip it on/off; this just keeps an
  /// already-on alarm's text current.
  void refreshDailyReminderContent() {
    try {
      if (!_ref.read(settingsProvider).dailyReminderEnabled) return;
      final plan = _ref.read(weeklyPlanProvider);
      if (plan == null) return;
      final todayActions = plan.days.first.actions;

      final languageCode = _ref.read(localeProvider).languageCode;
      final title = L10n.getForLocale(languageCode, 'notif_reminder_title');
      final body = todaySummaryLabelForLocale(languageCode, todayActions);
      unawaited(_ref.read(notificationServiceProvider).scheduleDailyReminder(
            title: title,
            body: body,
          ));
    } catch (e, st) {
      developer.log('Failed to refresh daily reminder content',
          name: 'SessionNotifier', error: e, stackTrace: st);
    }
  }


  // Clean up resources and timers when the session is explicitly stopped or cancelled.
  void stopSession({bool resetState = true}) {
    _isSessionActive = false;
    _sessionTimer.stop();
    _phaseTimer?.cancel();
    WakelockPlus.disable();
    _audioManager.stopDrone();
    _freedivingRounds = null;
    _freedivingRoundIndex = 0;
    _freedivingRoundsCompleted = 0;
    _freedivingPauseSkippable = false;
    _freedivingSkipRequested = false;
    _lastRoundMissed = false;
    _currentHoldStart = null;
    _currentRoundContractions = [];
    _contractionsByRound.clear();

    // Reset the state to clear the UI and prevent stale data from persisting.
    if (resetState) state = SessionState.initial();
  }

  void toggleGhostMode() {
    // The resulting dimmed screen is deliberately subtle, which meant a
    // double-tap gave no confirmation it even registered — a light haptic
    // fires every time regardless of the (barely visible) visual change.
    try {
      _hapticEngine.playTick();
    } catch (_) {}
    state = state.copyWith(isGhostMode: !state.isGhostMode);
  }
}