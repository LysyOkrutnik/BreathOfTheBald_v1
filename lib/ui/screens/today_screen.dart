import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/core/notifications/notification_service.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/data/repositories/freediving_repository.dart';
import 'package:okrutnik_breath/logic/freediving/co2_o2_table_generator.dart';
import 'package:okrutnik_breath/logic/path/cold_shower.dart';
import 'package:okrutnik_breath/logic/path/training_path.dart';
import 'package:okrutnik_breath/logic/path/weekly_plan.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/logic/providers/settings_provider.dart';
import 'package:okrutnik_breath/ui/screens/freediving/freediving_table_intro_screen.dart';
import 'package:okrutnik_breath/ui/screens/freediving/max_pb_test_screen.dart';
import 'package:okrutnik_breath/ui/screens/intro_screen.dart';
import 'package:okrutnik_breath/ui/widgets/cold_shower_card.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';
import 'package:okrutnik_breath/ui/widgets/week_plan_strip.dart';
import 'package:okrutnik_breath/ui/widgets/week_preferences_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The "Dziś" bottom-nav tab — the single hub replacing the old Wim Hof tab
/// as the app's landing screen. Consolidates what used to be split across
/// three places: the standalone "Twoja Ścieżka" push screen (today's plan,
/// the week rotation, the six-stage journey), the Wim Hof tab's status card,
/// and the cold-shower quick-log duplicated on two other screens. Only ever
/// shown as a shell tab root — the shared background lives in
/// HomeShellScreen so it isn't torn down and rebuilt every time the tab is
/// switched.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  static const _stages = PathStage.values;
  static const _pbTestDueAfter = Duration(days: 7);

  Future<void> _startAction(
      BuildContext context, WidgetRef ref, PlannedAction action) async {
    switch (action.type) {
      case PathAction.wimHof:
      case PathAction.mobility:
        final level = LevelData.levels[action.levelKey];
        if (level != null) {
          Navigator.of(context).push(fadeThroughRoute(IntroScreen(level: level)));
        }
      case PathAction.pbTest:
        Navigator.of(context).push(fadeThroughRoute(const MaxPbTestScreen()));
      case PathAction.co2Table:
      case PathAction.o2Table:
        final profile = ref.read(freedivingProfileProvider).value;
        if (profile == null) return;
        final pb = FreedivingRepository.effectivePb(
          tableType: action.type == PathAction.co2Table
              ? FreedivingTableType.co2
              : FreedivingTableType.o2,
          profile: profile,
        );
        if (pb <= 0) return;
        Navigator.of(context).push(fadeThroughRoute(FreedivingTableIntroScreen(
          tableType: action.type == PathAction.co2Table
              ? FreedivingTableType.co2
              : FreedivingTableType.o2,
          pbSeconds: pb,
        )));
      case PathAction.coldShower:
        break; // Handled by the standalone ColdShowerCard control instead.
      case PathAction.rest:
      case PathAction.maintain:
        break; // Informational only — nothing to start.
    }
  }

  /// The plannable key for a single action, or null when it isn't a real
  /// schedulable session.
  String? _plannableKey(PlannedAction action) {
    switch (action.type) {
      case PathAction.wimHof:
      case PathAction.mobility:
        return action.levelKey;
      case PathAction.pbTest:
        return 'freediving_pb_test';
      case PathAction.co2Table:
        return 'freediving_co2';
      case PathAction.o2Table:
        return 'freediving_o2';
      case PathAction.coldShower:
        return coldShowerLevelKey;
      case PathAction.rest:
      case PathAction.maintain:
        return null;
    }
  }

  /// Spreads [count] sessions evenly across the user's available hour
  /// window, so every scheduled time actually falls inside the range they
  /// picked instead of drifting past it via fixed per-discipline offsets.
  /// A single session lands at the start of the window; more than one are
  /// spaced as evenly as the window allows.
  List<int> _hoursForDay(int count, int startHour, int endHour) {
    if (count <= 0) return const [];
    if (count == 1) return [startHour];
    final span = (endHour - startHour).clamp(0, 23);
    final step = span / (count - 1);
    return [
      for (var i = 0; i < count; i++) (startHour + (step * i).round()).clamp(0, 23),
    ];
  }

  Future<void> _planWeek(BuildContext context, WidgetRef ref, WeeklyPlan plan) async {
    final languageCode = Localizations.localeOf(context).languageCode;
    final reminderTitle = L10n.get(context, 'planner_reminder_title');
    final messenger = ScaffoldMessenger.of(context);
    final planner = ref.read(plannerRepositoryProvider);
    final notifications = ref.read(notificationServiceProvider);
    final settings = ref.read(settingsProvider);
    final today = DateTime.now();

    try {
      for (final day in plan.days) {
        final plannable = [
          for (final action in day.actions)
            if (_plannableKey(action) != null) action,
        ];
        final hours = _hoursForDay(
            plannable.length, settings.availableHourStart, settings.availableHourEnd);
        final usedHours = <int>{};

        for (var i = 0; i < plannable.length; i++) {
          final action = plannable[i];
          final levelKey = _plannableKey(action)!;

          var hour = hours[i];
          while (usedHours.contains(hour)) {
            hour = (hour + 1) % 24;
          }
          usedHours.add(hour);

          final scheduledAt = DateTime(
              today.year, today.month, today.day + day.dayOffset, hour);
          if (scheduledAt.isBefore(DateTime.now())) continue;

          final level = LevelData.levels[levelKey];
          final levelName =
              level != null ? L10n.getForLocale(languageCode, level.title) : levelKey;

          final planId = await planner.addPlan(
            scheduledAt: scheduledAt,
            levelKey: levelKey,
          );
          await notifications.scheduleOneTime(
            id: planId,
            when: scheduledAt.subtract(const Duration(minutes: 5)),
            title: reminderTitle,
            body: levelName,
          );
        }
      }
      if (context.mounted) {
        messenger.showSnackBar(
            SnackBar(content: Text(L10n.get(context, 'path_week_planned_toast'))));
      }
    } catch (_) {
      // Best-effort — the planner tab itself remains the reliable fallback.
    }
  }

  bool _pbTestDue(FreedivingProfileData? profile) {
    if (profile == null || profile.safetyAcknowledgedAt == null) return false;
    if (profile.verifiedPbAt == null) return true;
    return DateTime.now().difference(profile.verifiedPbAt!) >= _pbTestDueAfter;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(trainingPathProvider);
    final plan = ref.watch(weeklyPlanProvider);
    final userProfile = ref.watch(userProfileProvider).value;
    final freedivingProfile = ref.watch(freedivingProfileProvider).value;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.isTablet ? 640 : 560),
          child: Column(
            children: [
              ScreenHeader(
                title: L10n.get(context, 'nav_today'),
                showBackButton: false,
              ),
              Expanded(
                child: (path == null || plan == null)
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.primary),
                      )
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                        children: [
                          _ProfileHeaderRow(profile: userProfile),
                          const SizedBox(height: AppSpacing.lg),
                          if (_pbTestDue(freedivingProfile)) ...[
                            _PbTestDueCard(
                              neverTested: freedivingProfile?.verifiedPbAt == null,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          _TodayCard(
                            actions: plan.days.first.actions,
                            isDesignatedRest: plan.days.first.isDesignatedRest,
                            onStart: (a) => _startAction(context, ref, a),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _WeekSection(
                            plan: plan,
                            onPlanWeek: () => _planWeek(context, ref, plan),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _JourneySection(stages: _stages, currentStage: path.stage),
                        ].animate(interval: 60.ms).fadeIn(duration: AppMotion.medium),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeaderRow extends StatelessWidget {
  const _ProfileHeaderRow({required this.profile});
  final UserProfileData? profile;

  @override
  Widget build(BuildContext context) {
    final level = profile?.level ?? 1;
    final streak = profile?.dailyStreak ?? 0;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.military_tech_outlined, color: AppTheme.primary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text('${L10n.get(context, 'stats_level')} $level', style: AppTheme.titleMedium),
          const Spacer(),
          Icon(Icons.local_fire_department_outlined, color: AppTheme.lure, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text('$streak ${L10n.get(context, 'stats_streak')}', style: AppTheme.titleMedium),
        ],
      ),
    );
  }
}

class _PbTestDueCard extends StatelessWidget {
  const _PbTestDueCard({required this.neverTested});
  final bool neverTested;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () =>
          Navigator.of(context).push(fadeThroughRoute(const MaxPbTestScreen())),
      child: GlassCard(
        gradient: AppTheme.cardGradient(AppTheme.primary),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, color: AppTheme.primary, size: 24),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L10n.get(context, 'today_pbtest_due_title'),
                    style: const TextStyle(
                        color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    L10n.get(context,
                        neverTested ? 'today_pbtest_due_body_new' : 'today_pbtest_due_body_retest'),
                    style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.primary, size: 20),
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppMotion.medium);
  }
}

_StageRelation _relativeTo(PathStage stage, PathStage current) {
  if (stage.index < current.index) return _StageRelation.done;
  if (stage.index == current.index) return _StageRelation.current;
  return _StageRelation.upcoming;
}

class _WeekSection extends ConsumerStatefulWidget {
  const _WeekSection({required this.plan, required this.onPlanWeek});
  final WeeklyPlan plan;
  final VoidCallback onPlanWeek;

  @override
  ConsumerState<_WeekSection> createState() => _WeekSectionState();
}

class _WeekSectionState extends ConsumerState<_WeekSection> {
  static const _firstVisitPrefsKey = 'week_prefs_first_visit_shown';

  @override
  void initState() {
    super.initState();
    _maybeShowPrefsOnFirstVisit();
  }

  /// The week is generated from sane defaults either way, but a user who's
  /// never told the app when they're actually free will get a plan that
  /// doesn't match their real schedule — surfacing the preferences sheet
  /// once, the very first time this section is seen, catches that before
  /// they ever hit "ZAPLANUJ CAŁY TYDZIEŃ" on an unconfigured week.
  Future<void> _maybeShowPrefsOnFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_firstVisitPrefsKey) ?? false) return;
    await prefs.setBool(_firstVisitPrefsKey, true);
    if (mounted) WeekPreferencesSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L10n.get(context, 'path_week_section_title'),
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            L10n.get(context, 'path_week_intro'),
            style: TextStyle(color: AppTheme.textDim.withAlpha(200), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          WeekPlanStrip(plan: widget.plan),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: PressableScale(
                  onTap: () => WeekPreferencesSheet.show(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppTheme.accent.withAlpha(140)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.tune_rounded, color: AppTheme.accent, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            L10n.get(context, 'path_configure_week_button'),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PressableScale(
                  onTap: widget.onPlanWeek,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: AppTheme.glow(AppTheme.accent, blur: 18),
                    ),
                    child: Text(
                      L10n.get(context, 'path_plan_week_button'),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            L10n.get(context, 'path_plan_week_note'),
            style: TextStyle(color: AppTheme.textDim.withAlpha(160), fontSize: 10, height: 1.3),
          ),
        ],
      ),
    );
  }
}

