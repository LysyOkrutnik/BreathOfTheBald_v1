import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/core/notifications/notification_service.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/logic/freediving/co2_o2_table_generator.dart';
import 'package:okrutnik_breath/logic/path/cold_shower.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/logic/wimhof/wimhof_progression.dart'
    show kHardWimHofLevels;
import 'package:okrutnik_breath/ui/screens/freediving/max_pb_test_screen.dart';
import 'package:okrutnik_breath/ui/screens/intro_screen.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/confirm_dialog.dart';
import 'package:okrutnik_breath/ui/widgets/day_timeline.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/month_calendar.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';
import 'package:okrutnik_breath/ui/widgets/week_strip.dart';

/// Pushed on top of the Training tab (see training_library_screen.dart) as
/// its own route — NOT a shell tab root, so it needs its own [AppBackground]
/// rather than relying on HomeShellScreen's shared instance. Without this,
/// the previous screen's background briefly shows through the push
/// transition and then the screen goes solid black once that screen is
/// removed from the tree — this used to be a shell tab root, before the
/// 3-tab redesign, and the background dependency was never re-added here.
class SchedulerScreen extends ConsumerStatefulWidget {
  const SchedulerScreen({super.key});

  @override
  ConsumerState<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends ConsumerState<SchedulerScreen> {
  late DateTime _focusedMonth;
  late DateTime _selectedDay;

  /// Null while still checking; true/false once known. The heavy request
  /// (it navigates out to a system Settings screen) only ever fires from an
  /// explicit tap on the resulting explainer card, never silently.
  bool? _needsExactAlarmPermission;

  /// Lets the card be dismissed without granting — it's a one-time nudge,
  /// not core content, and shouldn't permanently squat above the calendar.
  /// Session-only (this screen's state survives tab switches via the shell's
  /// IndexedStack-style caching, but resets on a fresh app launch).
  bool _exactAlarmCardDismissed = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDay = MonthCalendar.dateOnly(now);
    _checkExactAlarmPermission();
  }

  Future<void> _checkExactAlarmPermission() async {
    final canSchedule =
        await ref.read(notificationServiceProvider).canScheduleExactAlarms();
    if (mounted) setState(() => _needsExactAlarmPermission = !canSchedule);
  }

