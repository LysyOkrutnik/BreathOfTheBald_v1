import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/theme.dart';

/// A horizontal Mon–Sun strip for quickly jumping between days within a
/// week — a lightweight "week view" alongside the month grid and day
/// timeline.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.selectedDay,
    required this.markedDays,
    required this.onDaySelected,
  });

  final DateTime selectedDay;

  /// Date-only days that have at least one planned session.
  final Set<DateTime> markedDays;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final monday =
        selectedDay.subtract(Duration(days: (selectedDay.weekday - 1) % 7));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _DayChip(
              day: monday.add(Duration(days: i)),
              locale: locale,
              isSelected:
                  _isSameDay(monday.add(Duration(days: i)), selectedDay),
              isToday: _isSameDay(monday.add(Duration(days: i)), today),
              hasPlan: markedDays.contains(monday.add(Duration(days: i))),
              onTap: onDaySelected,
            ),
          ),
        ],
      ],
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.locale,
    required this.isSelected,
    required this.isToday,
    required this.hasPlan,
    required this.onTap,
  });

  final DateTime day;
  final String locale;
  final bool isSelected;
  final bool isToday;
  final bool hasPlan;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final dayLabel =
        toBeginningOfSentenceCase(DateFormat.MMMMd(locale).format(day));
    final semanticLabel = hasPlan
        ? '$dayLabel, ${L10n.get(context, 'a11y_day_has_plan')}'
        : dayLabel;

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: () => onTap(day),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary : Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: isToday && !isSelected
                  ? Border.all(color: AppTheme.primary.withAlpha(150))
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat.E(locale)
                      .format(day)
                      .substring(0, 2)
                      .toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.black87 : Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    color: isSelected ? Colors.black : AppTheme.textLight,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 4,
                  width: 4,
                  child: hasPlan
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? Colors.black : AppTheme.accent,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