/// The six-stage narrative, collapsed to just the current stage by default —
/// it's informational, doesn't change day to day, and previously forced
/// every visit to scroll past all six cards before reaching anything
/// actionable. Expandable on demand for anyone who wants the big picture.
class _JourneySection extends StatefulWidget {
  const _JourneySection({required this.stages, required this.currentStage});
  final List<PathStage> stages;
  final PathStage currentStage;

  @override
  State<_JourneySection> createState() => _JourneySectionState();
}

class _JourneySectionState extends State<_JourneySection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.stages.indexOf(widget.currentStage);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L10n.get(context, 'path_intro'),
            style: const TextStyle(color: AppTheme.textDim, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          _StageRow(
            stage: widget.currentStage,
            index: currentIndex + 1,
            state: _StageRelation.current,
          ),
          AnimatedSize(
            duration: AppMotion.medium,
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(
                    children: [
                      for (final stage in widget.stages)
                        if (stage != widget.currentStage)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.md),
                            child: _StageRow(
                              stage: stage,
                              index: widget.stages.indexOf(stage) + 1,
                              state: _relativeTo(stage, widget.currentStage),
                            ),
                          ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: AppSpacing.sm),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    L10n.get(context,
                        _expanded ? 'path_journey_collapse' : 'path_journey_expand'),
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: AppTheme.accent,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends ConsumerWidget {
  const _TodayCard({
    required this.actions,
    required this.onStart,
    this.isDesignatedRest = false,
  });
  final List<PlannedAction> actions;
  final ValueChanged<PlannedAction> onStart;

  /// True when today isn't just incidentally empty (ran out of sessions to
  /// place) but is the week's deliberately-reserved recovery day — see
  /// [DayPlan.isDesignatedRest].
  final bool isDesignatedRest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The cold shower is a daily habit, not part of the interleaved
    // discipline rotation — shown via the standalone ColdShowerCard control
    // rather than mixed into the training list below.
    final trainingActions = trainingActionsOf(actions);

    return GlassCard(
      gradient: AppTheme.cardGradient(AppTheme.accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L10n.get(context, 'path_today_label'),
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (trainingActions.isEmpty)
            Text(
              L10n.get(context,
                  isDesignatedRest ? 'path_designated_rest_label' : 'path_rest_day_label'),
              style: const TextStyle(color: AppTheme.textLight, fontSize: 15),
            )
          else
            for (var i = 0; i < trainingActions.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              _TodayActionRow(
                  action: trainingActions[i],
                  onTap: () => onStart(trainingActions[i])),
            ],
          const SizedBox(height: AppSpacing.sm),
          const ColdShowerCard(),
        ],
      ),
    );
  }
}

