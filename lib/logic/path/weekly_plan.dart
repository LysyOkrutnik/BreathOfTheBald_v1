import 'dart:collection';

import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/logic/path/training_path.dart' show PathAction;
import 'package:okrutnik_breath/logic/wimhof/wimhof_progression.dart';

/// Every weekday, Monday-first — matches [DateTime.weekday]'s 1..7 range, so
/// it can be compared directly against a computed day's weekday. The default
/// for [WeeklyPlanGenerator.compute]'s `availableWeekdays` and for
/// [Settings.availableWeekdays].
const Set<int> kAllWeekdays = {1, 2, 3, 4, 5, 6, 7};

/// One suggested session within a day. Reuses [PathAction] (only wimHof,
/// pbTest, co2Table, o2Table and coldShower ever appear here —
/// [PathAction.rest] and [PathAction.maintain] have no place in a concrete
/// weekly plan; an empty [DayPlan.actions] list already means "rest").
class PlannedAction {
  const PlannedAction({required this.type, this.levelKey});

  final PathAction type;

  /// Set only for [PathAction.wimHof] — which ladder level to suggest.
  final String? levelKey;

  /// A "hard" session shares the same weekly intensity budget as every other
  /// hard session across disciplines (see [kWeeklyHardSessionCap]): the two
  /// toughest Wim Hof levels, the O2 table, and the (one-off) PB test. A cold
  /// shower isn't a breath-hold effort at all, so it never counts here.
  bool get isHard =>
      type == PathAction.pbTest ||
      type == PathAction.o2Table ||
      (type == PathAction.wimHof && kHardWimHofLevels.contains(levelKey));
}

/// [dayOffset] 0 is today. An empty [actions] list is a full rest day.
class DayPlan {
  const DayPlan({
    required this.dayOffset,
    required this.actions,
    this.isDesignatedRest = false,
  });

  final int dayOffset;
  final List<PlannedAction> actions;

  /// True only for the one day [WeeklyPlanGenerator] deliberately reserved
  /// as a rest day (see its `usableDays.removeLast()`) — an intentional,
  /// planned-for recovery day, as opposed to a day that just happens to
  /// have no training on it because there weren't enough sessions to fill
  /// every available slot. UI can use this to call out an *intended* rest
  /// day distinctly rather than treating every actions-empty day the same.
  final bool isDesignatedRest;
}

/// A rolling 7-day plan starting today ([DayPlan.dayOffset] 0..6).
class WeeklyPlan {
  const WeeklyPlan({required this.days});

  final List<DayPlan> days;
}

/// Builds the week that replaces the old single-focus-per-stage sequencing:
/// every discipline the user has unlocked — Wim Hof always, CO2/O2 as soon as
/// the PB is verified — gets a slot every week, from the very first stage.
/// Each discipline still decides its own difficulty exactly as before (the
/// Wim Hof ladder level via [WimHofProgression], the RPE-driven virtual PB
/// for the tables elsewhere) — this only decides which days they land on,
/// so a "harder" Wim Hof level or a rising virtual PB is what the sessions
/// placed here actually consist of, not how many of them there are.
class WeeklyPlanGenerator {
  WeeklyPlanGenerator._();

  static const int wimHofPerWeek = 4;
  static const int co2PerWeek = 2;
  static const int o2PerWeek = 2;
  static const int mobilityPerWeek = 2;

  // The 4 Mobility-tab guided routines — none needs a PB or a Wim Hof
  // level, so unlike every other discipline here they're plannable from
  // week one. Packing is deliberately excluded: it needs a verified PB
  // (see freediving_home_screen.dart's packing gate) and carries enough of
  // its own risk profile that auto-scheduling it into a generic weekly
  // rotation isn't something to do without a more deliberate design.
  static const List<String> mobilityLevelKeys = [
    'stretch_chest',
    'uddiyana_bandha',
    'resisted_breathing',
    'three_part_breath',
  ];

