import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/logic/notifiers/session_notifier.dart';
import 'package:okrutnik_breath/ui/screens/session_screen.dart';
import 'package:okrutnik_breath/ui/widgets/particle_background.dart';

class IntroScreen extends ConsumerWidget {
  final LevelData level;

  const IntroScreen({super.key, required this.level});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Hero(
        tag: 'level_card_${level.key}',
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              const Positioned.fill(child: ParticleBackground()),
              Positioned.fill(
                child: Container(color: Colors.black.withAlpha(179)),
              ),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(Icons.self_improvement, size: 60, color: level.color),
                            const SizedBox(height: 20),
                            Text(
                              L10n.get(context, level.instructionTitleKey).toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textLight,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              L10n.get(context, level.instructionDescriptionKey),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textDim,
                                height: 1.5,
                              ),
                            ),

                            const SizedBox(height: 40),

                            ...level.instructionStepKeys.map((key) => Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.check_circle_outline, color: level.color.withAlpha(179), size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      L10n.get(context, key),
                                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            )),

                            if (level.type == ExerciseType.fireBreathing)
                              Container(
                                margin: const EdgeInsets.only(top: 20),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.danger.withAlpha(51),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.danger.withAlpha(128)),
                                ),
                                child: Text(
                                  L10n.get(context, 'warning_fire_breath'),
                                  style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: ElevatedButton(
                        onPressed: () {
                          ref.read(sessionProvider.notifier).startSession(level);
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const SessionScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: level.color,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 10,
                          shadowColor: level.color.withAlpha(128),
                        ),
                        child: Text(
                          L10n.get(context, 'start_session_button'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}