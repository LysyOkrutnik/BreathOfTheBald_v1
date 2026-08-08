import 'dart:math';
import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/theme.dart';

/// A subtle drifting-particle backdrop used across the app.
///
/// Particle motion is integrated in a ticker callback using real frame
/// delta-time, so movement is frame-rate independent and — crucially — the
/// painter stays a pure function of the current particle positions (no mutation
/// inside `paint`, which can be called for reasons unrelated to animation).
class ParticleBackground extends StatefulWidget {
  const ParticleBackground({super.key, this.particleCount = 24});

  final int particleCount;

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _random = Random();
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.particleCount; i++) {
      _particles.add(Particle(random: _random));
    }

    _controller = AnimationController(
      vsync: this,
      // Period is arbitrary; the controller is used purely as a frame ticker.
      duration: const Duration(seconds: 1),
    )
      ..addListener(_onTick)
      ..repeat();
  }

  void _onTick() {
    final elapsed = _controller.lastElapsedDuration ?? Duration.zero;
    final dt = (elapsed - _lastElapsed).inMicroseconds /
        Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;
    if (dt <= 0) return;
    for (final particle in _particles) {
      particle.advance(dt);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ParticlePainter(particles: _particles, repaint: _controller),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class Particle {
  double x;
  double y;
  double _t = 0;
  final double baseSize;
  final double growth;
  final double speedY;
  final double wobbleAmp;
  final double wobbleFreq;
  final double phase;
  final double opacity;

  Particle({required Random random})
      : x = random.nextDouble(),
        y = random.nextDouble(),
        // Speeds/sizes are expressed in screen-fractions per second — tuned
        // to read as bubbles in sparkling water: quick, growing as they
        // rise (lower pressure), wobbling side to side rather than drifting
        // in a straight line.
        speedY = -(random.nextDouble() * 0.09 + 0.05),
        baseSize = random.nextDouble() * 1.4 + 0.4,
        growth = random.nextDouble() * 3.5 + 1.8,
        wobbleAmp = random.nextDouble() * 0.03 + 0.01,
        wobbleFreq = random.nextDouble() * 3.0 + 1.5,
        phase = random.nextDouble() * 2 * pi,
        opacity = random.nextDouble() * 0.18 + 0.05;

  /// Current radius: bubbles expand as they rise toward the surface (y → 0).
  double get displaySize => baseSize + (1 - y) * growth;

  /// Current x, wobbling side to side around its anchor rather than
  /// drifting in a straight line.
  double displayX(double width) =>
      (x + wobbleAmp * sin(_t * wobbleFreq + phase)) * width;

  /// Advances the particle by [dt] seconds, wrapping the vertical rise
  /// around the unit square (a bubble reaching the top respawns at the
  /// bottom, small again).
  void advance(double dt) {
    _t += dt;
    y = (y + speedY * dt) % 1.0;
    if (y < 0) y += 1.0;
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.particles, required Listenable repaint})
      : super(repaint: repaint);

  final List<Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    // Each mote is a dim halo plus a brighter core (both flat fills, no blur
    // filter) — cheap, but reads as a small bioluminescent glow rather than
    // a flat dust speck.
    final paint = Paint()..style = PaintingStyle.fill;
    for (final particle in particles) {
      final r = particle.displaySize;
      final center = Offset(particle.displayX(size.width), particle.y * size.height);
      paint.color = AppTheme.accent.withAlpha((140 * particle.opacity).round());
      canvas.drawCircle(center, r * 2.2, paint);
      paint.color = AppTheme.glassBorder.withAlpha((255 * particle.opacity).round());
      canvas.drawCircle(center, r, paint);
    }
  }

  // Repaints are driven by the [Listenable] passed to super, so no per-field
  // comparison is needed here.
  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => false;
}
