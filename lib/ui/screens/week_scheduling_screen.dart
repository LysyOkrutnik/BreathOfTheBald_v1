import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/core/notifications/notification_service.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/logic/freediving/pb_readiness.dart';
import 'package:okrutnik_breath/logic/path/session_duration.dart';
import 'package:okrutnik_breath/logic/path/training_path.dart' show PathAction;
import 'package:okrutnik_breath/logic/path/weekly_plan.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/ui/screens/freediving/max_pb_test_screen.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';
import 'package:okrutnik_breath/ui/widgets/week_plan_strip.dart' show plannedActionColor, plannedActionIcon;

/// One suggested session still waiting for a time — [time]/[skipped] are the
/// only mutable state here; everything else is a fixed snapshot of what
/// [WeeklyPlanGenerator] suggested for this week, taken once when the screen
/// opens (see [_WeekSchedulingScreenState.initState] for why this can't just
/// be re-derived from `ref.watch` on every build).
class _SchedulableSession {
  _SchedulableSession({
    required this.action,
    required this.date,
    required this.estimatedDurationSec,
  });

  final PlannedAction action;
  final DateTime date;
  final int estimatedDurationSec;
  TimeOfDay? time;
  bool skipped = false;

  bool overlaps(_SchedulableSession other) {
    if (time == null || other.time == null) return false;
    if (date != other.date) return false;
    final start = time!.hour * 60 + time!.minute;
    final end = start + (estimatedDurationSec / 60).ceil();
    final otherStart = other.time!.hour * 60 + other.time!.minute;
    final otherEnd = otherStart + (other.estimatedDurationSec / 60).ceil();
    return start < otherEnd && otherStart < end;
  }
}

/// Replaces the old one-tap "auto-schedule the whole week" flow: shows every
/// session Twoja Ścieżka suggests for the coming days (matching the user's
/// own chosen availability), already filtered down to whatever isn't
/// already on the calendar, and lets them pick a time for each one
/// themselves instead of the app spreading them across an hour range no one
/// ever explicitly confirmed per session.
class WeekSchedulingScreen extends ConsumerStatefulWidget {
  const WeekSchedulingScreen({super.key});

  @override
  ConsumerState<WeekSchedulingScreen> createState() => _WeekSchedulingScreenState();
}

