import 'dart:convert';

import 'package:okrutnik_breath/data/db/database.dart';

/// Read-only rollup over recent freediving table logs, computed purely from
/// already-persisted data (roundsJson's per-round contraction marks, plus
/// roundsPlanned/roundsCompleted) — nothing new is stored here, this only
/// reads what FreedivingRepository.logTableSession already wrote.
class FreedivingProgressSummary {
  const FreedivingProgressSummary({
    required this.co2SessionsCompleted,
    required this.o2SessionsCompleted,
    required this.avgCompletionRate,
    required this.avgContractionRatio,
  });

  final int co2SessionsCompleted;
  final int o2SessionsCompleted;

  /// Average roundsCompleted/roundsPlanned across recent logs, 0..1. Null if
  /// there are no logs yet.
  final double? avgCompletionRate;

  /// Average, across rounds that were ever marked via "Fala kontrakcji", of
  /// firstContractionSec/apneaSec (0..1) — a rising value across sessions is
  /// real, measurable CO2-tolerance progress: the diaphragm's urge-to-breathe
  /// reflex is kicking in later relative to the hold's length, not just that
  /// the hold itself got longer. Null if nothing was ever marked.
  final double? avgContractionRatio;

  static const FreedivingProgressSummary empty = FreedivingProgressSummary(
    co2SessionsCompleted: 0,
    o2SessionsCompleted: 0,
    avgCompletionRate: null,
    avgContractionRatio: null,
  );

  static FreedivingProgressSummary fromLogs(List<FreedivingSessionLogData> logs) {
    if (logs.isEmpty) return empty;

    final co2Count = logs.where((l) => l.tableType == 'co2').length;
    final o2Count = logs.where((l) => l.tableType == 'o2').length;

    final rates = logs
        .where((l) => l.roundsPlanned > 0)
        .map((l) => l.roundsCompleted / l.roundsPlanned)
        .toList();
    final completionRate =
        rates.isEmpty ? null : rates.reduce((a, b) => a + b) / rates.length;

    final ratios = <double>[];
    for (final log in logs) {
      List<dynamic> rounds;
      try {
        rounds = jsonDecode(log.roundsJson) as List<dynamic>;
      } catch (_) {
        // The whole log's JSON is unparsable — nothing to salvage from it.
        continue;
      }
      for (final r in rounds) {
        // Scoped per round, not per log: one malformed/still-mid-sync round
        // (e.g. a numeric field that arrived as a string) used to throw and
        // discard every *other*, perfectly valid round in the same log too.
        try {
          final round = r as Map<String, dynamic>;
          final apnea = round['apneaSec'] as int?;
          final firstContraction = round['firstContractionSec'] as int?;
          if (apnea != null && apnea > 0 && firstContraction != null) {
            ratios.add(firstContraction / apnea);
          }
        } catch (_) {
          // This round contributes nothing; the rest of the log still does.
        }
      }
    }

    return FreedivingProgressSummary(
      co2SessionsCompleted: co2Count,
      o2SessionsCompleted: o2Count,
      avgCompletionRate: completionRate,
      avgContractionRatio:
          ratios.isEmpty ? null : ratios.reduce((a, b) => a + b) / ratios.length,
    );
  }
}
