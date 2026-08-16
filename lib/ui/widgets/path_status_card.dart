import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/logic/path/training_path.dart';
import 'package:okrutnik_breath/logic/path/weekly_plan.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/ui/screens/training_path_screen.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';

/// Compact "Twoja Ścieżka" status card — shown on both the Wim Hof and
/// Freediving tabs (same provider) so the guided path is visible wherever
/// the user is. Tapping it opens the full stage-by-stage view.
class PathStatusCard extends ConsumerWidget {
  const PathStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(trainingPathProvider);
    final plan = ref.watch(weeklyPlanProvider);
    // Still loading (or a data hiccup) — stay visible with a loading state
    // rather than disappearing outright, so the flagship guided feature is
    // never silently invisible for a whole session.
    if (path == null || plan == null) {
      return GestureDetector(
        onTap: () => Navigator.of(context)
            .push(fadeThroughRoute(const TrainingPathScreen())),
        child: GlassCard(
          child: Row(
            children: [
              const Icon(Icons.route_rounded, color: AppTheme.accent, size: 24),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  L10n.get(context, 'path_title'),
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
              ),
            ],
          ),
        ),
      );
    }

    final languageCode = Localizations.localeOf(context).languageCode;
    final todayLabel =
        todaySummaryLabelForLocale(languageCode, plan.days.first.actions);

    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(fadeThroughRoute(const TrainingPathScreen())),
      child: GlassCard(
        gradient: AppTheme.cardGradient(AppTheme.accent),
        child: Row(
          children: [
            const Icon(Icons.route_rounded, color: AppTheme.accent, size: 24),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${L10n.get(context, 'path_title')} • ${L10n.get(context, stageTitleKey(path.stage))}',
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    todayLabel,
                    style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                  ),
                  if (progressLabel(context, path) != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      progressLabel(context, path)!,
                      style: TextStyle(color: AppTheme.textDim.withAlpha(190), fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.accent, size: 22),
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppMotion.medium);
  }
}

/// Widget-layer convenience wrapper for [progressLabelForLocale].
String? progressLabel(BuildContext context, PathState path) =>
    progressLabelForLocale(Localizations.localeOf(context).languageCode, path);
