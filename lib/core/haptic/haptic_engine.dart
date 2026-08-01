import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class HapticEngine {
  /// When false, all haptics are suppressed (driven by the user's setting).
  bool enabled = true;

  // Cache the capability check; querying the platform channel on every breath
  // cue (as often as every ~700ms) is needless overhead.
  bool? _hasVibrator;

  Future<bool> get hasVibrator async {
    if (_hasVibrator != null) return _hasVibrator!;
    try {
      _hasVibrator = await Vibration.hasVibrator() == true;
    } catch (_) {
      _hasVibrator = false;
    }
    return _hasVibrator!;
  }

  /// Triggers a light haptic impact, suitable for inhale/exhale cues.
  Future<void> playTick() async {
    if (!enabled) return;
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
    if (!enabled) return;
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
    if (!enabled) return;
    try {
      HapticFeedback.mediumImpact();
      if (await hasVibrator) {
        Vibration.vibrate(pattern: [0, 100, 100, 100]);
      }
    } catch (e) {
      debugPrint("Vibration error: $e");
    }
  }

  Future<void> playInhalePulse(double progress) async {
    if (!enabled) return;
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