import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class HapticEngine {
  Future<bool> get hasVibrator async {
    // Safeguard against potential null returns from the Vibration plugin.
    return (await Vibration.hasVibrator()) ?? false;
  }

  /// Trigger a light haptic impact for inhale/exhale cues.
  Future<void> playLightImpact() async {
    try {
      HapticFeedback.lightImpact();
      if (await hasVibrator) {
        // Provide a short vibration fallback for devices lacking native haptic engine support.
        Vibration.vibrate(duration: 50);
      }
    } catch (e) {
      debugPrint("Vibration error: $e");
    }
  }

  /// Trigger a heavy haptic impact for round-end or retention start cues.
  Future<void> playHeavyImpact() async {
    try {
      HapticFeedback.heavyImpact();
      if (await hasVibrator) {
        Vibration.vibrate(duration: 500);
      }
    } catch (e) {
      debugPrint("Vibration error: $e");
    }
  }

  /// Trigger a heartbeat vibration pattern for Ghost Mode.
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
    // Ignore the progress parameter and default to a simple light impact.
    playLightImpact();
  }
}