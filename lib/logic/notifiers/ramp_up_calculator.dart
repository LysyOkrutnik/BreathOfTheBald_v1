class RampUpCalculator {
  
  
  static Duration getDuration(int breathIndex, Duration targetDuration) {
    
    if (breathIndex < 5) {
      
      double modifier = 1.4 - (breathIndex * 0.08);

      return Duration(
          milliseconds: (targetDuration.inMilliseconds * modifier).round());
    }

    return targetDuration;
  }
}