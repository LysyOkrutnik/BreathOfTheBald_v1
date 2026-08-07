import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/ui/widgets/particle_background.dart';

/// The shared atmospheric backdrop for every screen: a deep gradient base, two
/// soft glows for depth, drifting particles, and a vignette.
///
/// Performance note: the glows are painted **once** (static, no per-frame
/// gradient fills) — only the lightweight particles animate. This keeps the
/// backdrop cheap on every screen, which matters a lot on high-res / weaker
/// devices. Pass an [accent] (e.g. a level colour) to tint the glow.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    this.accent,
    this.intensity = 1.0,
    this.showParticles = true,
  });

  final Color? accent;

  /// Multiplies the glow opacity (0 = none, 1 = default).
  final double intensity;
  final bool showParticles;

  @override
  Widget build(BuildContext context) {
    final glowA = accent ?? AppTheme.primary;
    const glowB = AppTheme.accent;

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
                  colorA: glowA,
                  colorB: glowB,
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
  _GlowPainter({
    required this.colorA,
    required this.colorB,
    required this.intensity,
  });

  final Color colorA;
  final Color colorB;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    // Smaller, softer blobs than the original — reads as gentle ambient
    // lighting rather than a prominent "aura", matching the app's calmer,
    // more precision-instrument visual direction.
    final r = size.shortestSide * 0.70;
    _glow(canvas, size, Offset(size.width * 0.28, size.height * 0.22), r,
        colorA.withAlpha((40 * intensity).round()));
    _glow(canvas, size, Offset(size.width * 0.78, size.height * 0.74), r * 0.85,
        colorB.withAlpha((30 * intensity).round()));
  }

  void _glow(Canvas canvas, Size size, Offset center, double radius, Color color) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withAlpha(0)],
      ).createShader(rect);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) =>
      old.colorA != colorA ||
      old.colorB != colorB ||
      old.intensity != intensity;
}
