import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/data/repositories/freediving_repository.dart';
import 'package:okrutnik_breath/logic/freediving/co2_o2_table_generator.dart';
import 'package:okrutnik_breath/logic/freediving/pb_readiness.dart';
import 'package:okrutnik_breath/logic/notifiers/session_notifier.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/logic/providers/settings_provider.dart';
import 'package:okrutnik_breath/ui/screens/freediving/custom_freediving_builder_screen.dart';
import 'package:okrutnik_breath/ui/screens/freediving/freediving_table_intro_screen.dart';
import 'package:okrutnik_breath/ui/screens/freediving/max_pb_test_screen.dart';
import 'package:okrutnik_breath/ui/screens/intro_screen.dart';
import 'package:okrutnik_breath/ui/screens/session_screen.dart';
import 'package:okrutnik_breath/ui/widgets/confirm_dialog.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The "Freediving" bottom-nav tab. Only ever shown as a shell tab root —
/// the shared background lives in HomeShellScreen so it isn't torn down and
/// rebuilt (with its animation restarting) every time the tab is switched.
class FreedivingHomeScreen extends ConsumerWidget {
  const FreedivingHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(freedivingProfileProvider);

    // One-way flag, no-ops once already set — Twoja Ścieżka's weekly plan
    // uses this to hold off scheduling a "Test PB" slot until the user has
    // actually seen where PB tests and the term itself live.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsProvider.notifier).markFreedivingVisited();
    });

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.isTablet ? 640 : 560),
          child: Column(
            children: [
              ScreenHeader(
                title: L10n.get(context, 'freediving_title'),
                showBackButton: false,
              ),
              Expanded(
                child: profileAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppTheme.danger),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (profile) {
                    if (profile == null || profile.safetyAcknowledgedAt == null) {
                      return _SafetyConsent(
                        onAccept: () => ref
                            .read(freedivingRepositoryProvider)
                            .acknowledgeSafety(),
                      );
                    }
                    return _FreedivingContent(profile: profile);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyConsent extends StatefulWidget {
  const _SafetyConsent({required this.onAccept});
  final VoidCallback onAccept;

  @override
  State<_SafetyConsent> createState() => _SafetyConsentState();
}

class _SafetyConsentState extends State<_SafetyConsent> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final rules = [
      'freediving_safety_rule1',
      'freediving_safety_rule2',
      'freediving_safety_rule3',
      'freediving_safety_rule4',
      'freediving_safety_rule5',
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
      children: [
        Icon(Icons.health_and_safety_rounded,
                color: AppTheme.danger, size: 48)
            .animate()
            .scale(duration: AppMotion.slow, curve: Curves.easeOutBack),
        const SizedBox(height: AppSpacing.md),
        Text(
          L10n.get(context, 'freediving_safety_title'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textLight,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          L10n.get(context, 'freediving_safety_intro'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textDim, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final key in rules)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: GlassCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              radius: AppRadius.md,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.priority_high_rounded,
                      color: AppTheme.danger, size: 18),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      L10n.get(context, key),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        GestureDetector(
          onTap: () => setState(() => _acknowledged = !_acknowledged),
          behavior: HitTestBehavior.opaque,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _acknowledged,
                activeColor: AppTheme.danger,
                onChanged: (v) => setState(() => _acknowledged = v ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    L10n.get(context, 'freediving_safety_checkbox'),
                    style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Opacity(
          opacity: _acknowledged ? 1.0 : 0.4,
          child: PressableScale(
            onTap: _acknowledged ? widget.onAccept : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppTheme.danger,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                L10n.get(context, 'freediving_safety_accept'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FreedivingContent extends ConsumerWidget {
  const _FreedivingContent({required this.profile});
  final FreedivingProfileData profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = ref.watch(freedivingReadinessProvider);
    // Re-locks the tables/packing once a verified test goes stale, not just
    // once no test has ever been done — see PbReadiness for the retest
    // window this keys off.
    final hasPb = readiness?.isActive ?? false;
    final presets =
        ref.watch(customFreedivingPresetsProvider).value ?? const <CustomFreedivingPreset>[];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
      children: [
        Text(
          L10n.get(context, 'freediving_intro'),
          style: const TextStyle(color: AppTheme.textDim, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.lg),
        _PbCard(profile: profile, readiness: readiness),
        if (hasPb) ...[
          const SizedBox(height: AppSpacing.lg),
          const _ProgressSection(),
        ],
        const SizedBox(height: AppSpacing.xl),
        if (hasPb) ...[
          _TableTile(
            tableType: FreedivingTableType.co2,
            titleKey: 'freediving_co2_title',
            subtitleKey: 'freediving_co2_subtitle',
            color: const Color(0xFF4FC3F7),
            icon: Icons.co2_rounded,
            pbSeconds: FreedivingRepository.effectivePb(
                tableType: FreedivingTableType.co2, profile: profile),
          ),
          const SizedBox(height: AppSpacing.md),
          _TableTile(
            tableType: FreedivingTableType.o2,
            titleKey: 'freediving_o2_title',
            subtitleKey: 'freediving_o2_subtitle',
            color: const Color(0xFFFF7043),
            icon: Icons.bolt_rounded,
            pbSeconds: FreedivingRepository.effectivePb(
                tableType: FreedivingTableType.o2, profile: profile),
          ),
        ] else
          // A single dimmed placeholder instead of two separate disabled
          // full-size tiles competing for attention with the PB card above,
          // which is the only thing actually actionable for a new user.
          const _LockedTablesPlaceholder(),
        const SizedBox(height: AppSpacing.md),
        // Packing carries the same real medical risk as the CO2/O2 tables
        // above (barotrauma, gas embolism, blackout) — it was previously
        // reachable with zero verified PB, less gated than the tables it
        // sits right next to. Same PB requirement, same locked-placeholder
        // pattern.
        hasPb ? const _PackingTile() : const _PackingLockedPlaceholder(),
        const SizedBox(height: AppSpacing.xl),
        _CustomFreedivingSection(presets: presets),
      ],
    );
  }
}

class _CustomFreedivingSection extends ConsumerWidget {
  const _CustomFreedivingSection({required this.presets});
  final List<CustomFreedivingPreset> presets;

  Future<void> _delete(BuildContext context, WidgetRef ref, CustomFreedivingPreset p) async {
    final confirmed = await showGlassConfirm(
      context,
      title: L10n.get(context, 'delete_confirm_title'),
      confirmLabel: L10n.get(context, 'delete_confirm_yes'),
      cancelLabel: L10n.get(context, 'delete_confirm_cancel'),
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed) {
      await ref.read(customFreedivingRepositoryProvider).deletePreset(p.id);
    }
  }

  // A custom table has no PB-relative safety cap at all, so this reminder is
  // its one safety checkpoint — it used to only fire when the preset was
  // first created, not on every subsequent reuse from this screen.
  Future<void> _start(BuildContext context, WidgetRef ref, CustomFreedivingPreset p) async {
    final confirmed = await showGlassConfirm(
      context,
      title: L10n.get(context, 'freediving_safety_confirm_title'),
      body: L10n.get(context, 'freediving_safety_rule1'),
      confirmLabel: L10n.get(context, 'freediving_start_table'),
      cancelLabel: L10n.get(context, 'common_cancel'),
      icon: Icons.warning_amber_rounded,
    );
    if (!confirmed || !context.mounted) return;
    final rounds = Co2O2TableGenerator.generateCustomTable(
      startApneaSec: p.startApneaSec,
      endApneaSec: p.endApneaSec,
      startRestSec: p.startRestSec,
      endRestSec: p.endRestSec,
      rounds: p.rounds,
    );
    final level = LevelData.customFreedivingTable(name: p.name, rounds: rounds);
    ref.read(sessionProvider.notifier).startSession(level);
    Navigator.of(context).push(fadeThroughRoute(const SessionScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              L10n.get(context, 'custom_freediving_section'),
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Container(height: 1, color: Colors.white.withAlpha(18))),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final p in presets) ...[
          _CustomFreedivingPresetCard(
            preset: p,
            onTap: () => _start(context, ref, p),
            onEdit: () => Navigator.of(context).push(
                fadeThroughRoute(CustomFreedivingBuilderScreen(existingPreset: p))),
            onDelete: () => _delete(context, ref, p),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        PressableScale(
          onTap: () => Navigator.of(context)
              .push(fadeThroughRoute(const CustomFreedivingBuilderScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppTheme.danger.withAlpha(120)),
              color: AppTheme.danger.withAlpha(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_rounded, color: AppTheme.danger, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  L10n.get(context, 'custom_freediving_create'),
                  style: const TextStyle(
                    color: AppTheme.danger,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Includes each round's breathe-up + final inhale + exhale overhead, same
/// as FreedivingTableIntroScreen's estimate — without it this card's number
/// disagreed with (and understated) what the session preview shows.
int _estimateMinutes(CustomFreedivingPreset p) {
  final rounds = Co2O2TableGenerator.generateCustomTable(
    startApneaSec: p.startApneaSec,
    endApneaSec: p.endApneaSec,
    startRestSec: p.startRestSec,
    endRestSec: p.endRestSec,
    rounds: p.rounds,
  );
  final totalSec = rounds.fold<int>(
      0,
      (s, r) =>
          s + r.apneaSec + r.restSec + FreedivingSessionTiming.perRoundOverheadSec);
  return (totalSec / 60).round();
}

class _CustomFreedivingPresetCard extends StatelessWidget {
  const _CustomFreedivingPresetCard({
    required this.preset,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final CustomFreedivingPreset preset;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: GlassCard(
        gradient: AppTheme.cardGradient(AppTheme.danger),
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md, horizontal: AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.tune_rounded, color: AppTheme.danger, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textLight,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '~${_estimateMinutes(preset)} min • '
                    '${preset.startApneaSec}-${preset.endApneaSec}s '
                    '${L10n.get(context, 'freediving_custom_summary_apnea_suffix')} • '
                    '${preset.startRestSec}-${preset.endRestSec}s '
                    '${L10n.get(context, 'freediving_custom_summary_rest_suffix')} • ${preset.rounds}×',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textDim.withAlpha(190)),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: Colors.white38, size: 20),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.white38, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _PbCard extends StatelessWidget {
  const _PbCard({required this.profile, required this.readiness});
  final FreedivingProfileData profile;
  final PbReadiness? readiness;

  @override
  Widget build(BuildContext context) {
    final verified = profile.verifiedPbSec;
    final locale = Localizations.localeOf(context).toString();
    final isStale = readiness?.status == PbReadinessStatus.stale;

    return GlassCard(
      // With no PB yet (or a stale one — see PbReadiness), this card's CTA
      // is the one thing actually required to unlock the rest of the tab —
      // give it a visible glow so it doesn't read as just another
      // equally-weighted card next to the (now dimmed) locked tables below.
      gradient: verified == null || isStale
          ? AppTheme.cardGradient(isStale ? AppTheme.danger : AppTheme.primary)
          : null,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            L10n.get(context, 'freediving_pb_section_title'),
            style: const TextStyle(
                color: AppTheme.textDim,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          if (verified != null) ...[
            Row(
              children: [
                Icon(Icons.timer_outlined, color: AppTheme.primary, size: 22),
                const SizedBox(width: AppSpacing.md),
                Text(
                  '${verified ~/ 60}:${(verified % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: AppTheme.textLight,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(L10n.get(context, 'freediving_pb_verified_label'),
                    style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
              ],
            ),
            if (profile.verifiedPbAt != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${L10n.get(context, 'freediving_pb_tested_on')} '
                '${DateFormat('dd.MM.yyyy', locale).format(profile.verifiedPbAt!)}',
                style: TextStyle(color: AppTheme.textDim.withAlpha(180), fontSize: 11),
              ),
            ],
            if (isStale) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      L10n.get(context, 'freediving_pb_expired_body'),
                      style: const TextStyle(color: AppTheme.danger, fontSize: 12, height: 1.3),
                    ),
                  ),
                ],
              ),
            ],
            if (profile.verifiedPbCo2Sec != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.timer_outlined, color: AppTheme.accent, size: 18),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '${profile.verifiedPbCo2Sec! ~/ 60}:'
                    '${(profile.verifiedPbCo2Sec! % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: AppTheme.textLight,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(L10n.get(context, 'freediving_pb_verified_co2_label'),
                      style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
                ],
              ),
            ],
          ] else
            Text(
              L10n.get(context, 'freediving_pb_none'),
              style: const TextStyle(color: AppTheme.textDim, fontSize: 13),
            ),
          const SizedBox(height: AppSpacing.md),
          PressableScale(
            onTap: () => Navigator.of(context)
                .push(fadeThroughRoute(const MaxPbTestScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: (isStale ? AppTheme.danger : AppTheme.primary).withAlpha(30),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border:
                    Border.all(color: (isStale ? AppTheme.danger : AppTheme.primary).withAlpha(120)),
              ),
              child: Text(
                L10n.get(
                    context,
                    verified == null
                        ? 'freediving_pb_test_cta'
                        : isStale
                            ? 'freediving_pb_retest_expired'
                            : 'freediving_pb_retest'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isStale ? AppTheme.danger : AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recent-progress rollup, contextual to this tab rather than a duplicate of
/// StatsScreen (which is unified across all disciplines and has no
/// freediving-specific breakdown at all). Hidden entirely until there's at
/// least one logged table — an all-zero card would just be noise for a
/// brand-new user.
class _ProgressSection extends ConsumerWidget {
  const _ProgressSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(freedivingProgressProvider);
    if (progress.co2SessionsCompleted == 0 && progress.o2SessionsCompleted == 0) {
      return const SizedBox.shrink();
    }

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            L10n.get(context, 'freediving_progress_title'),
            style: const TextStyle(
                color: AppTheme.textDim,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _ProgressStat(
                  icon: Icons.co2_rounded,
                  color: const Color(0xFF4FC3F7),
                  label: L10n.get(context, 'freediving_co2_title'),
                  value: '${progress.co2SessionsCompleted}',
                ),
              ),
              Expanded(
                child: _ProgressStat(
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFFFF7043),
                  label: L10n.get(context, 'freediving_o2_title'),
                  value: '${progress.o2SessionsCompleted}',
                ),
              ),
            ],
          ),
          if (progress.avgContractionRatio != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const Icon(Icons.waves_rounded, color: AppTheme.accent, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    L10n.get(context, 'freediving_progress_contraction_trend'),
                    style: TextStyle(fontSize: 12, color: AppTheme.textDim.withAlpha(190)),
                  ),
                ),
                Text(
                  '${(progress.avgContractionRatio! * 100).round()}%',
                  style: const TextStyle(
                      color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressStat extends StatelessWidget {
  const _ProgressStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.textLight,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textDim.withAlpha(190))),
          ],
        ),
      ],
    );
  }
}

class _TableTile extends StatelessWidget {
  const _TableTile({
    required this.tableType,
    required this.titleKey,
    required this.subtitleKey,
    required this.color,
    required this.icon,
    required this.pbSeconds,
  });

  final FreedivingTableType tableType;
  final String titleKey;
  final String subtitleKey;
  final Color color;
  final IconData icon;
  final int pbSeconds;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => Navigator.of(context).push(fadeThroughRoute(
        FreedivingTableIntroScreen(tableType: tableType, pbSeconds: pbSeconds),
      )),
      child: GlassCard(
        gradient: AppTheme.cardGradient(color),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L10n.get(context, titleKey),
                    style: const TextStyle(
                      color: AppTheme.textLight,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    L10n.get(context, subtitleKey),
                    style: TextStyle(fontSize: 12, color: AppTheme.textDim.withAlpha(190)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withAlpha(160), size: 20),
          ],
        ),
      ),
    );
  }
}

/// A single dimmed row standing in for both tables while no PB exists yet —
/// two separate disabled full-size tiles previously competed visually with
/// the PB card above, which is the only thing actually actionable here.
class _LockedTablesPlaceholder extends StatelessWidget {
  const _LockedTablesPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.6,
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: Colors.white24, size: 24),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L10n.get(context, 'freediving_locked_tables_title'),
                    style: const TextStyle(
                        color: AppTheme.textDim, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    L10n.get(context, 'freediving_locked_no_pb'),
                    style: TextStyle(fontSize: 12, color: AppTheme.textDim.withAlpha(190)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Packing's equivalent of [_LockedTablesPlaceholder] — same visual
/// treatment, same reasoning (a dimmed row beats a disabled full-size tile
/// competing with the PB card above), shown until a PB exists.
class _PackingLockedPlaceholder extends StatelessWidget {
  const _PackingLockedPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.6,
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: Colors.white24, size: 24),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L10n.get(context, 'exercise_packing_title'),
                    style: const TextStyle(
                        color: AppTheme.textDim, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    L10n.get(context, 'freediving_packing_locked_body'),
                    style: TextStyle(fontSize: 12, color: AppTheme.textDim.withAlpha(190)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Packing — a real freediving technique with documented medical risk
/// (pulmonary barotrauma, gas embolism, blackout before the dive). Already
/// sits behind this screen's safety-consent gate; on top of that, a
/// one-time warning dialog shows before its very first use (same
/// SharedPreferences "shown once" pattern as the session screen's Ghost
/// Mode hint and the scheduler's week-preferences first-visit sheet) —
/// deliberately not a repeated gate, just a single, unmissable disclosure.
class _PackingTile extends ConsumerStatefulWidget {
  const _PackingTile();

  @override
  ConsumerState<_PackingTile> createState() => _PackingTileState();
}

class _PackingTileState extends ConsumerState<_PackingTile> {
  static const _warningShownKey = 'packing_warning_shown';

  Future<void> _open(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_warningShownKey) ?? false)) {
      if (!context.mounted) return;
      final confirmed = await showGlassConfirm(
        context,
        title: L10n.get(context, 'packing_warning_title'),
        body: L10n.get(context, 'packing_warning_body'),
        confirmLabel: L10n.get(context, 'packing_warning_confirm'),
        cancelLabel: L10n.get(context, 'delete_confirm_cancel'),
        icon: Icons.warning_amber_rounded,
        confirmColor: AppTheme.danger,
      );
      if (!confirmed) return;
      await prefs.setBool(_warningShownKey, true);
    }
    if (!context.mounted) return;
    final level = LevelData.packing(gulpCount: ref.read(packingGulpCountProvider));
    Navigator.of(context).push(fadeThroughRoute(IntroScreen(level: level)));
  }

  @override
  Widget build(BuildContext context) {
    // Display-only metadata (title/subtitle/color never vary with gulp
    // count) — the static entry is fine here; _open builds the real,
    // gulp-count-aware level for the actual session.
    final level = LevelData.levels['freediving_packing']!;
    return PressableScale(
      onTap: () => _open(context),
      child: GlassCard(
        gradient: AppTheme.cardGradient(level.color),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: level.color, size: 26),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L10n.get(context, 'exercise_packing_title'),
                    style: const TextStyle(
                      color: AppTheme.textLight,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    L10n.get(context, 'exercise_packing_subtitle'),
                    style: TextStyle(fontSize: 12, color: AppTheme.textDim.withAlpha(190)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: level.color.withAlpha(160), size: 20),
          ],
        ),
      ),
    );
  }
}