  static WeeklyPlan compute({
    required WimHofNextUp wimHof,
    required bool pbVerified,
    required int hardSessionsUsedThisWeek,
    Set<int> availableWeekdays = kAllWeekdays,
    bool allowMultiplePerDay = true,
    // Defaults to true (schedule it) for callers that don't track this —
    // the weekly plan provider is the one place that actually gates it on
    // a real first-visit flag; without that context, assuming "already
    // seen it" is the safer default over silently never scheduling a PB
    // test at all.
    bool freedivingVisited = true,
    int weeklyHardSessionCap = kWeeklyHardSessionCap,
    DateTime? now,
  }) {
    now ??= DateTime.now();

    // Offsets (0=today..6) whose calendar weekday the user marked available.
    // Left unrestricted (the default), the last offset is still reserved as
    // a guaranteed rest day — the same single-reserved-day fallback this
    // generator always had before availability became configurable.
    final usableDays = [
      for (var offset = 0; offset < 7; offset++)
        if (availableWeekdays
            .contains(now.add(Duration(days: offset)).weekday))
          offset,
    ];
    int? designatedRestOffset;
    if (availableWeekdays.length >= 7 && usableDays.length == 7) {
      designatedRestOffset = usableDays.removeLast();
    }
    // A fully-contradictory configuration (no day available at all) would
    // otherwise make every session "conflict" — fall back to the full week
    // rather than silently dropping the plan.
    final effectiveUsableDays = usableDays.isEmpty
        ? [for (var offset = 0; offset < 7; offset++) offset]
        : usableDays;

    // Suggest the recommended trial level when one is active, not just the
    // confirmed current level — otherwise the week's plan and the "Next Up"
    // card on the Wim Hof tab could recommend two different levels at once,
    // and the plan would never actually schedule the trial sessions needed
    // to confirm a promotion.
    final wimHofAction = PlannedAction(
        type: PathAction.wimHof,
        levelKey: wimHof.recommendedLevelKey ?? wimHof.currentLevelKey);

    final groups = <List<PlannedAction>>[];

    // Mobility never depends on PB or Wim Hof level — plannable from week
    // one, same as the daily cold shower below, and never "hard" (no
    // budget interaction at all). Rotates through all 4 routines instead
    // of always suggesting the same one, using the day of the year as a
    // stable-but-changing-week-to-week seed rather than persisting any new
    // state just for this.
    final mobilityStart = now.difference(DateTime(now.year)).inDays;
    groups.add([
      for (var i = 0; i < mobilityPerWeek; i++)
        PlannedAction(
          type: PathAction.mobility,
          levelKey: mobilityLevelKeys[(mobilityStart + i) % mobilityLevelKeys.length],
        ),
    ]);

    if (!pbVerified) {
      // Nothing to interleave with yet — but the PB test itself no longer
      // waits for Wim Hof mastery, it's scheduled as soon as the user has
      // actually seen the Freediving tab (and so knows what "PB" means)
      // rather than always from week one.
      if (freedivingVisited) {
        groups.add(const [PlannedAction(type: PathAction.pbTest)]);
      }
      groups.add(List.filled(wimHofPerWeek, wimHofAction));
    } else {
      // Wim Hof is the foundation of the method — under budget pressure it's
      // O2 (the single most hypoxia-intensive exercise in the app) that
      // gives way, never the other way around. This used to trim Wim Hof
      // down to zero first to reserve a guaranteed O2 slot, which meant a
      // Beast/Guru user under a tight cap could see their core practice
      // disappear from the week entirely so the app could still schedule
      // its riskiest table — pedagogically backwards. Wim Hof keeps at
      // least one session/week; O2 (below) is the one that can shrink to
      // zero instead.
      const minWimHofGuarantee = 1;
      var wimHofCount = wimHofPerWeek;
      if (wimHofAction.isHard) {
        while (wimHofCount > minWimHofGuarantee &&
            hardSessionsUsedThisWeek + wimHofCount > weeklyHardSessionCap) {
          wimHofCount--;
        }
      }
      groups.add(List.filled(wimHofCount, wimHofAction));
      groups.add(List.filled(
          co2PerWeek, const PlannedAction(type: PathAction.co2Table)));

      var o2Budget = o2PerWeek;
      final hardBeforeO2 =
          hardSessionsUsedThisWeek + (wimHofAction.isHard ? wimHofCount : 0);
      while (o2Budget > 0 && hardBeforeO2 + o2Budget > weeklyHardSessionCap) {
        o2Budget--;
      }
      if (o2Budget > 0) {
        groups.add(List.filled(
            o2Budget, const PlannedAction(type: PathAction.o2Table)));
      }
    }

    var sequence = _fairInterleave(groups);

    // With stacking disallowed, anything past one-per-available-day is
    // dropped for the week (lowest fair-interleave priority first) rather
    // than doubled up on a single day.
    if (!allowMultiplePerDay && sequence.length > effectiveUsableDays.length) {
      sequence = sequence.sublist(0, effectiveUsableDays.length);
    }

    final days = List.generate(7, (_) => <PlannedAction>[]);

    var cursor = 0;
    for (final action in sequence) {
      int? placedAt;
      var tier1Succeeded = false;

      // Tier 1: no same-discipline duplicate, no second hard session.
      for (var attempt = 0; attempt < effectiveUsableDays.length; attempt++) {
        final day = effectiveUsableDays[(cursor + attempt) % effectiveUsableDays.length];
        final sameTypeAlready = days[day].any((a) => a.type == action.type);
        final hasHardAlready = days[day].any((a) => a.isHard);
        if (!sameTypeAlready && !(action.isHard && hasHardAlready)) {
          placedAt = day;
          cursor = (cursor + attempt + 1) % effectiveUsableDays.length;
          tier1Succeeded = true;
          break;
        }
      }

      // Tier 2: too few available days for the hard-session rule to hold —
      // still never duplicate the exact same discipline on one day.
      if (placedAt == null) {
        final noDuplicate = effectiveUsableDays
            .where((d) => !days[d].any((a) => a.type == action.type));
        if (noDuplicate.isNotEmpty) {
          placedAt =
              noDuplicate.reduce((a, b) => days[a].length <= days[b].length ? a : b);
        }
      }

      // Tier 3: fewer available days than copies of this exact discipline
      // (e.g. 4 Wim Hof sessions but only 3 days picked) — a duplicate on one
      // day is genuinely unavoidable; place it on the lightest day.
      placedAt ??= effectiveUsableDays
          .reduce((a, b) => days[a].length <= days[b].length ? a : b);
      days[placedAt].add(action);

      // Tier 1 already advances `cursor` on its own success path above; a
      // Tier 2/3 fallback used to leave it untouched, so under tight
      // availability every subsequent action's Tier-1 scan restarted from
      // the exact same spot, biasing overflow toward the earliest usable
      // days instead of spreading it out. Advance it here too whenever
      // Tier 1 didn't already.
      if (!tier1Succeeded) {
        cursor = (cursor + 1) % effectiveUsableDays.length;
      }
    }

    // Cold showers are the third pillar of the Wim Hof method — a daily
    // habit independent of the breathing/table rotation above, so every day
    // gets one regardless of availability or rest days, and it never
    // competes for a day slot or counts against the hard-session budget.
    for (final day in days) {
      day.add(const PlannedAction(type: PathAction.coldShower));
    }

    return WeeklyPlan(
      days: [
        for (var i = 0; i < 7; i++)
          DayPlan(
            dayOffset: i,
            actions: days[i],
            isDesignatedRest: i == designatedRestOffset,
          ),
      ],
    );
  }

