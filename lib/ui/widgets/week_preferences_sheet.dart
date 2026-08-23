import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/logic/providers/settings_provider.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';

/// Weekly-plan sessions now get their hour picked individually in
/// WeekSchedulingScreen, so this sheet no longer offers an hour range to
/// edit — [_hourStart]/[_hourEnd] just carry the stored values through
/// unchanged on save, since [SettingsNotifier.setWeekPreferences] still
/// persists them (kept, unused, to avoid reshaping the sync payload).

/// A reference Monday (2024-01-01 was one) used purely to format localized
/// weekday abbreviations for weekdays 1..7 — no calendar meaning otherwise.
DateTime _referenceMonday() => DateTime(2024, 1, 1);

/// Bottom sheet for Twoja Ścieżka's weekly-plan preferences: which weekdays
/// are available, the usual training hour, and whether sessions may stack on
/// the same day. Edited together and saved in one go.
class WeekPreferencesSheet extends ConsumerStatefulWidget {
  const WeekPreferencesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const WeekPreferencesSheet(),
    );
  }

  @override
  ConsumerState<WeekPreferencesSheet> createState() =>
      _WeekPreferencesSheetState();
}

class _WeekPreferencesSheetState extends ConsumerState<WeekPreferencesSheet> {
  late Set<int> _weekdays;
  late int _hourStart;
  late int _hourEnd;
  late bool _allowMultiple;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _weekdays = Set.of(settings.availableWeekdays);
    _hourStart = settings.availableHourStart;
    _hourEnd = settings.availableHourEnd;
    _allowMultiple = settings.allowMultipleSessionsPerDay;
  }

  void _toggleDay(int weekday) {
    setState(() {
      if (_weekdays.contains(weekday)) {
        if (_weekdays.length > 1) _weekdays.remove(weekday);
      } else {
        _weekdays.add(weekday);
      }
    });
  }

  Future<void> _save() async {
    await ref.read(settingsProvider.notifier).setWeekPreferences(
          availableWeekdays: _weekdays,
          availableHourStart: _hourStart,
          availableHourEnd: _hourEnd,
          allowMultipleSessionsPerDay: _allowMultiple,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final monday = _referenceMonday();

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: Colors.white.withAlpha(20)),
        ),
        // A fixed 7-day toggle row + slider + switch + button can still
        // exceed the sheet's height on a short landscape phone or at a large
        // system text scale — this used to be a bare Column with no scroll
        // fallback, which would overflow instead of just scrolling.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                L10n.get(context, 'path_prefs_title'),
                style: const TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                L10n.get(context, 'path_prefs_intro'),
                style: TextStyle(
                    color: AppTheme.textDim.withAlpha(200),
                    fontSize: 12,
                    height: 1.4),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                L10n.get(context, 'path_prefs_days_label'),
                style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  for (var weekday = 1; weekday <= 7; weekday++) ...[
                    if (weekday > 1) const SizedBox(width: 6),
                    Expanded(
                        child: _DayToggle(
                      label: DateFormat.E(locale)
                          .format(monday.add(Duration(days: weekday - 1)))
                          .substring(0, 2)
                          .toUpperCase(),
                      selected: _weekdays.contains(weekday),
                      onTap: () => _toggleDay(weekday),
                    )),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      L10n.get(context, 'path_prefs_multiple_label'),
                      style: const TextStyle(
                          color: AppTheme.textLight, fontSize: 14),
                    ),
                  ),
                  Switch(
                    value: _allowMultiple,
                    activeThumbColor: AppTheme.accent,
                    onChanged: (v) => setState(() => _allowMultiple = v),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              PressableScale(
                onTap: _save,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: AppTheme.glow(AppTheme.accent, blur: 18),
                  ),
                  child: Text(
                    L10n.get(context, 'path_prefs_save'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
