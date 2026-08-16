import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/logic/freediving/co2_o2_table_generator.dart';
import 'package:okrutnik_breath/logic/notifiers/session_notifier.dart';
import 'package:okrutnik_breath/ui/screens/session_screen.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';

/// Shows the exact, calculated round-by-round schedule for a CO2/O2 table
/// (generated from the caller's current working PB) before starting, plus a
/// persistent safety reminder — the equivalent of [IntroScreen] for the other
/// exercise types, but with a table preview instead of a generic step list.
class FreedivingTableIntroScreen extends ConsumerWidget {
  const FreedivingTableIntroScreen({
    super.key,
    required this.tableType,
    required this.pbSeconds,
  });

  final FreedivingTableType tableType;
  final int pbSeconds;

  bool get _isCo2 => tableType == FreedivingTableType.co2;

  void _start(BuildContext context, WidgetRef ref) {
    final level = LevelData.freedivingTable(tableType: tableType, pbSeconds: pbSeconds);
    ref.read(sessionProvider.notifier).startSession(level);
    Navigator.of(context).pushReplacement(fadeThroughRoute(const SessionScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _isCo2 ? const Color(0xFF4FC3F7) : const Color(0xFFFF7043);
    final level = LevelData.freedivingTable(tableType: tableType, pbSeconds: pbSeconds);
    final rounds = level.freedivingRounds!;
    // Includes each round's breathe-up + final inhale + exhale — omitting
    // that overhead would understate real session length by several minutes
    // over a full table (see FreedivingSessionTiming).
    final totalSec = rounds.fold<int>(
        0,
        (s, r) =>
            s + r.apneaSec + r.restSec + FreedivingSessionTiming.perRoundOverheadSec);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: AppBackground(sectionAccent: color)),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.isTablet ? 640 : 560),
                child: Column(
                  children: [
                    ScreenHeader(
                        title: L10n.get(context, _isCo2 ? 'freediving_co2_title' : 'freediving_o2_title')),
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                        children: [
                          Text(
                            L10n.get(context, _isCo2 ? 'freediving_co2_desc' : 'freediving_o2_desc'),
                            style: const TextStyle(
                                color: AppTheme.textDim, fontSize: 13, height: 1.5),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          GlassCard(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            radius: AppRadius.md,
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: AppTheme.danger, size: 18),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    L10n.get(context, 'freediving_safety_rule1'),
                                    style: const TextStyle(
                                        color: AppTheme.danger, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Row(
                            children: [
                              Text(
                                L10n.get(context, 'freediving_table_preview_title'),
                                style: const TextStyle(
                                    color: AppTheme.textDim,
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              Text(
                                '~${(totalSec / 60).ceil()} min',
                                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          for (final round in rounds)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _RoundRow(round: round, color: color),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: PressableScale(
                        onTap: () => _start(context, ref),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            boxShadow: AppTheme.glow(color, blur: 20),
                          ),
                          child: Text(
                            L10n.get(context, 'freediving_start_table'),
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
        ],
      ),
    );
  }
}

class _RoundRow extends StatelessWidget {
  const _RoundRow({required this.round, required this.color});
  final BreathHoldRound round;
  final Color color;

  String _fmt(int seconds) =>
      "${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${round.index}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Icon(Icons.pause_circle_outline_rounded, color: color, size: 16),
                const SizedBox(width: 6),
                Text(
                  _fmt(round.apneaSec),
                  style: const TextStyle(
                    color: AppTheme.textLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.air_rounded, color: AppTheme.textDim, size: 16),
                const SizedBox(width: 6),
                Text(
                  _fmt(round.restSec),
                  style: const TextStyle(
                    color: AppTheme.textDim,
                    fontSize: 13,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
