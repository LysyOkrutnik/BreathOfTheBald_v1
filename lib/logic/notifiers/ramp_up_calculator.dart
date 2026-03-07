class RampUpCalculator {
  /// Calculate the duration for a specific breath.
  /// [targetDuration] dictates the final baseline pace.
  static Duration getDuration(int breathIndex, Duration targetDuration) {
    // Decrease duration progressively for the first 5 breaths to ease the user into the rhythm.
    if (breathIndex < 5) {
      // Scale the modifier from 1.4x (slower) down to near 1.0x.
      double modifier = 1.4 - (breathIndex * 0.08);

      return Duration(
          milliseconds: (targetDuration.inMilliseconds * modifier).round()
      );
    }

    return targetDuration;
  }
}