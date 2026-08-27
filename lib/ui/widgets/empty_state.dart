import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/theme.dart';

/// The app's one "nothing here yet" treatment: a dim icon over a short
/// message, fading in — used wherever a whole screen/section has nothing
/// else to show (as opposed to a compact inline caption next to content
/// that's still rendering, e.g. Scheduler's day timeline, which keeps its
/// own plain-text caption). Extracted from history_screen.dart's original
/// `_EmptyState`, which stats_screen.dart later copied independently.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.messageKey,
    this.iconSize = 64,
  });

  final IconData icon;
  final String messageKey;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: AppTheme.textDim.withAlpha(120)),
          const SizedBox(height: AppSpacing.md),
          Text(
            L10n.get(context, messageKey),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textDim, fontSize: 16),
          ),
        ],
      ).animate().fadeIn(duration: AppMotion.slow),
    );
  }
}
