import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/theme.dart';

class FerrofluidWidget extends StatefulWidget {
  final double size;
  final bool isInhaling;
  final Duration duration;

  const FerrofluidWidget({
    super.key,
    this.size = 300,
    required this.isInhaling,
    required this.duration,
  });

  @override
  State<FerrofluidWidget> createState() => _FerrofluidWidgetState();
}

class _FerrofluidWidgetState extends State<FerrofluidWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color inhaleColor = AppTheme.breathInhale;
    // Derive a darker, less saturated color for the exhale state.
    final Color exhaleColor = Color.lerp(inhaleColor, Colors.black, 0.4)!;

    final Color targetColor = widget.isInhaling ? inhaleColor : exhaleColor;

    return AnimatedScale(
      scale: widget.isInhaling ? 1.0 : 0.6,
      duration: widget.duration ~/ 2,
      curve: Curves.easeInOut,
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          // Animate the color transition smoothly between breathing phases.
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: targetColor),
            // Synchronize the color transition duration with the scale animation.
            duration: widget.duration ~/ 2,
            curve: Curves.easeInOut,
            builder: (context, animatedColor, _) {
              return AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: FerrofluidPainter(
                      animationValue: _waveController.value,
                      color: animatedColor ?? inhaleColor,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class FerrofluidPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  FerrofluidPainter({
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.45;

    final path = Path();
    const int points = 120;

    for (int i = 0; i <= points; i++) {
      final double angle = (i / points) * 2 * math.pi;
      final double offset1 = math.sin(angle * 3 + animationValue * 2 * math.pi) * (radius * 0.06);
      final double offset2 = math.cos(angle * 5 - animationValue * 4 * math.pi) * (radius * 0.05);
      final double offset3 = math.sin(angle * 7 + animationValue * 2 * math.pi) * (radius * 0.03);

      final double currentRadius = radius + offset1 + offset2 + offset3;
      final double x = center.dx + currentRadius * math.cos(angle);
      final double y = center.dy + currentRadius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final rect = Rect.fromCircle(center: center, radius: radius * 1.2);
    final gradient = RadialGradient(
      center: Alignment.topLeft,
      radius: 1.2,
      colors: [
        color.withOpacity(0.9),
        color.withOpacity(0.6),
        color.withOpacity(0.3),
      ],
      stops: const [0.0, 0.6, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    // Simulate a wet, glossy surface with a radial gradient overlay.
    final reflectionPaint = Paint()
      ..shader = RadialGradient(
        // Position the virtual light source at the top-left.
        center: const Alignment(-0.5, -0.5),
        radius: 0.7,
        colors: [
          Colors.white.withOpacity(0.4),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 0.7],
      ).createShader(rect);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Scale the reflection down slightly to prevent edge bleeding outside the base path.
    canvas.scale(0.95, 0.95);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(path, reflectionPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FerrofluidPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.color != color;
  }
}