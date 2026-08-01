import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/core/audio/audio_manager.dart';
import 'package:okrutnik_breath/core/haptic/haptic_engine.dart';
import 'package:okrutnik_breath/logic/notifiers/ramp_up_calculator.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/logic/providers/settings_provider.dart';
import 'package:okrutnik_breath/logic/states/session_state.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  final audioManager = ref.read(audioManagerProvider);
  return SessionNotifier(audioManager, ref);
});

class SessionNotifier extends StateNotifier<SessionState> {
  final AudioManager _audioManager;
  final HapticEngine _hapticEngine = HapticEngine();
  final Ref _ref;

  final Stopwatch _sessionTimer = Stopwatch();

  LevelData? _currentLevel;
  bool _isSessionActive = false;
  Timer? _phaseTimer;

  /// True only while a session is active *and* this notifier is still mounted.
  /// Writing `state` after disposal throws, so every async continuation guards
  /// on this before touching state.
  bool get _isRunning => _isSessionActive && mounted;

  SessionNotifier(this._audioManager, this._ref) : super(SessionState.initial());

  Future<void> startSession(LevelData level) async {
    // Ignore a duplicate start while a session is already running (e.g. a
    // double-tapped Start button or the widget delivering its launch twice) —
    // otherwise two breathing loops run concurrently and cues double up.
    if (_isSessionActive) return;

    _isSessionActive = true;
    _currentLevel = level;

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

    int totalBreaths = level.totalBreaths;
    if (level.type == ExerciseType.fireBreathing) {
      final duration = level.totalDuration ?? const Duration(minutes: 3);
      // Approximate the breath count for the progress bar, assuming a ~700ms pace per phase.
      totalBreaths = (duration.inMilliseconds / 1400).floor();
    } else if (level.type == ExerciseType.boxBreathing) {
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
    }
  }

