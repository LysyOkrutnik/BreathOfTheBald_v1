import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/ui/widgets/particle_background.dart';

/// The shared atmospheric backdrop for every screen: a deep-ocean gradient
/// base, a dominant bioluminescent cyan glow, an optional secondary tint for
/// per-section identity, drifting particles, and a vignette.
///
/// Performance note: the glows are painted **once** (static, no per-frame
/// gradient fills) — only the lightweight particles animate. This keeps the
/// backdrop cheap on every screen, which matters a lot on high-res / weaker
/// devices. Pass a [sectionAccent] (e.g. a tab's identity colour) to layer a
/// secondary, quieter tint on top of the app-wide ocean cyan — it should
/// never replace it, or every screen loses its "deep water" identity.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    this.sectionAccent,
    this.intensity = 1.0,
    this.showParticles = true,
  });

  /// A secondary, per-section tint layered *under* the dominant ocean cyan
  /// glow — enough to give a tab its own identity without losing the app's
  /// unifying deep-water look.
  final Color? sectionAccent;

  /// Multiplies the glow opacity (0 = none, 1 = default).
  final double intensity;
  final bool showParticles;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Static glows — painted once (RepaintBoundary + shouldRepaint=false).
            RepaintBoundary(
              child: CustomPaint(
                painter: _GlowPainter(
                  sectionAccent: sectionAccent,
                  intensity: intensity,
                ),
                size: Size.infinite,
              ),
            ),
            if (showParticles) const ParticleBackground(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.1,
                  colors: [Colors.transparent, Color(0x66000000)],
                  stops: [0.55, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({required this.sectionAccent, required this.intensity});

  final Color? sectionAccent;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    // The dominant blob is always the ocean's bioluminescent cyan — this is
    // the app's unifying identity colour, so it never loses to a section
    // tint. The section accent (if any) is a quieter secondary blob, tucked
    // into a corner, that gives a tab its own personality without turning
    // the whole screen that colour.
    final r = size.shortestSide * 0.85;
    _glow(canvas, size, Offset(size.width * 0.22, size.height * 0.16), r,
        AppTheme.accent.withAlpha((125 * intensity).round()));

    if (sectionAccent != null) {
      _glow(canvas, size, Offset(size.width * 0.82, size.height * 0.80),
          r * 0.6, sectionAccent!.withAlpha((55 * intensity).round()));
    }
  }

  void _glow(Canvas canvas, Size size, Offset center, double radius, Color color) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = RadialGradient(
        colors: [color, color.withAlpha(0)],
      ).createShader(rect);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) =>
      old.sectionAccent != sectionAccent || old.intensity != intensity;
}
