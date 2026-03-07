import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/core/audio/audio_manager.dart';
import 'package:okrutnik_breath/core/haptic/haptic_engine.dart';
import 'package:okrutnik_breath/logic/notifiers/ramp_up_calculator.dart';
import 'package:okrutnik_breath/logic/states/session_state.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  final audioManager = ref.read(audioManagerProvider);
  return SessionNotifier(audioManager);
});

class SessionNotifier extends StateNotifier<SessionState> {
  final AudioManager _audioManager;
  final HapticEngine _hapticEngine = HapticEngine();

  final Stopwatch _sessionTimer = Stopwatch();

  LevelData? _currentLevel;
  bool _isSessionActive = false;
  Timer? _phaseTimer;

  SessionNotifier(this._audioManager) : super(SessionState.initial());

  /// Skip the active session and proceed directly to the summary for debugging.
  void debugSkip() {
    _finishSession();
  }

  Future<void> startSession(LevelData level) async {
    _isSessionActive = true;
    _currentLevel = level;

    // Prevent timer duplication when rapidly restarting sessions.
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
      // Calculate approximate full breaths for the progress bar based on a ~700ms pace per phase.
      totalBreaths = (duration.inMilliseconds / 1400).floor();
    } else if (level.type == ExerciseType.boxBreathing) {
      totalBreaths = level.loopCount ?? 16;
    } else if (level.type == ExerciseType.relax478) {
      totalBreaths = level.loopCount ?? 32;
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
      if (!_isSessionActive) return;
      if (i == 1) {
        try { _audioManager.playGong(); } catch (_) {}
      }
      state = state.copyWith(customDescription: "$i...");
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!_isSessionActive) return;
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
    }
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
      if (!_isSessionActive) return;

      // Ensure the phase hasn't been manually overridden before proceeding.
      if (!state.phase.maybeMap(breathing: (_) => true, orElse: () => false)) return;

      final Duration duration = RampUpCalculator.getDuration(i - 1, pace);
      final half = duration ~/ 2;

      state = state.copyWith(phase: SessionPhase.breathing(breathIndex: i, isInhaling: true, currentBreathDuration: duration));
      _playSignal(isInhale: true);
      await Future.delayed(half);

      if (!_isSessionActive) return;

      state = state.copyWith(phase: SessionPhase.breathing(breathIndex: i, isInhaling: false, currentBreathDuration: duration));
      _playSignal(isInhale: false);
      await Future.delayed(half);
    }

    if (_isSessionActive) _startRetention();
  }

  void _startRetention() {
    try { _hapticEngine.playHeavyImpact(); _audioManager.playGong(); _audioManager.duckDrone(); } catch (_) {}

    final start = DateTime.now();
    state = state.copyWith(phase: SessionPhase.retention(elapsed: Duration.zero));

    _phaseTimer?.cancel();
    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isSessionActive) { t.cancel(); return; }
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

    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isSessionActive) { t.cancel(); return; }
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
      if (!_isSessionActive) return;
      state = state.copyWith(currentRound: 1, totalRounds: 1);

      _updateCustomState("session_inhale", "session_box_inhale_desc", isBig: true, isInhaling: true, duration: const Duration(seconds: 4), index: i);
      _playSignal(isInhale: true);
      await Future.delayed(const Duration(seconds: 4));
      if (!_isSessionActive) return;

      _updateCustomState("session_hold", "session_box_hold_full_desc", isBig: true, isInhaling: true, duration: const Duration(seconds: 4), index: i);
      await Future.delayed(const Duration(seconds: 4));
      if (!_isSessionActive) return;

      _updateCustomState("session_exhale", "session_box_exhale_desc", isBig: false, isInhaling: false, duration: const Duration(seconds: 4), index: i);
      _playSignal(isInhale: false);
      await Future.delayed(const Duration(seconds: 4));
      if (!_isSessionActive) return;

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
      if (!_isSessionActive) return;

      _updateCustomState("session_inhale", "session_relax_inhale_desc", isBig: true, isInhaling: true, duration: const Duration(seconds: 4), index: i);
      _playSignal(isInhale: true);
      await Future.delayed(const Duration(seconds: 4));
      if (!_isSessionActive) return;

      _updateCustomState("session_hold", "session_relax_hold_desc", isBig: true, isInhaling: true, duration: const Duration(seconds: 7), index: i);
      await Future.delayed(const Duration(seconds: 7));
      if (!_isSessionActive) return;

      _updateCustomState("session_exhale", "session_relax_exhale_desc", isBig: false, isInhaling: false, duration: const Duration(seconds: 8), index: i);
      _playSignal(isInhale: false);
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

    // Utilize Timer.periodic to ensure timeline stability and smooth UI updates over rapid intervals.
    _phaseTimer?.cancel();
    _phaseTimer = Timer.periodic(tickDuration, (timer) {
      if (!_isSessionActive) {
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

      final timeStr = "${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}";

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
        _hapticEngine.playLightImpact();
        try { _audioManager.playInhale(); } catch (_) {}
      } else {
        try { _audioManager.playExhale(); } catch (_) {}
      }

      isInhaling = !isInhaling;
      if (isInhaling) cycle++;
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

  void _playSignal({required bool isInhale}) {
    try {
      _hapticEngine.playLightImpact();
      if (isInhale) _audioManager.playInhale(); else _audioManager.playExhale();
    } catch (_) {}
  }

  // Handle successful session completion and transition to the summary view.
  void _finishSession() {
    _sessionTimer.stop();
    state = state.copyWith(
      phase: const SessionPhase.finished(),
      sessionDuration: _sessionTimer.elapsed,
    );
    stopSession(resetState: false);
  }

  // Clean up the active state and gracefully return to the menu when explicitly cancelled.
  void stopSession({bool resetState = true}) {
    _isSessionActive = false;
    _sessionTimer.stop();
    _phaseTimer?.cancel();
    WakelockPlus.disable();
    _audioManager.stopDrone();

    // Trigger UI removal by resetting to the initial state.
    if (resetState) state = SessionState.initial();
  }

  void finishSession() {
    _finishSession();
  }

  void toggleGhostMode() {
    state = state.copyWith(isGhostMode: !state.isGhostMode);
  }
}