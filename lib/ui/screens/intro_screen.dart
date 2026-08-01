import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/logic/notifiers/session_notifier.dart';
import 'package:okrutnik_breath/ui/screens/session_screen.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/glow_halo.dart';

class IntroScreen extends ConsumerWidget {
  const IntroScreen({super.key, required this.level});

  final LevelData level;

  void _start(BuildContext context, WidgetRef ref) {
    ref.read(sessionProvider.notifier).startSession(level);
    Navigator.of(context).pushReplacement(
      fadeThroughRoute(const SessionScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final twoPane = context.isTablet || context.isLandscape;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: AppBackground(accent: level.color)),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.isTablet ? 980 : 560),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white54),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: twoPane ? _twoPane(context, ref) : _singleColumn(context, ref),
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

  Widget _singleColumn(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: [
              _Intro(level: level),
              const SizedBox(height: AppSpacing.xl),
              _Steps(level: level),
              if (level.type == ExerciseType.fireBreathing) ...[
                const SizedBox(height: AppSpacing.lg),
                _FireWarning(),
              ],
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
        _StartButton(level: level, onTap: () => _start(context, ref)),
      ],
    );
  }

  Widget _twoPane(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Intro(level: level),
                        const SizedBox(height: AppSpacing.xl),
                        _StartButton(level: level, onTap: () => _start(context, ref)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
            children: [
              _Steps(level: level),
              if (level.type == ExerciseType.fireBreathing) ...[
                const SizedBox(height: AppSpacing.lg),
                _FireWarning(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.level});
  final LevelData level;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GlowHalo(
          color: level.color,
          diameter: 104,
          haloScale: 1.9,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: level.color.withAlpha(24),
              border: Border.all(color: level.color.withAlpha(90)),
            ),
            child: Center(
              child: Icon(Icons.self_improvement, size: 52, color: level.color),
            ),
          ),
        )
            .animate()
            .scale(duration: AppMotion.slow, curve: Curves.easeOutBack)
            .fadeIn(),
        const SizedBox(height: AppSpacing.lg),
        Text(
          L10n.get(context, level.instructionTitleKey).toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: context.responsive(compact: 26, expanded: 32),
            fontWeight: FontWeight.bold,
            color: AppTheme.textLight,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          L10n.get(context, level.instructionDescriptionKey),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: AppTheme.textDim, height: 1.5),
        ),
      ],
    ).animate().fadeIn(duration: AppMotion.medium).slideY(begin: 0.1);
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.level});
  final LevelData level;

  @override
  Widget build(BuildContext context) {
    final steps = level.instructionStepKeys;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: GlassCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              radius: AppRadius.md,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline,
                      color: level.color.withAlpha(200), size: 20),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      L10n.get(context, steps[i]),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(delay: (80 * i).ms, duration: AppMotion.medium)
              .slideX(begin: 0.1),
      ],
    );
  }
}

class _FireWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.danger.withAlpha(38),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppTheme.danger.withAlpha(120)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFFF8A80), size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              L10n.get(context, 'warning_fire_breath'),
              style: const TextStyle(
                  color: Color(0xFFFF8A80), fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.level, required this.onTap});
  final LevelData level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            color: level.color,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppTheme.glow(level.color, blur: 16),
          ),
          child: Text(
            L10n.get(context, 'start_session_button'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 250.ms, duration: AppMotion.medium).slideY(begin: 0.3);
  }
}
