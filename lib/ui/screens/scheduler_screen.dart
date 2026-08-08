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
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/ui/screens/intro_screen.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/month_calendar.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';

/// The "Plan" bottom-nav tab. Only ever shown as a shell tab root — the
/// shared background lives in HomeShellScreen so it isn't torn down and
/// rebuilt (with its animation restarting) every time the tab is switched.
class SchedulerScreen extends ConsumerStatefulWidget {
  const SchedulerScreen({super.key});

  @override
  ConsumerState<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends ConsumerState<SchedulerScreen> {
  late DateTime _focusedMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDay = MonthCalendar.dateOnly(now);
    // Reminders fire to the minute, so ask for exact-alarm permission up front.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).requestExactAlarmsPermission();
    });
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(plannedSessionsProvider);
    final plans = plansAsync.value ?? const <PlannedSession>[];
    final marked = {
      for (final p in plans) MonthCalendar.dateOnly(p.scheduledAt),
    };
    final dayPlans = plans
        .where((p) => MonthCalendar.dateOnly(p.scheduledAt) == _selectedDay)
        .toList();

    final calendar = MonthCalendar(
      focusedMonth: _focusedMonth,
      selectedDay: _selectedDay,
      markedDays: marked,
      onDaySelected: (d) => setState(() => _selectedDay = d),
      onMonthChanged: (m) => setState(() => _focusedMonth = m),
    );

    final dayPanel = _DayPanel(
      day: _selectedDay,
      plans: dayPlans,
      onAdd: () => _showAddSheet(context),
      onDelete: _deletePlan,
      onStart: (level) => Navigator.of(context)
          .push(fadeThroughRoute(IntroScreen(level: level))),
    );

    final twoPane = context.isTablet || context.isLandscape;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.isTablet ? 980 : 560),
          child: Column(
            children: [
              ScreenHeader(
                title: L10n.get(context, 'scheduler_title'),
                showBackButton: false,
              ),
              Expanded(
                child: twoPane
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: calendar,
                            ),
                          ),
                          Expanded(child: dayPanel),
                        ],
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: calendar,
                          ),
                          Expanded(child: dayPanel),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deletePlan(PlannedSession plan) async {
    final message = L10n.get(context, 'planner_deleted');
    await ref.read(plannerRepositoryProvider).deletePlan(plan.id);
    await ref.read(notificationServiceProvider).cancel(plan.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _showAddSheet(BuildContext context) async {
    LevelData? level;
    var time = const TimeOfDay(hour: 8, minute: 0);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.lg,
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
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<LevelData>(
                          value: level,
                          isExpanded: true,
                          dropdownColor: AppTheme.background,
                          hint: Text(L10n.get(context, 'scheduler_choose_level'),
                              style: const TextStyle(color: AppTheme.textDim)),
                          items: LevelData.levels.values
                              .map((l) => DropdownMenuItem(
                                    value: l,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                              color: l.color, shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: AppSpacing.md),
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
                            horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(time.format(context),
                                style: const TextStyle(
                                  color: AppTheme.textLight,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: [FontFeature.tabularFigures()],
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
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(AppRadius.md),
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
    final reminderTitle = L10n.get(context, 'planner_reminder_title');
    final levelName = L10n.get(context, level.title);
    final timeStr = time.format(context);
    final savedMessage = L10n.get(context, 'planner_saved');

    try {
      final planId = await ref.read(plannerRepositoryProvider).addPlan(
            scheduledAt: scheduledAt,
            levelKey: level.key,
          );
      await ref.read(notificationServiceProvider).scheduleOneTime(
            id: planId,
            when: scheduledAt.subtract(const Duration(minutes: 5)),
            title: reminderTitle,
            body: '$levelName • $timeStr',
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(savedMessage)));
      }
    } catch (e, st) {
      developer.log('Error saving plan',
          name: 'SchedulerScreen', error: e, stackTrace: st);
    }
  }
}

class _DayPanel extends StatelessWidget {
  const _DayPanel({
    required this.day,
    required this.plans,
    required this.onAdd,
    required this.onDelete,
    required this.onStart,
  });

  final DateTime day;
  final List<PlannedSession> plans;
  final VoidCallback onAdd;
  final ValueChanged<PlannedSession> onDelete;
  final ValueChanged<LevelData> onStart;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: plans.isEmpty
                ? _empty(context)
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: plans.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => _PlanTile(
                      plan: plans[i],
                      onDelete: () => onDelete(plans[i]),
                      onStart: onStart,
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          PressableScale(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppTheme.primary.withAlpha(120)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, color: AppTheme.primary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    L10n.get(context, 'planner_add'),
                    style: const TextStyle(
                      color: AppTheme.primary,
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

  Widget _empty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available_outlined,
              size: 48, color: AppTheme.textDim.withAlpha(110)),
          const SizedBox(height: AppSpacing.md),
          Text(
            L10n.get(context, 'planner_no_plans'),
            style: const TextStyle(color: AppTheme.textDim, fontSize: 14),
          ),
        ],
      ),
    );
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
    final name =
        level != null ? L10n.get(context, level.title) : plan.levelKey;
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
