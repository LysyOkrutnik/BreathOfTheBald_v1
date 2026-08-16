import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/logic/path/training_path.dart';
import 'package:okrutnik_breath/logic/path/weekly_plan.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/ui/screens/history_screen.dart';
import 'package:okrutnik_breath/ui/screens/instruction_screen.dart';
import 'package:okrutnik_breath/ui/screens/settings_screen.dart';
import 'package:okrutnik_breath/ui/screens/stats_screen.dart';
import 'package:okrutnik_breath/ui/screens/training_path_screen.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';

/// The "Więcej" bottom-nav tab: stats, guide, history and settings. Only
/// ever shown as a shell tab root — the shared background lives in
/// HomeShellScreen so it isn't torn down and rebuilt (with its animation
/// restarting) every time the tab is switched.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(trainingPathProvider);
    final plan = ref.watch(weeklyPlanProvider);
    final languageCode = Localizations.localeOf(context).languageCode;
    final pathSubtitle = (path == null || plan == null)
        ? null
        : '${L10n.get(context, stageTitleKey(path.stage))} • '
            '${todaySummaryLabelForLocale(languageCode, plan.days.first.actions)}';

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.isTablet ? 640 : 560),
          child: Column(
            children: [
              ScreenHeader(
                title: L10n.get(context, 'more_title'),
                showBackButton: false,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  children: [
                    _MoreTile(
                      icon: Icons.route_rounded,
                      color: AppTheme.accent,
                      title: L10n.get(context, 'path_title'),
                      subtitle: pathSubtitle,
                      onTap: () => Navigator.of(context)
                          .push(fadeThroughRoute(const TrainingPathScreen())),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MoreTile(
                      icon: Icons.insights_outlined,
                      color: AppTheme.lure,
                      title: L10n.get(context, 'menu_stats_button'),
                      onTap: () => Navigator.of(context)
                          .push(fadeThroughRoute(const StatsScreen())),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MoreTile(
                      icon: Icons.spa_outlined,
                      color: AppTheme.primary,
                      title: L10n.get(context, 'menu_guide_button'),
                      onTap: () => Navigator.of(context)
                          .push(fadeThroughRoute(const InstructionScreen())),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MoreTile(
                      icon: Icons.history_rounded,
                      color: AppTheme.accent,
                      title: L10n.get(context, 'menu_history_button'),
                      onTap: () => Navigator.of(context)
                          .push(fadeThroughRoute(const HistoryScreen())),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MoreTile(
                      icon: Icons.settings_outlined,
                      color: AppTheme.textDim,
                      title: L10n.get(context, 'menu_settings_button'),
                      onTap: () => Navigator.of(context)
                          .push(fadeThroughRoute(const SettingsScreen())),
                    ),
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

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  /// Set only for Twoja Ścieżka — a live status line (stage • today's
  /// actions), so this entry reads as a dashboard shortcut rather than a
  /// static menu item identical to Stats/Guide/History/Settings.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: GlassCard(
        gradient: AppTheme.cardGradient(color),
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.lg, horizontal: AppSpacing.lg),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha(30),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textLight,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: color.withAlpha(200), fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withAlpha(180), size: 22),
          ],
        ),
      ),
    );
  }
}