  /// Repeatedly takes one item from each non-empty group in turn, so e.g.
  /// four Wim Hof + two CO2 sessions come out as W,C,W,C,W,W instead of
  /// W,W,W,W,C,C — no discipline clumps together in the resulting sequence.
  static List<PlannedAction> _fairInterleave(List<List<PlannedAction>> groups) {
    final queues = groups.map(Queue<PlannedAction>.from).toList();
    final result = <PlannedAction>[];
    while (queues.any((q) => q.isNotEmpty)) {
      for (final q in queues) {
        if (q.isNotEmpty) result.add(q.removeFirst());
      }
    }
    return result;
  }
}

/// Full-sentence label for a single planned action (e.g. in a "today" list),
/// resolving a Wim Hof level name where relevant. Context-free so it's usable
/// from both widgets and the daily-reminder notification body.
String plannedActionLabelForLocale(String languageCode, PlannedAction action) {
  String tr(String key) => L10n.getForLocale(languageCode, key);
  switch (action.type) {
    case PathAction.wimHof:
      final level = LevelData.levels[action.levelKey];
      final name = level == null ? '' : tr(level.title);
      return '${tr('path_action_wimhof')} $name';
    case PathAction.pbTest:
      return tr('path_action_pbtest');
    case PathAction.co2Table:
      return tr('path_action_co2');
    case PathAction.o2Table:
      return tr('path_action_o2');
    case PathAction.coldShower:
      return tr('path_action_coldshower');
    case PathAction.mobility:
      final level = LevelData.levels[action.levelKey];
      final name = level == null ? '' : tr(level.title);
      return '${tr('path_action_mobility')} $name';
    case PathAction.rest:
    case PathAction.maintain:
      return tr('path_rest_day_label');
  }
}

/// Joins every *training* action planned for a single day into one line
/// (e.g. for the daily-reminder body or a compact status card) — "Rest day"
/// when there's nothing planned at all. The daily cold shower is excluded:
/// it's on every single day regardless, so it would just add noise here —
/// it gets its own always-visible checkbox wherever this is shown instead.
String todaySummaryLabelForLocale(String languageCode, List<PlannedAction> actions) {
  final training = trainingActionsOf(actions);
  if (training.isEmpty) {
    return L10n.getForLocale(languageCode, 'path_rest_day_label');
  }
  return training
      .map((a) => plannedActionLabelForLocale(languageCode, a))
      .join(' + ');
}

/// The non-cold-shower actions in a day's plan — the "training" part of the
/// day, as opposed to the always-present daily cold shower habit.
List<PlannedAction> trainingActionsOf(List<PlannedAction> actions) =>
    actions.where((a) => a.type != PathAction.coldShower).toList();

/// Short badge label for a single planned action, for compact week-strip
/// chips where a full sentence doesn't fit.
String plannedActionChipLabelForLocale(String languageCode, PlannedAction action) {
  String tr(String key) => L10n.getForLocale(languageCode, key);
  switch (action.type) {
    case PathAction.wimHof:
      final level = LevelData.levels[action.levelKey];
      return level == null ? '' : tr(level.title);
    case PathAction.pbTest:
      return tr('path_chip_pbtest');
    case PathAction.co2Table:
      return tr('path_chip_co2');
    case PathAction.o2Table:
      return tr('path_chip_o2');
    case PathAction.coldShower:
      return tr('path_chip_coldshower');
    case PathAction.mobility:
      final level = LevelData.levels[action.levelKey];
      return level == null ? '' : tr(level.title);
    case PathAction.rest:
    case PathAction.maintain:
      return tr('path_chip_rest');
  }
}
