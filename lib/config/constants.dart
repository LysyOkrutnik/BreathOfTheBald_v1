class AppConstants {
  // --- AUDIO ---
  // Maximum volume for the background drone during active breathing phases.
  static const double volumeMax = 0.6;

  // Minimum volume during retention. Must be > 0.0 to prevent iOS from terminating the background audio session.
  static const double volumeMin = 0.15;

  static const Duration duckingDuration = Duration(milliseconds: 500);

  // --- HAPTICS ---
  // Interval (in seconds) for the heartbeat vibration in Ghost Mode.
  static const int ghostHeartbeatInterval = 15;
}