class _TodayActionRow extends StatelessWidget {
  const _TodayActionRow({required this.action, required this.onTap});
  final PlannedAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final color = plannedActionColor(action);
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm, horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: Colors.white.withAlpha(14),
        ),
        child: Row(
          children: [
            Icon(plannedActionIcon(action), color: color, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                plannedActionLabelForLocale(languageCode, action),
                style: const TextStyle(color: AppTheme.textLight, fontSize: 14),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withAlpha(200), size: 20),
          ],
        ),
      ),
    );
  }
}

enum _StageRelation { done, current, upcoming }

class _StageRow extends StatelessWidget {
  const _StageRow({required this.stage, required this.index, required this.state});
  final PathStage stage;
  final int index;
  final _StageRelation state;

  @override
  Widget build(BuildContext context) {
    final isCurrent = state == _StageRelation.current;
    final isDone = state == _StageRelation.done;
    final color = isCurrent
        ? AppTheme.accent
        : (isDone ? AppTheme.primary : AppTheme.textDim);

    return GlassCard(
      gradient: isCurrent ? AppTheme.cardGradient(AppTheme.accent) : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha(30),
              border: Border.all(color: color.withAlpha(160)),
            ),
            child: isDone
                ? Icon(Icons.check_rounded, color: color, size: 16)
                : Text('$index',
                    style: TextStyle(
                        color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.get(context, stageTitleKey(stage)),
                  style: TextStyle(
                    color: isDone || isCurrent ? AppTheme.textLight : AppTheme.textDim,
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  L10n.get(context, stageDescKey(stage)),
                  style: TextStyle(color: AppTheme.textDim.withAlpha(190), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
