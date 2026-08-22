import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/logic/path/training_path.dart' show PathAction;
import 'package:okrutnik_breath/logic/path/weekly_plan.dart';

/// Color for a single planned action, shared between the week strip and the
/// "today" action rows so a discipline always reads the same everywhere.
Color plannedActionColor(PlannedAction action) {
  switch (action.type) {
    case PathAction.wimHof:
      return LevelData.levels[action.levelKey]?.color ?? AppTheme.accent;
    case PathAction.pbTest:
      return AppTheme.primary;
    case PathAction.co2Table:
      return const Color(0xFF4FC3F7);
    case PathAction.o2Table:
      return const Color(0xFFFF7043);
    case PathAction.coldShower:
      return const Color(0xFF80D8FF);
    case PathAction.mobility:
      return LevelData.levels[action.levelKey]?.color ?? AppTheme.accent;
    case PathAction.rest:
    case PathAction.maintain:
      return AppTheme.textDim;
  }
}

IconData plannedActionIcon(PlannedAction action) {
  switch (action.type) {
    case PathAction.wimHof:
      return Icons.air_rounded;
    case PathAction.pbTest:
      return Icons.timer_outlined;
    case PathAction.co2Table:
      return Icons.co2_rounded;
    case PathAction.o2Table:
      return Icons.bolt_rounded;
    case PathAction.coldShower:
      return Icons.ac_unit_rounded;
    case PathAction.mobility:
      return Icons.accessibility_new_rounded;
    case PathAction.rest:
    case PathAction.maintain:
      return Icons.spa_outlined;
  }
}

/// A Mon-of-this-window .. +6 days strip showing, per day, a small dot per
/// planned action (colored/iconed by discipline) — the "at a glance" view of
/// how the week's disciplines interleave. Purely presentational; tapping a
/// day surfaces its actions via [onDaySelected].
class WeekPlanStrip extends StatelessWidget {
  const WeekPlanStrip({
    super.key,
    required this.plan,
    this.selectedOffset = 0,
    this.onDaySelected,
  });

  final WeeklyPlan plan;
  final int selectedOffset;
  final ValueChanged<int>? onDaySelected;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final today = DateTime.now();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in plan.days) ...[
          if (day.dayOffset > 0) const SizedBox(width: 6),
          Expanded(
            child: _DayColumn(
              date: today.add(Duration(days: day.dayOffset)),
              locale: locale,
              day: day,
              isSelected: day.dayOffset == selectedOffset,
              isToday: day.dayOffset == 0,
              onTap: onDaySelected == null
                  ? null
                  : () => onDaySelected!(day.dayOffset),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.date,
    required this.locale,
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final String locale;
  final DayPlan day;
  final bool isSelected;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withAlpha(24) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: isToday
              ? Border.all(color: AppTheme.accent.withAlpha(150))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat.E(locale).format(date).substring(0, 2).toUpperCase(),
              style: TextStyle(
                color: isToday ? AppTheme.accent : Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            // Every day carries at least the daily cold-shower dot, so there's
            // no genuinely empty day to special-case here anymore — a day
            // with just that one dot already reads as "rest, but shower".
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 3,
              runSpacing: 3,
              children: [
                for (final action in day.actions)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: plannedActionColor(action),
                      boxShadow: AppTheme.glow(plannedActionColor(action), blur: 6),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
