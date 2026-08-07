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
    // Derive a darker, less saturated color for the exhale state to create a visual contrast.
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
          // Use TweenAnimationBuilder to smoothly animate the color transition between breathing phases.
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: targetColor),
            // Synchronize the color transition to match the scale animation duration.
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

/// A single radial harmonic: [angularFreq] (must be an integer for a closed
/// loop in θ), [amplitude] as a fraction of radius, [timeFreq] (integer, for a
/// seamless time loop) and a constant [phase].
class _Harmonic {
  const _Harmonic(this.angularFreq, this.amplitude, this.timeFreq, this.phase);
  final int angularFreq;
  final double amplitude;
  final int timeFreq;
  final double phase;
}

/// A luminous, breathing liquid orb.
///
/// Composed of stacked layers that all loop seamlessly: an outer atmospheric
/// glow, two counter-phased metaball bodies blended additively for an organic
/// liquid feel, a bright off-centre core, and a soft glowing rim.
class FerrofluidPainter extends CustomPainter {
  FerrofluidPainter({required this.animationValue, required this.color});

  final double animationValue;
  final Color color;

  // Two bodies with different harmonics drift against each other.
  static const _bodyA = [
    _Harmonic(3, 0.060, 1, 0.0),
    _Harmonic(5, 0.045, -2, 0.0),
    _Harmonic(7, 0.028, 1, 1.0),
  ];
  static const _bodyB = [
    _Harmonic(4, 0.052, -1, 0.6),
    _Harmonic(6, 0.038, 2, 2.1),
    _Harmonic(2, 0.030, 1, 0.3),
  ];

  Path _blobPath(Offset center, double radius, List<_Harmonic> harmonics) {
    const points = 160;
    final path = Path();
    for (var i = 0; i <= points; i++) {
      final a = (i / points) * 2 * math.pi;
      var r = radius;
      for (final h in harmonics) {
        r += radius *
            h.amplitude *
            math.sin(a * h.angularFreq +
                animationValue * 2 * math.pi * h.timeFreq +
                h.phase);
      }
      final x = center.dx + r * math.cos(a);
      final y = center.dy + r * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.40;

    // 1) Outer atmospheric glow — a confident ambient halo that still leaves
    // the core body/rim below (which conveys inhale/exhale state) untouched.
    final glowRect = Rect.fromCircle(center: center, radius: radius * 1.7);
    canvas.drawCircle(
      center,
      radius * 1.7,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [color.withAlpha(75), color.withAlpha(0)],
          stops: const [0.0, 1.0],
        ).createShader(glowRect),
    );

    // 2) Secondary body (additive) for liquid depth. Softness comes from the
    // radial gradient — no MaskFilter.blur (expensive on the Impeller backend).
    final bodyB = _blobPath(center, radius * 0.94, _bodyB);
    canvas.drawPath(
      bodyB,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          radius: 1.1,
          colors: [color.withAlpha(120), color.withAlpha(20)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // 3) Main body with a soft top-left lit gradient.
    final bodyA = _blobPath(center, radius, _bodyA);
    canvas.drawPath(
      bodyA,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 1.3,
          colors: [
            Color.lerp(color, Colors.white, 0.45)!.withAlpha(220),
            color.withAlpha(160),
            color.withAlpha(70),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.2)),
    );

    // 4) Bright inner core.
    final coreCenter = center.translate(-radius * 0.18, -radius * 0.22);
    canvas.drawCircle(
      coreCenter,
      radius * 0.5,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [Colors.white.withAlpha(120), color.withAlpha(0)],
        ).createShader(Rect.fromCircle(center: coreCenter, radius: radius * 0.5)),
    );

    // 5) A specular glint that drifts slowly around the orb (seamless loop).
    final glintAngle = animationValue * 2 * math.pi;
    final glint = center.translate(
      math.cos(glintAngle) * radius * 0.30,
      math.sin(glintAngle) * radius * 0.30 - radius * 0.12,
    );
    canvas.drawCircle(
      glint,
      radius * 0.20,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [Colors.white.withAlpha(110), Colors.white.withAlpha(0)],
        ).createShader(Rect.fromCircle(center: glint, radius: radius * 0.20)),
    );

    // 6) Crisp glowing rim (no blur).
    canvas.drawPath(
      bodyA,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Color.lerp(color, Colors.white, 0.3)!.withAlpha(120),
    );
  }

  @override
  bool shouldRepaint(covariant FerrofluidPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.color != color;
  }
}