  Future<void> _requestExactAlarmPermission() async {
    await ref.read(notificationServiceProvider).requestExactAlarmsPermission();
    // The user may have just come back from the Settings screen — re-check
    // rather than assuming either outcome.
    if (mounted) _checkExactAlarmPermission();
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(plannedSessionsProvider);
    final plans = plansAsync.value ?? const <PlannedSession>[];

    final markedDaysSet = {
      for (final p in plans) MonthCalendar.dateOnly(p.scheduledAt),
    };
    final markedDaysColors = <DateTime, List<Color>>{};
    for (final p in plans) {
      final day = MonthCalendar.dateOnly(p.scheduledAt);
      final color = LevelData.levels[p.levelKey]?.color ?? AppTheme.primary;
      final colors = markedDaysColors.putIfAbsent(day, () => []);
      if (!colors.contains(color)) colors.add(color);
    }
    final dayPlans = plans
        .where((p) => MonthCalendar.dateOnly(p.scheduledAt) == _selectedDay)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final calendar = MonthCalendar(
      focusedMonth: _focusedMonth,
      selectedDay: _selectedDay,
      markedDays: markedDaysColors,
      onDaySelected: (d) => setState(() => _selectedDay = d),
      onMonthChanged: (m) => setState(() => _focusedMonth = m),
    );

    final weekStrip = WeekStrip(
      selectedDay: _selectedDay,
      markedDays: markedDaysSet,
      onDaySelected: (d) => setState(() {
        _selectedDay = d;
        _focusedMonth = DateTime(d.year, d.month);
      }),
    );

    final twoPane = context.isTablet || context.isLandscape;

    final dayPanel = _DayPanel(
      day: _selectedDay,
      weekStrip: weekStrip,
      plans: dayPlans,
      plansLoading: plansAsync.isLoading,
      onAdd: () => _showAddSheet(context),
      onDelete: _deletePlan,
      onStart: _startFromPlan,
      // In the single-pane phone layout the month grid above already
      // leaves little headroom, so the timeline gets a fixed preview height
      // (its own internal scroll) and the whole calendar + day panel column
      // scrolls as one page instead of squeezing an Expanded down to a
      // sliver. The two-pane layout puts this panel in a genuinely tall,
      // bounded Row cell, where the old Expanded-to-fill behaviour is fine.
      timelineHeight: twoPane ? null : 320,
    );

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: context.isTablet ? 980 : 560),
                child: Column(
                  children: [
                    ScreenHeader(
                      title: L10n.get(context, 'scheduler_title'),
                    ),
                    // Asking for a permission tied to a feature the user hasn't
                    // touched yet (no plan ever saved) reads as premature — wait
                    // until they've actually created one.
                    if (_needsExactAlarmPermission == true &&
                        !_exactAlarmCardDismissed &&
                        plans.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                        child: _ExactAlarmCard(
                          onTap: _requestExactAlarmPermission,
                          onDismiss: () =>
                              setState(() => _exactAlarmCardDismissed = true),
                        ),
                      ),
                    Expanded(
                      child: twoPane
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding:
                                        const EdgeInsets.all(AppSpacing.lg),
                                    child: calendar,
                                  ),
                                ),
                                Expanded(child: dayPanel),
                              ],
                            )
                          : SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                children: [
                                  Padding(
                                    padding:
                                        const EdgeInsets.all(AppSpacing.lg),
                                    child: calendar,
                                  ),
                                  dayPanel,
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Freediving CO2/O2 tables can't be pre-planned as a fixed shape — the
  /// round schedule depends on the user's *current* working PB, so it's
  /// regenerated fresh here via [LevelData.freedivingTable] rather than
  /// starting whatever static placeholder ended up stored. A planned PB test
  /// needs the guided stopwatch screen, not a generic level intro. Regular
  /// levels start unchanged. (The scheduler's own add sheet excludes these
  /// from the plannable list; both branches exist because "Twoja Ścieżka"
  /// can plan them directly.)
  Future<void> _startFromPlan(LevelData level) async {
    if (level.key == 'freediving_pb_test') {
      Navigator.of(context).push(fadeThroughRoute(const MaxPbTestScreen()));
      return;
    }
    if (level.key == coldShowerLevelKey) {
      // No guided screen for this one either — logging it *is* "starting" it.
      final messenger = ScaffoldMessenger.of(context);
      final result = await logColdShowerSession(ref);
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(L10n.get(context, 'coldshower_logged_toast')),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: L10n.get(context, 'common_undo'),
            onPressed: () => undoColdShowerSession(ref, result),
          ),
        ));
      }
      return;
    }

    var toStart = level;
    if (level.type == ExerciseType.co2Table ||
        level.type == ExerciseType.o2Table) {
      final profile = await ref.read(freedivingRepositoryProvider).getProfile();
      final tableType = level.type == ExerciseType.co2Table
          ? FreedivingTableType.co2
          : FreedivingTableType.o2;
      final pb = (tableType == FreedivingTableType.co2
              ? profile.virtualPbCo2Sec
              : profile.virtualPbO2Sec) ??
          profile.verifiedPbSec;
      if (pb == null) {
        // Was a silent no-op — tapping a planned CO2/O2 table with no PB yet
        // did nothing at all, with no indication why.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(L10n.get(context, 'freediving_locked_no_pb')),
            action: SnackBarAction(
              label: L10n.get(context, 'freediving_pb_test_cta'),
              onPressed: () => Navigator.of(context)
                  .push(fadeThroughRoute(const MaxPbTestScreen())),
            ),
          ));
        }
        return;
      }
      toStart = LevelData.freedivingTable(tableType: tableType, pbSeconds: pb);
    }
    if (mounted) {
      Navigator.of(context).push(fadeThroughRoute(IntroScreen(level: toStart)));
    }
  }

  Future<void> _deletePlan(PlannedSession plan) async {
    final confirmed = await showGlassConfirm(
      context,
      title: L10n.get(context, 'delete_confirm_title'),
      confirmLabel: L10n.get(context, 'delete_confirm_yes'),
      cancelLabel: L10n.get(context, 'delete_confirm_cancel'),
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    final message = L10n.get(context, 'planner_deleted');
    await ref.read(plannerRepositoryProvider).deletePlan(plan.id);
    await ref.read(notificationServiceProvider).cancel(plan.id);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _showAddSheet(BuildContext context) async {
    // Freediving CO2/O2 tables depend on the live working PB at start time,
    // so they can't be meaningfully pre-planned as a fixed shape (see
    // _startFromPlan) — excluded from the plannable list entirely.
    final plannableLevels = LevelData.levels.values
        .where((l) =>
            l.type != ExerciseType.co2Table && l.type != ExerciseType.o2Table)
        .toList();

    // Default to the Wim Hof "Next Up" recommendation, if there is one —
    // a light integration between the ladder progression and the planner.
    final recommendedKey =
        ref.read(wimHofNextUpProvider).value?.recommendedLevelKey;
    LevelData? level =
        recommendedKey == null ? null : LevelData.levels[recommendedKey];
    var time = const TimeOfDay(hour: 8, minute: 0);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheet) {
            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                // A bottom sheet is full-width by default — on a tablet that
                // stretches the dropdown/time-row/save-button far wider than
                // every other screen's content, which all cap around 560.
                constraints: BoxConstraints(
                    maxWidth: sheetContext.isTablet ? 480 : double.infinity),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    top: AppSpacing.lg,
                    bottom: MediaQuery.viewInsetsOf(sheetContext).bottom +
                        AppSpacing.lg,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141C24),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: Colors.white.withAlpha(24)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          DateFormat.yMMMMEEEEd(
                                  Localizations.localeOf(context).toString())
                              .format(_selectedDay),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppTheme.textLight,
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<LevelData>(
                              value: level,
                              isExpanded: true,
                              dropdownColor: AppTheme.background,
                              hint: Text(
                                  L10n.get(context, 'scheduler_choose_level'),
                                  style:
                                      const TextStyle(color: AppTheme.textDim)),
                              items: plannableLevels
                                  .map((l) => DropdownMenuItem(
                                        value: l,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                  color: l.color,
                                                  shape: BoxShape.circle),
                                            ),
                                            const SizedBox(
                                                width: AppSpacing.md),
                                            Text(L10n.get(context, l.title),
                                                style: const TextStyle(
                                                    color: AppTheme.textLight)),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) => setSheet(() => level = v),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        PressableScale(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: sheetContext,
                              initialTime: time,
                              builder: (ctx, child) => Theme(
                                data: ThemeData.dark().copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: AppTheme.primary,
                                    onPrimary: Colors.black,
                                    surface: AppTheme.background,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) setSheet(() => time = picked);
                          },
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.lg),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(time.format(context),
                                    style: const TextStyle(
                                      color: AppTheme.textLight,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      fontFeatures: [
                                        FontFeature.tabularFigures()
                                      ],
                                    )),
                                const Icon(Icons.access_time_rounded,
                                    color: AppTheme.primary),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            const Icon(Icons.notifications_active_outlined,
                                color: AppTheme.textDim, size: 16),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                L10n.get(context, 'planner_reminder_note'),
                                style: const TextStyle(
                                    color: AppTheme.textDim, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        PressableScale(
                          onTap: level == null
                              ? null
                              : () {
                                  Navigator.of(sheetContext).pop();
                                  _savePlan(level!, time);
                                },
                          child: Opacity(
                            opacity: level == null ? 0.5 : 1.0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                boxShadow: level == null
                                    ? null
                                    : AppTheme.glow(AppTheme.primary, blur: 20),
                              ),
                              child: Text(
                                L10n.get(context, 'scheduler_save'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _savePlan(LevelData level, TimeOfDay time) async {
    final scheduledAt = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      time.hour,
      time.minute,
    );

    // A reminder for a moment that's already passed would never fire —
    // notification_service.dart silently drops it — so this would otherwise
    // save a plan the user believes carries a working reminder and doesn't.
    if (scheduledAt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.get(context, 'planner_time_in_past'))));
      return;
    }

    // A weekly Max PB Test needs to be the day's one demanding effort — a
    // hard session stacked on the same day risks skewing the test (fatigue,
    // residual CO2) or just isn't smart training. This is a warning, not a
    // hard block: the user can still confirm and add it anyway.
    final isHardLevel = level.key != 'freediving_pb_test' &&
        (level.type == ExerciseType.co2Table ||
            level.type == ExerciseType.o2Table ||
            (level.type == ExerciseType.wimHof &&
                kHardWimHofLevels.contains(level.key)));
    if (isHardLevel) {
      final plans =
          ref.read(plannedSessionsProvider).value ?? const <PlannedSession>[];
      final hasPbTestThatDay = plans.any((p) =>
          p.levelKey == 'freediving_pb_test' &&
          MonthCalendar.dateOnly(p.scheduledAt) ==
              MonthCalendar.dateOnly(scheduledAt));
      if (hasPbTestThatDay) {
        final confirmed = await showGlassConfirm(
          context,
          title: L10n.get(context, 'planner_pbtest_day_warning_title'),
          body: L10n.get(context, 'planner_pbtest_day_warning_body'),
          confirmLabel: L10n.get(context, 'planner_pbtest_day_warning_confirm'),
          cancelLabel: L10n.get(context, 'delete_confirm_cancel'),
          icon: Icons.warning_amber_rounded,
          confirmColor: AppTheme.danger,
        );
        if (!confirmed || !mounted) return;
      }
    }

    final reminderTitle = L10n.get(context, 'planner_reminder_title');
    final levelName = L10n.get(context, level.title);
    final timeStr = time.format(context);
    final savedMessage = L10n.get(context, 'planner_saved');

    try {
      final planId = await ref.read(plannerRepositoryProvider).addPlan(
            scheduledAt: scheduledAt,
            levelKey: level.key,
          );
      final notifications = ref.read(notificationServiceProvider);
      await notifications.scheduleOneTime(
        id: planId,
        when: scheduledAt.subtract(const Duration(minutes: 5)),
        title: reminderTitle,
        body: '$levelName • $timeStr',
      );
      if (!mounted) return;

      // The persistent alarm-permission card only shows once a plan exists
      // (asking beforehand read as premature), but that means this first
      // save might just have silently failed to schedule a working reminder
      // — check right here instead of leaving it to be silently discovered.
      final canScheduleExact = await notifications.canScheduleExactAlarms();
      if (!mounted) return;
      if (!canScheduleExact) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L10n.get(context, 'planner_saved_needs_permission')),
          action: SnackBarAction(
            label: L10n.get(context, 'planner_exact_alarm_allow'),
            onPressed: () {
              notifications.requestExactAlarmsPermission();
              _checkExactAlarmPermission();
            },
          ),
        ));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(savedMessage)));
      }
    } catch (e, st) {
      developer.log('Error saving plan',
          name: 'SchedulerScreen', error: e, stackTrace: st);
    }
  }
}

