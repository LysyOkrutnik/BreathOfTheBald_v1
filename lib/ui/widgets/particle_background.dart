import 'dart:math';
import 'package:flutter/material.dart';

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
  final double speedX;
  final double speedY;
  final double size;
  final double opacity;

  Particle({required Random random})
      : x = random.nextDouble(),
        y = random.nextDouble(),
        // Speeds are expressed in screen-fractions per second.
        speedX = (random.nextDouble() - 0.5) * 0.04,
        speedY = (random.nextDouble() - 0.5) * 0.04,
        size = random.nextDouble() * 2 + 0.5,
        opacity = random.nextDouble() * 0.15 + 0.05;

  /// Advances the particle by [dt] seconds, wrapping around the unit square.
  void advance(double dt) {
    x = (x + speedX * dt) % 1.0;
    if (x < 0) x += 1.0;
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
    final paint = Paint()..style = PaintingStyle.fill;
    for (final particle in particles) {
      paint.color = Colors.white.withAlpha((255 * particle.opacity).round());
      canvas.drawCircle(
        Offset(particle.x * size.width, particle.y * size.height),
        particle.size,
        paint,
      );
    }
  }

  // Repaints are driven by the [Listenable] passed to super, so no per-field
  // comparison is needed here.
  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => false;
}
