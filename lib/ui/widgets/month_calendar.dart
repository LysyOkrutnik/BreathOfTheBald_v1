import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:okrutnik_breath/config/theme.dart';

/// A compact, glass-styled month calendar. Weeks start on Monday. Days that
/// have planned sessions show a dot per distinct session type (colour-coded);
/// the selected day is filled and today is outlined.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.focusedMonth,
    required this.selectedDay,
    required this.markedDays,
    required this.onDaySelected,
    required this.onMonthChanged,
  });

  final DateTime focusedMonth;
  final DateTime selectedDay;

  /// Date-only days (year/month/day, time stripped) mapped to the distinct
  /// colours of that day's planned sessions (for the colour-coded dots).
  final Map<DateTime, List<Color>> markedDays;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onMonthChanged;

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final today = dateOnly(DateTime.now());
    final first = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final leadingBlanks = (first.weekday - 1) % 7; // Monday-first

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppTheme.glass(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(context, locale),
          const SizedBox(height: AppSpacing.sm),
          _weekdayRow(locale),
          const SizedBox(height: AppSpacing.xs),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            children: [
              for (var i = 0; i < leadingBlanks; i++) const SizedBox(),
              for (var day = 1; day <= daysInMonth; day++)
                _DayCell(
                  date: DateTime(focusedMonth.year, focusedMonth.month, day),
                  isToday: DateTime(focusedMonth.year, focusedMonth.month, day) == today,
                  isSelected:
                      DateTime(focusedMonth.year, focusedMonth.month, day) ==
                          dateOnly(selectedDay),
                  dotColors: markedDays[
                          DateTime(focusedMonth.year, focusedMonth.month, day)] ??
                      const [],
                  onTap: () => onDaySelected(
                      DateTime(focusedMonth.year, focusedMonth.month, day)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String locale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _navButton(Icons.chevron_left_rounded,
            () => onMonthChanged(DateTime(focusedMonth.year, focusedMonth.month - 1))),
        Text(
          toBeginningOfSentenceCase(
                  DateFormat.yMMMM(locale).format(focusedMonth)) ??
              '',
          style: const TextStyle(
            color: AppTheme.textLight,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        _navButton(Icons.chevron_right_rounded,
            () => onMonthChanged(DateTime(focusedMonth.year, focusedMonth.month + 1))),
      ],
    );
  }

  Widget _navButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withAlpha(12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        // The icon+padding alone was ~34x34 — below the 48dp minimum
        // recommended touch target size.
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(child: Icon(icon, color: Colors.white70, size: 22)),
        ),
      ),
    );
  }

  Widget _weekdayRow(String locale) {
    // Monday-first weekday labels.
    final monday = DateTime(2024, 1, 1); // a Monday
    final labels = [
      for (var i = 0; i < 7; i++)
        DateFormat.E(locale).format(monday.add(Duration(days: i)))
    ];
    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Center(
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white38, fontSize: 10, letterSpacing: 0.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.dotColors,
    required this.onTap,
  });

  final DateTime date;
  final bool isToday;
  final bool isSelected;

  /// One colour per distinct session type planned this day (already
  /// deduplicated by the caller); shown as up to 3 small dots.
  final List<Color> dotColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Fill the grid slot (with a little inset) rather than forcing a fixed
    // 38px box, which overflowed the cell on narrow widths / two-pane tablets.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? AppTheme.primary : Colors.transparent,
            border: isToday && !isSelected
                ? Border.all(color: AppTheme.primary.withAlpha(150))
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      color: isSelected ? Colors.black : AppTheme.textLight,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                    ),
                  ),
                ),
              ),
              if (dotColors.isNotEmpty)
                Positioned(
                  bottom: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final color in dotColors.take(3)) ...[
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? Colors.black : color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