/// Explains, in context, why the app wants the (fairly heavy — it navigates
/// out to a system Settings screen) exact-alarm permission, before ever
/// asking for it, rather than firing the system flow unexplained.
class _ExactAlarmCard extends StatelessWidget {
  const _ExactAlarmCard({required this.onTap, required this.onDismiss});
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.alarm_on_outlined, color: AppTheme.accent, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.get(context, 'planner_exact_alarm_title'),
                  style: const TextStyle(
                    color: AppTheme.textLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  L10n.get(context, 'planner_exact_alarm_body'),
                  style: const TextStyle(
                      color: AppTheme.textDim, fontSize: 11, height: 1.4),
                ),
                const SizedBox(height: AppSpacing.sm),
                PressableScale(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      L10n.get(context, 'planner_exact_alarm_allow'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: Colors.white38, size: 18),
            onPressed: onDismiss,
            tooltip: L10n.get(context, 'common_dismiss'),
          ),
        ],
      ),
    );
  }
}

class _DayPanel extends StatelessWidget {
  const _DayPanel({
    required this.day,
    required this.weekStrip,
    required this.plans,
    required this.plansLoading,
    required this.onAdd,
    required this.onDelete,
    required this.onStart,
    this.timelineHeight,
  });

  final DateTime day;
  final Widget weekStrip;
  final List<PlannedSession> plans;

