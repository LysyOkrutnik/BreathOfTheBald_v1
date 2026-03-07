import 'dart:math';
import 'package:flutter/material.dart';

class ParticleBackground extends StatefulWidget {
  const ParticleBackground({super.key});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 50; i++) {
      _particles.add(Particle(random: _random));
    }

    _controller = AnimationController(
      vsync: this,
      // Provide an arbitrary duration; particle movement relies on continuous ticker updates rather than tweening.
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlePainter(
            particles: _particles,
          ),
          child: Container(),
        );
      },
    );
  }
}

class Particle {
  double x;
  double y;
  double speedX;
  double speedY;
  double size;
  double opacity;

  Particle({required Random random})
      : x = random.nextDouble(),
        y = random.nextDouble(),
        speedX = (random.nextDouble() - 0.5) * 0.002,
        speedY = (random.nextDouble() - 0.5) * 0.002,
        size = random.nextDouble() * 2 + 0.5,
        opacity = random.nextDouble() * 0.15 + 0.05;
}

class _ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  _ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var particle in particles) {
      particle.x += particle.speedX;
      particle.y += particle.speedY;

      // Wrap particles around screen boundaries to maintain a continuous visual flow.
      if (particle.x > 1.0) particle.x = 0.0;
      if (particle.x < 0.0) particle.x = 1.0;
      if (particle.y > 1.0) particle.y = 0.0;
      if (particle.y < 0.0) particle.y = 1.0;

      paint.color = Colors.white.withOpacity(particle.opacity);
      canvas.drawCircle(
        Offset(particle.x * size.width, particle.y * size.height),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}