class _WeekSchedulingScreenState extends ConsumerState<WeekSchedulingScreen> {
  late final List<_SchedulableSession> _sessions;
  late final PbReadiness? _readiness;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // A one-time snapshot via `ref.read`, not `ref.watch` — this screen's
    // whole point is to hold a list of in-progress picks across possibly
    // several minutes of user interaction. Watching the underlying
    // providers directly would rebuild (and silently discard every pick
    // made so far) the moment any of them recomputes for an unrelated
    // reason while this screen is open.
    final plan = ref.read(weeklyPlanProvider);
    final existingPlans = ref.read(plannedSessionsProvider).value ?? const <PlannedSession>[];
    final freedivingProfile = ref.read(freedivingProfileProvider).value;
    _readiness = ref.read(freedivingReadinessProvider);
    _sessions = plan == null
        ? const []
        : _buildSchedulableSessions(plan, existingPlans, freedivingProfile, _readiness);
  }

  static List<_SchedulableSession> _buildSchedulableSessions(
    WeeklyPlan plan,
    List<PlannedSession> existingPlans,
    FreedivingProfileData? freedivingProfile,
    PbReadiness? readiness,
  ) {
    final today = DateTime.now();
    final existingKeysByDate = <DateTime, Set<String>>{};
    for (final p in existingPlans) {
      final day = DateTime(p.scheduledAt.year, p.scheduledAt.month, p.scheduledAt.day);
      existingKeysByDate.putIfAbsent(day, () => {}).add(p.levelKey);
    }
    // Defense in depth: WeeklyPlanGenerator already never places a CO2/O2
    // action unless the freediving PB readiness is active, so this should
    // never actually trigger — but this screen shouldn't have to trust that
    // invariant blindly to stay safe if it's ever violated.
    final readinessActive = readiness?.isActive ?? false;

    final result = <_SchedulableSession>[];
    for (final day in plan.days) {
      final date = DateTime(today.year, today.month, today.day + day.dayOffset);
      // Cold shower is a daily one-tap habit with its own always-visible
      // card, not something anyone picks a time for — same exclusion the
      // rest of the app already applies via trainingActionsOf.
      for (final action in trainingActionsOf(day.actions)) {
        if (!readinessActive &&
            (action.type == PathAction.co2Table || action.type == PathAction.o2Table)) {
          continue;
        }
        final key = plannableStorageKeyFor(action);
        if (key == null) continue;
        if (existingKeysByDate[date]?.contains(key) ?? false) {
          continue; // Already on the calendar — don't suggest it again.
        }
        result.add(_SchedulableSession(
          action: action,
          date: date,
          estimatedDurationSec:
              estimatedDurationSecForAction(action, freedivingProfile: freedivingProfile),
        ));
      }
    }
    return result;
  }

  bool get _allAssigned => _sessions.every((s) => s.skipped || s.time != null);

  Future<void> _pickTime(_SchedulableSession session) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: session.time ?? const TimeOfDay(hour: 8, minute: 0),
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
    if (picked == null) return;
    setState(() {
      session.time = picked;
      session.skipped = false;
    });
  }

  List<_SchedulableSession> _overlapsFor(_SchedulableSession session) => _sessions
      .where((other) => other != session && !other.skipped && session.overlaps(other))
      .toList();

  Future<void> _save() async {
    setState(() => _saving = true);
    final languageCode = Localizations.localeOf(context).languageCode;
    final reminderTitle = L10n.get(context, 'planner_reminder_title');
    final planner = ref.read(plannerRepositoryProvider);
    final notifications = ref.read(notificationServiceProvider);

    var savedCount = 0;
    for (final session in _sessions) {
      if (session.skipped || session.time == null) continue;
      final scheduledAt = DateTime(
        session.date.year,
        session.date.month,
        session.date.day,
        session.time!.hour,
        session.time!.minute,
      );
      // A reminder for a moment that's already passed would never fire —
      // silently drop it rather than saving a plan the user believes
      // carries a working reminder and doesn't (same rule the manual
      // Scheduler add-flow already enforces).
      if (scheduledAt.isBefore(DateTime.now())) continue;

      final levelKey = plannableStorageKeyFor(session.action)!;
      final levelName = plannedActionLabelForLocale(languageCode, session.action);
      final planId = await planner.addPlan(
        scheduledAt: scheduledAt,
        levelKey: levelKey,
        estimatedDurationSec: session.estimatedDurationSec,
      );
      await notifications.scheduleOneTime(
        id: planId,
        when: scheduledAt.subtract(const Duration(minutes: 5)),
        title: reminderTitle,
        body: levelName,
      );
      savedCount++;
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (savedCount == 0) {
      setState(() => _saving = false);
      messenger.showSnackBar(
          SnackBar(content: Text(L10n.get(context, 'week_scheduling_nothing_saved'))));
      return;
    }

    // Bulk-planning used to skip this entirely — a whole week's worth of
    // reminders could silently never fire on a stricter Android build,
    // with no indication why, unlike the one-by-one Scheduler add flow
    // which already checks this.
    final canScheduleExact = await notifications.canScheduleExactAlarms();
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(L10n.get(
          context, canScheduleExact ? 'path_week_planned_toast' : 'planner_saved_needs_permission')),
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.isTablet ? 640 : 560),
                child: Column(
                  children: [
                    ScreenHeader(title: L10n.get(context, 'week_scheduling_title')),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Text(
                        L10n.get(context,
                            _sessions.isEmpty ? 'week_scheduling_empty' : 'week_scheduling_intro'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppTheme.textDim.withAlpha(200), fontSize: 13, height: 1.4),
                      ),
                    ),
                    if (_readiness != null && !_readiness.isActive) ...[
                      const SizedBox(height: AppSpacing.md),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: PressableScale(
                          onTap: () => Navigator.of(context)
                              .push(fadeThroughRoute(const MaxPbTestScreen())),
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_outline_rounded,
                                    color: AppTheme.textDim, size: 18),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    L10n.get(
                                        context,
                                        _readiness.status == PbReadinessStatus.stale
                                            ? 'week_scheduling_pb_locked_stale'
                                            : 'week_scheduling_pb_locked_never'),
                                    style: const TextStyle(
                                        color: AppTheme.textDim, fontSize: 11, height: 1.3),
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded,
                                    color: AppTheme.textDim, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: _sessions.isEmpty
                          ? const SizedBox.shrink()
                          : ListView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                              children: [
                                for (final date in _sessions.map((s) => s.date).toSet()) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: AppSpacing.md, bottom: AppSpacing.sm),
                                    child: Text(
                                      toBeginningOfSentenceCase(
                                              DateFormat.MMMMEEEEd(locale).format(date)) ??
                                          '',
                                      style: const TextStyle(
                                        color: AppTheme.accent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  for (final session in _sessions.where((s) => s.date == date)) ...[
                                    _SessionRow(
                                      session: session,
                                      overlaps: _overlapsFor(session),
                                      onPickTime: () => _pickTime(session),
                                      onToggleSkip: () => setState(() => session.skipped = !session.skipped),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                  ],
                                ],
                              ],
                            ),
                    ),
                    if (_sessions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                        child: Opacity(
                          opacity: _allAssigned && !_saving ? 1.0 : 0.5,
                          child: PressableScale(
                            onTap: _allAssigned && !_saving ? _save : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                boxShadow: _allAssigned && !_saving
                                    ? AppTheme.glow(AppTheme.primary, blur: 18)
                                    : null,
                              ),
                              child: Text(
                                L10n.get(context, 'week_scheduling_save'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
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
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.session,
    required this.overlaps,
    required this.onPickTime,
    required this.onToggleSkip,
  });

  final _SchedulableSession session;
  final List<_SchedulableSession> overlaps;
  final VoidCallback onPickTime;
  final VoidCallback onToggleSkip;

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final color = plannedActionColor(session.action);
    final name = plannedActionLabelForLocale(languageCode, session.action);

    return Opacity(
      opacity: session.skipped ? 0.45 : 1.0,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(plannedActionIcon(session.action), color: color, size: 20),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(color: AppTheme.textLight, fontSize: 14),
                  ),
                ),
                if (!session.skipped)
                  PressableScale(
                    onTap: onPickTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: session.time == null ? Colors.white.withAlpha(14) : color.withAlpha(30),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                            color: session.time == null ? Colors.white24 : color.withAlpha(140)),
                      ),
                      child: Text(
                        session.time == null
                            ? L10n.get(context, 'week_scheduling_pick_time')
                            : session.time!.format(context),
                        style: TextStyle(
                          color: session.time == null ? Colors.white70 : color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  icon: Icon(
                    session.skipped ? Icons.replay_rounded : Icons.close_rounded,
                    color: Colors.white38,
                    size: 18,
                  ),
                  tooltip: L10n.get(context,
                      session.skipped ? 'week_scheduling_unskip' : 'week_scheduling_skip'),
                  onPressed: onToggleSkip,
                ),
              ],
            ),
            if (!session.skipped && overlaps.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Text(
                  L10n.get(context, 'week_scheduling_overlap_warning').replaceFirst(
                      '{names}',
                      overlaps
                          .map((o) => plannedActionLabelForLocale(languageCode, o.action))
                          .join(', ')),
                  style: const TextStyle(color: AppTheme.danger, fontSize: 11, height: 1.3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
