import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:okrutnik_breath/config/assets.dart';
import 'package:okrutnik_breath/config/constants.dart';

final audioManagerProvider = Provider<AudioManager>((ref) {
  return AudioManager();
});

class AudioManager {
  final AudioPlayer _dronePlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  bool _isInitialized = false;

  
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
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

      _isInitialized = true;
    } catch (e) {
      debugPrint("⚠️ AUDIO ERROR (Init): $e. Verify audio assets exist!");
      
      _isInitialized = true;
    }
  }

  Future<void> startDrone() async {
    try {
      if (!_dronePlayer.playing) {
        await _dronePlayer.play();
      }
    } catch (e) {
      debugPrint("⚠️ AUDIO ERROR (Start Drone): $e");
    }
  }

  Future<void> stopDrone() async {
    try {
      await _dronePlayer.stop();
    } catch (e) {
      
    }
  }

  Future<void> playInhale() async => _safePlay(AppAssets.inhale);
  Future<void> playExhale() async => _safePlay(AppAssets.exhale);
  Future<void> playGong() async => _safePlay(AppAssets.gong);

  Future<void> _safePlay(String path) async {
    try {
      
      await _sfxPlayer.stop();
      await _sfxPlayer.setAsset(path);
      _sfxPlayer.play();
    } catch (e) {
      debugPrint("⚠️ SFX ERROR ($path): $e");
    }
  }

  Future<void> duckDrone() async {
    try {
      await _dronePlayer.setVolume(AppConstants.volumeMin);
    } catch (e) {
      
    }
  }

  Future<void> unduckDrone() async {
    try {
      await _dronePlayer.setVolume(AppConstants.volumeMax);
    } catch (e) {
      
    }
  }

  void dispose() {
    _dronePlayer.dispose();
    _sfxPlayer.dispose();
  }
}