  // ==========================================================
  // CUSTOM (USER-DEFINED PATTERN)
  // ==========================================================
  Future<void> _startCustom(LevelData level) async {
    final cycles = level.loopCount ?? 8;
    final rounds = level.totalRounds > 0 ? level.totalRounds : 1;

    for (int r = 1; r <= rounds; r++) {
      if (!_isRunning) return;
      state = state.copyWith(
          currentRound: r, totalRounds: rounds, totalBreathsInRound: cycles);

      for (int i = 1; i <= cycles; i++) {
        if (!await _customPhase(
            "session_inhale", level.inhaleSec, isBig: true, isInhale: true, index: i, cycles: cycles)) {
          return;
        }
        if (!await _customPhase(
            "session_hold", level.holdInSec, isBig: true, isInhale: null, index: i, cycles: cycles)) {
          return;
        }
        if (!await _customPhase(
            "session_exhale", level.exhaleSec, isBig: false, isInhale: false, index: i, cycles: cycles)) {
          return;
        }
        if (!await _customPhase(
            "session_hold", level.holdOutSec, isBig: false, isInhale: null, index: i, cycles: cycles)) {
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
    );
    if (isInhale != null) {
      _playBreathSignal(isInhale: isInhale, progress: 1.0);
    }
    await Future.delayed(Duration(seconds: seconds));
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
    state = state.copyWith(phase: SessionPhase.retention(elapsed: Duration.zero));

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

  void _startRecovery() {
    try { _audioManager.playInhale(); _audioManager.unduckDrone(); } catch (_) {}
    int sec = 15;
    state = state.copyWith(phase: SessionPhase.recovery(remaining: Duration(seconds: sec)));

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

  void _nextRound() {
    if (state.currentRound >= _currentLevel!.totalRounds) {
      _finishSession();
    } else {
      state = state.copyWith(
        currentRound: state.currentRound + 1,
        phase: SessionPhase.breathing(breathIndex: 1, isInhaling: false, currentBreathDuration: _currentLevel!.breathPace),
      );
      Future.delayed(const Duration(milliseconds: 50), _runBreathingLoop);
    }
  }

  // ==========================================================
  // 2. BOX BREATHING (SNIPER)
  // ==========================================================
  Future<void> _startBoxBreathing(LevelData level) async {
    final int loops = level.loopCount ?? 16;

    for (int i = 1; i <= loops; i++) {
      if (!_isRunning) return;
      state = state.copyWith(currentRound: 1, totalRounds: 1);

      _updateCustomState("session_inhale", "session_box_inhale_desc", isBig: true, isInhaling: true, duration: const Duration(seconds: 4), index: i);
      _playBreathSignal(isInhale: true, progress: 1.0);
      await Future.delayed(const Duration(seconds: 4));
      if (!_isRunning) return;

      _updateCustomState("session_hold", "session_box_hold_full_desc", isBig: true, isInhaling: true, duration: const Duration(seconds: 4), index: i);
      await Future.delayed(const Duration(seconds: 4));
      if (!_isRunning) return;

      _updateCustomState("session_exhale", "session_box_exhale_desc", isBig: false, isInhaling: false, duration: const Duration(seconds: 4), index: i);
      _playBreathSignal(isInhale: false, progress: 1.0);
      await Future.delayed(const Duration(seconds: 4));
      if (!_isRunning) return;

      _updateCustomState("session_hold", "session_box_hold_empty_desc", isBig: false, isInhaling: false, duration: const Duration(seconds: 4), index: i);
      await Future.delayed(const Duration(seconds: 4));
    }
    _finishSession();
  }

  // ==========================================================
  // 3. RELAX 4-7-8
  // ==========================================================
  Future<void> _startRelax478(LevelData level) async {
    final int loops = level.loopCount ?? 32;

    for (int i = 1; i <= loops; i++) {
      if (!_isRunning) return;

      _updateCustomState("session_inhale", "session_relax_inhale_desc", isBig: true, isInhaling: true, duration: const Duration(seconds: 4), index: i);
      _playBreathSignal(isInhale: true, progress: 1.0);
      await Future.delayed(const Duration(seconds: 4));
      if (!_isRunning) return;

      _updateCustomState("session_hold", "session_relax_hold_desc", isBig: true, isInhaling: true, duration: const Duration(seconds: 7), index: i);
      await Future.delayed(const Duration(seconds: 7));
      if (!_isRunning) return;

      _updateCustomState("session_exhale", "session_relax_exhale_desc", isBig: false, isInhaling: false, duration: const Duration(seconds: 8), index: i);
      _playBreathSignal(isInhale: false, progress: 1.0);
      await Future.delayed(const Duration(seconds: 8));
    }
    _finishSession();
  }

  // ==========================================================
  // 4. FIRE BREATHING (BHASTRIKA)
  // ==========================================================
  void _startFireBreathing(LevelData level) {
    final totalDuration = level.totalDuration ?? const Duration(minutes: 3);
    final tickDuration = const Duration(milliseconds: 700);

    final endTime = DateTime.now().add(totalDuration);
    int cycle = 1;
    bool isInhaling = true;

    // Use Timer.periodic for a stable timeline and smooth UI updates during rapid intervals.
    _phaseTimer?.cancel();
    _phaseTimer = Timer.periodic(tickDuration, (timer) {
      if (!_isRunning) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final remaining = endTime.difference(now);

      if (remaining.isNegative) {
        timer.cancel();
        _finishSession();
        return;
      }

      state = state.copyWith(
        customLabel: isInhaling ? "session_inhale" : "session_exhale",
        customDescription: isInhaling ? "session_fire_inhale_desc" : "session_fire_exhale_desc",
        customIsBig: isInhaling,
        phase: SessionPhase.breathing(
            breathIndex: cycle,
            isInhaling: isInhaling,
            currentBreathDuration: tickDuration
        ),
      );

      if (isInhaling) {
        // One full breath cycle is 1400ms (two 700ms ticks), and `cycle` only
        // advances per inhale — so the ramp denominator must match that cadence.
        _hapticEngine.playInhalePulse(cycle / (totalDuration.inMilliseconds / 1400));
        try { _audioManager.playInhale(); } catch (_) {}
      } else {
        _hapticEngine.playTick();
        try { _audioManager.playExhale(); } catch (_) {}
      }

      isInhaling = !isInhaling;
      if (isInhaling) {
        cycle++;
      }
    });
  }

  // ==========================================================
  // HELPERS & TEARDOWN
  // ==========================================================

  void _updateCustomState(String labelKey, String descKey, {
    required bool isBig,
    required bool isInhaling,
    required Duration duration,
    required int index,
  }) {
    state = state.copyWith(
      customLabel: labelKey,
      customDescription: descKey,
      customIsBig: isBig,
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

    state = state.copyWith(
      phase: const SessionPhase.finished(),
      sessionDuration: duration,
    );

    // The UI has already advanced to the summary; persist results in the
    // background so a slow disk write never blocks the transition.
    if (level != null) {
      unawaited(
          _persistSessionResults(level, duration, totalRounds, retentionLogs));
    }

    stopSession(resetState: false);
  }

  Future<void> _persistSessionResults(
    LevelData level,
    Duration duration,
    int totalRounds,
    List<Duration> retentionLogs,
  ) async {
    try {
      final totalRetention =
          retentionLogs.fold<int>(0, (sum, d) => sum + d.inSeconds);

      final gamification = _ref.read(gamificationServiceProvider);
      final xpEarned = await gamification.updateXpAndLevel(
        breathCount: level.totalBreaths * totalRounds,
        retentionSeconds: totalRetention,
        multiplier: 1.5,
      );
      await gamification.updateStreak();

      // Custom sessions share the key 'custom'; persist their user-given name
      // instead so history and stats show the real name, not "custom".
      final levelKey =
          level.type == ExerciseType.custom ? level.title : level.key;

      await _ref.read(sessionRepositoryProvider).addSession(
            levelKey: levelKey,
            timestamp: DateTime.now(),
            durationSec: duration.inSeconds,
            rounds: totalRounds,
            retentionSec: totalRetention,
            xpEarned: xpEarned,
          );
    } catch (e, st) {
      developer.log('Failed to persist session results',
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

    // Reset the state to clear the UI and prevent stale data from persisting.
    if (resetState) state = SessionState.initial();
  }

  void toggleGhostMode() {
    state = state.copyWith(isGhostMode: !state.isGhostMode);
  }
}