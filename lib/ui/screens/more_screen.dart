import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/ui/screens/history_screen.dart';
import 'package:okrutnik_breath/ui/screens/instruction_screen.dart';
import 'package:okrutnik_breath/ui/screens/settings_screen.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';

/// The "Więcej" bottom-nav tab: guide, history and settings.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          ),
        ],
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
  });

  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

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
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withAlpha(180), size: 22),
          ],
        ),
      ),
    );
  }
}
