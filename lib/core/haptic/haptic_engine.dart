import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class HapticEngine {
  Future<bool> get hasVibrator async {
    try {
      final result = await Vibration.hasVibrator();
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// Triggers a light haptic impact, suitable for inhale/exhale cues.
  Future<void> playTick() async {
    try {
      if (await hasVibrator) {
        Vibration.vibrate(duration: 20, amplitude: 80);
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint("Vibration error: $e");
    }
  }

  /// Triggers a heavy haptic impact, suitable for round-end or retention start cues.
  Future<void> playRetentionPeak() async {
    try {
      HapticFeedback.heavyImpact();
      if (await hasVibrator) {
        Vibration.vibrate(duration: 400, amplitude: 255);
      }
    } catch (e) {
      debugPrint("Vibration error: $e");
    }
  }

  /// Triggers a heartbeat vibration pattern, used as a periodic cue in Ghost Mode.
  Future<void> playHeartbeat() async {
    try {
      HapticFeedback.mediumImpact();
      if (await hasVibrator) {
        Vibration.vibrate(pattern: [0, 100, 100, 100]);
      }
    } catch (e) {
      debugPrint("Vibration error: $e");
    }
  }

  Future<void> vibrateBreath(double progress) async {
    // The 'progress' parameter is ignored in favor of a simple light impact for this implementation.
    playTick();
  }

  Future<void> playInhalePulse(double progress) async {
    try {
      if (await hasVibrator) {
        // Scale intensity from 50 to 150 based on inhale progress.
        final amplitude = (50 + (progress * 100)).clamp(50, 150).toInt();
        Vibration.vibrate(duration: 100, amplitude: amplitude);
      }
    } catch (e) {
      debugPrint("Vibration error: $e");
    }
  }
}