  /// True only before the plans stream has emitted its first value — guards
  /// the "nothing planned" caption below so it can't flash misleadingly
  /// during that brief window.
  final bool plansLoading;
  final VoidCallback onAdd;
  final ValueChanged<PlannedSession> onDelete;
  final ValueChanged<LevelData> onStart;

  /// When set, the timeline gets this fixed height (its own internal scroll)
  /// instead of an [Expanded] — needed wherever this panel sits inside an
  /// *unbounded*-height context (the single-pane phone layout wraps the
  /// whole calendar + day panel in one page-level scroll view, since a full
  /// month grid above it already leaves little to no room for a flex-sized
  /// timeline to expand into). Null keeps the old [Expanded] behaviour for
  /// the two-pane layout, where this panel fills a genuinely tall, bounded
  /// Row cell.
  final double? timelineHeight;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize:
            timelineHeight == null ? MainAxisSize.max : MainAxisSize.min,
        children: [
          weekStrip,
          const SizedBox(height: AppSpacing.md),
          Text(
            toBeginningOfSentenceCase(
                    DateFormat.MMMMEEEEd(locale).format(day)) ??
                '',
            style: const TextStyle(
                color: AppTheme.textLight,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5),
          ),
          if (plans.isEmpty && !plansLoading) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              L10n.get(context, 'planner_no_plans'),
              style: const TextStyle(color: AppTheme.textDim, fontSize: 12),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _buildTimeline(),
          const SizedBox(height: AppSpacing.md),
          // Filled, not outlined — this is the screen's one primary action,
          // and previously read as visually weaker than the (temporary)
          // exact-alarm permission card above it.
          PressableScale(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppTheme.glow(AppTheme.primary, blur: 18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, color: Colors.black, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    L10n.get(context, 'planner_add'),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final timeline = SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: DayTimeline(
        items: [
          for (final p in plans)
            TimelineItem(
              time: TimeOfDay.fromDateTime(p.scheduledAt),
              child: _PlanTile(
                plan: p,
                onDelete: () => onDelete(p),
                onStart: onStart,
              ),
            ),
        ],
      ),
    );

    return timelineHeight == null
        ? Expanded(child: timeline)
        : SizedBox(height: timelineHeight, child: timeline);
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.onDelete,
    required this.onStart,
  });

  final PlannedSession plan;
  final VoidCallback onDelete;
  final ValueChanged<LevelData> onStart;

  @override
  Widget build(BuildContext context) {
    final level = LevelData.levels[plan.levelKey];
    final color = level?.color ?? AppTheme.primary;
    final name = level != null ? L10n.get(context, level.title) : plan.levelKey;
    final time = TimeOfDay.fromDateTime(plan.scheduledAt).format(context);

    return GlassCard(
      gradient: AppTheme.cardGradient(color),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      child: Row(
        children: [
          Text(
            time,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
          ),
          if (level != null)
            IconButton(
              icon: Icon(Icons.play_arrow_rounded, color: color),
              tooltip: L10n.get(context, 'planner_start'),
              onPressed: () => onStart(level),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.white38, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
