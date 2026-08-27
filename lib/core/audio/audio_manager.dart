import 'dart:async';
import 'dart:developer' as developer;
import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:okrutnik_breath/config/assets.dart';
import 'package:okrutnik_breath/config/constants.dart';

final audioManagerProvider = Provider<AudioManager>((ref) {
  final manager = AudioManager();
  // Release the underlying platform players when the provider is torn down.
  ref.onDispose(manager.dispose);
  return manager;
});

class AudioManager {
  final AudioPlayer _dronePlayer = AudioPlayer();

  // Each short cue gets its own pre-loaded player. Cues fire as often as every
  // ~700ms, so re-decoding an asset on every play (the previous approach) added
  // latency and GC churn; instead we load once and replay via seek(0).
  final AudioPlayer _inhalePlayer = AudioPlayer();
  final AudioPlayer _exhalePlayer = AudioPlayer();
  final AudioPlayer _gongPlayer = AudioPlayer();

  bool _isInitialized = false;

  /// When false, all playback is suppressed (driven by the user's sound setting).
  bool soundEnabled = true;

  // Initialize the audio session and players. Fail soft so the app still works
  // (silently) if audio assets are missing or the platform rejects playback.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      ));

      await _dronePlayer.setAsset(AppAssets.background);
      await _dronePlayer.setLoopMode(LoopMode.one);
      await _dronePlayer.setVolume(AppConstants.volumeMax);

      // Pre-load short cues so playback is instant during a session.
      await Future.wait([
        _inhalePlayer.setAsset(AppAssets.inhale),
        _exhalePlayer.setAsset(AppAssets.exhale),
        _gongPlayer.setAsset(AppAssets.gong),
      ]);

      _isInitialized = true;
    } catch (e, st) {
      developer.log('Audio init failed; continuing muted.',
          name: 'AudioManager', error: e, stackTrace: st);
      // Mark as initialized so the app functions without audio capabilities.
      _isInitialized = true;
    }
  }

  Future<void> startDrone() async {
    if (!soundEnabled) return;
    try {
      if (!_dronePlayer.playing) {
        await _dronePlayer.play();
      }
    } catch (e, st) {
      developer.log('Drone start failed',
          name: 'AudioManager', error: e, stackTrace: st);
    }
  }

  Future<void> stopDrone() async {
    try {
      await _dronePlayer.stop();
    } catch (_) {
      // Best-effort; nothing actionable on stop failure.
    }
  }

  Future<void> playInhale() => _replay(_inhalePlayer);
  Future<void> playExhale() => _replay(_exhalePlayer);
  Future<void> playGong() => _replay(_gongPlayer);

  /// Restarts a pre-loaded cue from the beginning without re-decoding it.
  /// `play()` itself stays fire-and-forget deliberately — its Future only
  /// completes once the *whole cue finishes playing*, and cues fire as
  /// often as every ~700ms; awaiting it here would stall whatever phase
  /// transition triggered this cue until playback ends. It still needs its
  /// own `catchError`, though — `unawaited()` opts a future out of the
  /// surrounding try/catch entirely, so a rejection from `play()` itself
  /// (audio focus loss, or the player mid-`dispose()` while a cue is still
  /// in flight) used to surface as an unhandled async exception instead of
  /// the same quiet log every other failure path in this file gets.
  Future<void> _replay(AudioPlayer player) async {
    if (!soundEnabled) return;
    try {
      await player.seek(Duration.zero);
      unawaited(player.play().catchError((Object e, StackTrace st) {
        developer.log('SFX playback failed',
            name: 'AudioManager', error: e, stackTrace: st);
      }));
    } catch (e, st) {
      developer.log('SFX playback failed',
          name: 'AudioManager', error: e, stackTrace: st);
    }
  }

  Future<void> duckDrone() async {
    try {
      await _dronePlayer.setVolume(AppConstants.volumeMin);
    } catch (_) {
      // Best-effort volume change.
    }
  }

  Future<void> unduckDrone() async {
    try {
      await _dronePlayer.setVolume(AppConstants.volumeMax);
    } catch (_) {
      // Best-effort volume change.
    }
  }

  Future<void> dispose() async {
    await Future.wait([
      _dronePlayer.dispose(),
      _inhalePlayer.dispose(),
      _exhalePlayer.dispose(),
      _gongPlayer.dispose(),
    ]);
  }
}
