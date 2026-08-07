import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/logic/freediving/co2_o2_table_generator.dart';
import 'package:okrutnik_breath/logic/notifiers/session_notifier.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/logic/providers/settings_provider.dart';
import 'package:okrutnik_breath/ui/screens/home_shell_screen.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/glow_halo.dart';

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  bool _rpeSubmitted = false;

  String _fmt(Duration d) =>
      "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";

  FreedivingTableType? get _freedivingTableType {
    final type = ref.read(sessionProvider.notifier).lastFinishedExerciseType;
    if (type == ExerciseType.co2Table) return FreedivingTableType.co2;
    if (type == ExerciseType.o2Table) return FreedivingTableType.o2;
    return null;
  }

  Future<void> _submitRpe(int score) async {
    final tableType = _freedivingTableType;
    if (tableType == null) return;
    await ref
        .read(freedivingRepositoryProvider)
        .recordRpeAndAdjustPb(tableType: tableType, rpeScore: score);
    if (mounted) setState(() => _rpeSubmitted = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.read(sessionProvider);
    final duration = state.sessionDuration ?? Duration.zero;
    final tableType = _freedivingTableType;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.isTablet ? 640 : 480),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Badge()
                          .animate()
                          .scale(duration: AppMotion.slow, curve: Curves.easeOutBack)
                          .fadeIn(),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        L10n.get(context, 'summary_title'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 3.0,
                        ),
                      ).animate().fadeIn(delay: 150.ms),
                      const SizedBox(height: AppSpacing.sm),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                              color: Colors.white.withAlpha(160), fontSize: 15),
                          children: [
                            TextSpan(text: "${L10n.get(context, 'summary_great_job')}, "),
                            TextSpan(
                              text: ref.watch(settingsProvider).profileName.isEmpty
                                  ? L10n.get(context, 'summary_okrutnik')
                                  : ref.watch(settingsProvider).profileName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                            const TextSpan(text: "."),
                          ],
                        ),
                      ).animate().fadeIn(delay: 250.ms),
                      if (tableType != null) ...[
                        const SizedBox(height: AppSpacing.xl),
                        _RpeCard(
                          submitted: _rpeSubmitted,
                          onSubmit: _submitRpe,
                        ).animate().fadeIn(delay: 300.ms),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      _StatRow(
                        icon: Icons.timer_outlined,
                        label: L10n.get(context, 'summary_stat_duration'),
                        value: _fmt(duration),
                        delay: 300,
                      ),
                      if (state.totalRounds > 1) ...[
                        const SizedBox(height: AppSpacing.md),
                        _StatRow(
                          icon: Icons.all_inclusive_rounded,
                          label: L10n.get(context, 'summary_stat_rounds'),
                          value: "${state.totalRounds}",
                          delay: 380,
                        ),
                      ],
                      if (state.retentionLogs.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          L10n.get(context, 'summary_retention_times'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppTheme.textDim, fontSize: 12, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final e in state.retentionLogs.asMap().entries)
                              _RetentionChip(
                                round: e.key + 1,
                                time: _fmt(e.value),
                              ),
                          ],
                        ).animate().fadeIn(delay: 450.ms),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                      PressableScale(
                        onTap: () => Navigator.of(context).pushAndRemoveUntil(
                          fadeThroughRoute(const HomeShellScreen()),
                          (route) => false,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            boxShadow: AppTheme.glow(AppTheme.primary, blur: 26),
                          ),
                          child: Text(
                            L10n.get(context, 'summary_back_to_menu'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RpeCard extends StatefulWidget {
  const _RpeCard({required this.submitted, required this.onSubmit});
  final bool submitted;
  final ValueChanged<int> onSubmit;

  @override
  State<_RpeCard> createState() => _RpeCardState();
}

class _RpeCardState extends State<_RpeCard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    if (widget.submitted) {
      return GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppTheme.primary, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                L10n.get(context, 'freediving_rpe_thanks'),
                style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            L10n.get(context, 'freediving_rpe_question'),
            style: const TextStyle(
                color: AppTheme.textLight, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            L10n.get(context, 'freediving_rpe_hint'),
            style: const TextStyle(color: AppTheme.textDim, fontSize: 11),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 1; i <= 10; i++)
                GestureDetector(
                  onTap: () => setState(() => _selected = i),
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _selected == i
                          ? AppTheme.primary
                          : Colors.white.withAlpha(14),
                      border: Border.all(
                        color: _selected == i
                            ? AppTheme.primary
                            : Colors.white24,
                      ),
                    ),
                    child: Text(
                      '$i',
                      style: TextStyle(
                        color: _selected == i ? Colors.black : AppTheme.textLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Opacity(
            opacity: _selected == null ? 0.4 : 1.0,
            child: PressableScale(
              onTap: _selected == null ? null : () => widget.onSubmit(_selected!),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  L10n.get(context, 'freediving_rpe_submit'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlowHalo(
        color: AppTheme.primary,
        diameter: 108,
        haloScale: 1.9,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primary.withAlpha(24),
            border: Border.all(color: AppTheme.primary.withAlpha(90)),
          ),
          child: const Center(
            child: Icon(Icons.check_rounded, color: AppTheme.primary, size: 56),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.delay,
  });

  final IconData icon;
  final String label;
  final String value;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 26),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  color: Colors.white54, letterSpacing: 1.5, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).slideX(begin: 0.08);
  }
}

class _RetentionChip extends StatelessWidget {
  const _RetentionChip({required this.round, required this.time});
  final int round;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withAlpha(24)),
      ),
      child: Text(
        "${L10n.get(context, 'summary_retention_round')} $round: $time",
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }
}
