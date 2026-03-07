class AppConstants {
  // --- AUDIO ---
  // Cap drone volume during active breathing phases.
  static const double volumeMax = 0.6;

  // Maintain volume > 0.0 during retention to prevent iOS from terminating the background audio session.
  static const double volumeMin = 0.15;

  static const Duration duckingDuration = Duration(milliseconds: 500);

  // --- HAPTICS ---
  // Set interval (in seconds) for Ghost Mode heartbeat vibrations.
  static const int ghostHeartbeatInterval = 15;
}