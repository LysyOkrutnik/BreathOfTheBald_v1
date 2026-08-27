/// Formats [totalSeconds] as "m:ss" (e.g. `245` -> "4:05").
String formatMmSs(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Formats [duration] as "m:ss".
String formatDurationMmSs(Duration duration) => formatMmSs(duration.inSeconds);

/// Serializes [dt] to a UTC ISO8601 string with an explicit UTC suffix —
/// required by the server's Zod `.datetime()` validation on push payloads.
String toUtcIso(DateTime dt) => dt.toUtc().toIso8601String();

/// Nullable variant of [toUtcIso].
String? toUtcIsoOrNull(DateTime? dt) => dt?.toUtc().toIso8601String();
