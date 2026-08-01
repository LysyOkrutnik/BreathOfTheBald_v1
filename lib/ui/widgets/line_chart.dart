import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/theme.dart';

/// A minimal gradient-filled line chart used across stats and session detail.
class LineChartView extends StatelessWidget {
  const LineChartView({
    super.key,
    required this.values,
    this.color = AppTheme.primary,
    this.height = 120,
  });

  final List<double> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _LineChartPainter(values, color),
        size: Size.infinite,
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter(this.values, this.color);
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final range = (maxV - minV).abs() < 1 ? 1.0 : (maxV - minV);

    Offset pt(int i) {
      final x = size.width * i / (values.length - 1);
      final norm = (values[i] - minV) / range;
      final y = size.height - norm * (size.height - 8) - 4;
      return Offset(x, y);
    }

    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(pt(i).dx, pt(i).dy);
    }

    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withAlpha(80), color.withAlpha(0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    final last = pt(values.length - 1);
    canvas.drawCircle(last, 4, Paint()..color = color);
    canvas.drawCircle(last, 7, Paint()..color = color.withAlpha(60));
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.values != values || old.color != color;
}
