class RampUpCalculator {
  /// Calculates the duration for a given breath, applying a ramp-up effect for the initial breaths.
  /// The [targetDuration] is the baseline pace that will be reached after the ramp-up phase.
  static Duration getDuration(int breathIndex, Duration targetDuration) {
    // Progressively decrease the duration for the first 5 breaths to ease the user into the rhythm.
    if (breathIndex < 5) {
      // Scale the modifier from 1.4x (slower) down to 1.0x for a smooth transition.
      double modifier = 1.4 - (breathIndex * 0.08);

      return Duration(
          milliseconds: (targetDuration.inMilliseconds * modifier).round());
    }

    return targetDuration;
  }
}