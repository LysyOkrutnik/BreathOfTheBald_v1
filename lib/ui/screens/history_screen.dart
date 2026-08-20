import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';
import 'package:okrutnik_breath/ui/widgets/shimmer.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.isTablet ? 720 : double.infinity),
                child: Column(
                  children: [
                    ScreenHeader(title: L10n.get(context, 'history_title')),
                    const Expanded(child: HistoryContent()),
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

/// The session list — extracted from [HistoryScreen] so it can be embedded
/// directly inside a tab (no nested Scaffold/background) as well as shown as
/// its own pushed screen.
class HistoryContent extends ConsumerWidget {
  const HistoryContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(sessionHistoryProvider);

    return historyAsync.when(
      loading: () => const _LoadingSkeleton(),
      error: (_, __) => const _EmptyState(),
      data: (sessions) {
        if (sessions.isEmpty) return const _EmptyState();
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: sessions.length,
          itemBuilder: (context, index) => _SessionCard(
            session: sessions[index],
            index: index,
          ),
        );
      },
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: ShimmerBox(height: 76),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.self_improvement,
              size: 64, color: AppTheme.textDim.withAlpha(120)),
          const SizedBox(height: AppSpacing.md),
          Text(
            L10n.get(context, 'history_empty'),
            style: const TextStyle(color: AppTheme.textDim, fontSize: 16),
          ),
        ],
      ).animate().fadeIn(duration: AppMotion.slow),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.index});

  final Session session;
  final int index;

  String _levelName(BuildContext context) {
    final level = LevelData.levels[session.levelKey];
    return level != null ? L10n.get(context, level.title) : session.levelKey;
  }

  Color _levelColor() =>
      LevelData.levels[session.levelKey]?.color ?? AppTheme.primary;

  String _fmt(int seconds) =>
      "${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    final color = _levelColor();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GlassCard(
        gradient: AppTheme.cardGradient(color),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: AppTheme.glow(color, blur: 10),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _levelName(context),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textLight,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    DateFormat('dd.MM.yyyy • HH:mm').format(session.timestamp),
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textDim.withAlpha(180)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _fmt(session.durationSec),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${session.rounds} ${L10n.get(context, 'desc_rounds')}',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textDim.withAlpha(180)),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (40 * index).ms, duration: AppMotion.medium)
        .slideY(begin: 0.1);
  }
}
