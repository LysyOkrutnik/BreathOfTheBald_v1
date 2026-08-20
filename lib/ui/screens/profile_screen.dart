import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/logic/providers/challenges_providers.dart';
import 'package:okrutnik_breath/ui/screens/history_screen.dart';
import 'package:okrutnik_breath/ui/screens/instruction_screen.dart';
import 'package:okrutnik_breath/ui/screens/settings_screen.dart';
import 'package:okrutnik_breath/ui/screens/stats_screen.dart';
import 'package:okrutnik_breath/ui/widgets/confirm_dialog.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';

/// The "Ty" bottom-nav tab — replaces the old "Więcej" grab-bag. Level/XP/
/// streak, session history and the new Wyzwania (Challenges) leaderboard are
/// now three segments of one tab instead of separate destinations reached
/// through a menu; Przewodnik and Ustawienia (the only two items that are
/// genuinely just navigation, not content to browse) stay as plain tiles
/// below. Przewodnik previously had two identical entry points (this menu
/// and a tile inside Settings) — this is now the only one.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _segment = 0;

  static const _sections = [
    StatsContent(),
    HistoryContent(),
    ChallengesContent(),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          ScreenHeader(title: L10n.get(context, 'nav_profile'), showBackButton: false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _SegmentedControl(
              labels: [
                L10n.get(context, 'profile_segment_stats'),
                L10n.get(context, 'profile_segment_history'),
                L10n.get(context, 'profile_segment_challenges'),
              ],
              selected: _segment,
              onChanged: (i) => setState(() => _segment = i),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: IndexedStack(index: _segment, children: _sections),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: _NavTile(
                    icon: Icons.spa_outlined,
                    label: L10n.get(context, 'profile_guide_tile'),
                    onTap: () => Navigator.of(context)
                        .push(fadeThroughRoute(const InstructionScreen())),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _NavTile(
                    icon: Icons.settings_outlined,
                    label: L10n.get(context, 'profile_settings_tile'),
                    onTap: () => Navigator.of(context)
                        .push(fadeThroughRoute(const SettingsScreen())),
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

/// Same visual pattern as [TrainingLibraryScreen]'s segmented control —
/// duplicated rather than shared as a public widget since the two are
/// currently one-off, single-screen uses; worth extracting if a third
/// appears.
class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppTheme.glassBorder.withAlpha(40)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == selected ? AppTheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: i == selected ? Colors.black : AppTheme.textDim,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
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

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.textLight, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textLight, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Wyzwania (Challenges) section — lists active time-boxed community
/// challenges from the backend (server/src/routes/challenges.ts), with a
/// join/leave toggle and a tap-through to a leaderboard dialog. This is a
/// brand-new client feature; the backend endpoints already existed with no
/// client ever calling them.
class ChallengesContent extends ConsumerWidget {
  const ChallengesContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengesAsync = ref.watch(challengesProvider);
    return challengesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (_, __) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            L10n.get(context, 'challenges_error'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textDim, fontSize: 14),
          ),
        ),
      ),
      data: (challenges) {
        if (challenges.isEmpty) {
          return Center(
            child: Text(
              L10n.get(context, 'challenges_empty'),
              style: const TextStyle(color: AppTheme.textDim, fontSize: 14),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          itemCount: challenges.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _ChallengeCard(challenge: challenges[i]),
          ),
        );
      },
    );
  }
}

class _ChallengeCard extends ConsumerStatefulWidget {
  const _ChallengeCard({required this.challenge});
  final Challenge challenge;

  @override
  ConsumerState<_ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends ConsumerState<_ChallengeCard> {
  bool _busy = false;

  Future<void> _toggleJoin() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final actions = ref.read(challengeActionsProvider);
      if (widget.challenge.joined) {
        await actions.leave(widget.challenge.id);
      } else {
        await actions.join(widget.challenge.id);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showLeaderboard() {
    showGlassDialog(
      context,
      builder: (dialogContext) => _LeaderboardView(challenge: widget.challenge),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    return PressableScale(
      onTap: _showLeaderboard,
      child: GlassCard(
        gradient: AppTheme.cardGradient(AppTheme.lure),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.challenge.title, style: AppTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(widget.challenge.description,
                style: const TextStyle(color: AppTheme.textDim, fontSize: 12, height: 1.4)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${L10n.get(context, 'challenges_ends_on')} '
              '${DateFormat('dd.MM.yyyy', locale).format(widget.challenge.endsAt)}',
              style: AppTheme.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: PressableScale(
                onTap: _busy ? null : () => _toggleJoin(),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: widget.challenge.joined ? Colors.transparent : AppTheme.lure,
                    border: widget.challenge.joined
                        ? Border.all(color: AppTheme.lure.withAlpha(160))
                        : null,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    L10n.get(context,
                        widget.challenge.joined ? 'challenges_leave' : 'challenges_join'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.challenge.joined ? AppTheme.lure : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardView extends ConsumerWidget {
  const _LeaderboardView({required this.challenge});
  final Challenge challenge;

  String _formatValue(BuildContext context, int value) {
    switch (challenge.metric) {
      case 'STREAK':
        return '$value ${L10n.get(context, 'challenges_metric_streak_unit')}';
      case 'TOTAL_RETENTION_SEC':
        final minutes = value ~/ 60;
        final seconds = value % 60;
        return '$minutes:${seconds.toString().padLeft(2, '0')}';
      default:
        return '$value ${L10n.get(context, 'challenges_metric_sessions_unit')}';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(leaderboardProvider(challenge.id));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          L10n.get(context, 'challenges_leaderboard_title'),
          style: const TextStyle(
              color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.5),
        ),
        const SizedBox(height: AppSpacing.lg),
        entriesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
          error: (_, __) => Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(L10n.get(context, 'challenges_error'),
                style: const TextStyle(color: AppTheme.textDim)),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(L10n.get(context, 'challenges_leaderboard_empty'),
                    style: const TextStyle(color: AppTheme.textDim)),
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final e = entries[i];
                  return Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text('#${e.rank}',
                            style: const TextStyle(
                                color: AppTheme.lure, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      Expanded(
                        child: Text(e.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.textLight, fontSize: 13)),
                      ),
                      Text(_formatValue(context, e.value),
                          style: const TextStyle(
                              color: AppTheme.textDim,
                              fontSize: 12,
                              fontFeatures: [FontFeature.tabularFigures()])),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
