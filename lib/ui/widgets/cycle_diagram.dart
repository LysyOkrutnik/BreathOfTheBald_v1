import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/theme.dart';

/// A live diagram of every step in one repeating cycle of an exercise — a
/// single top-to-bottom list of boxes, connected by straight arrows in
/// cycle order, the currently active one highlighted; the last box loops
/// back to the first via a return arrow routed through the left margin.
///
/// Every forward arrow is a straight vertical line by construction (each
/// box sits directly below the previous one) — unlike an earlier 2-column
/// grid layout, there's no diagonal case to handle for odd step counts.
/// All positions are computed analytically from fixed dimensions rather
/// than measured after layout, so the painted arrows always line up with
/// the boxes exactly, in one pass.
class CycleDiagram extends StatelessWidget {
  const CycleDiagram({
    super.key,
    required this.steps,
    required this.activeIndex,
    required this.accentColor,
  });

  final List<CycleStep> steps;
  final int? activeIndex;
  final Color accentColor;

  static const double _boxWidth = 168;
  static const double _boxHeight = 52;
  static const double _vGap = 20;
  // Reserved to the left of every box for the return arrow's vertical run,
  // so it never has to cross through a box on its way back up.
  static const double _returnMargin = 34;

  @override
  Widget build(BuildContext context) {
    final n = steps.length;
    if (n == 0) return const SizedBox.shrink();

    final rects = List<Rect>.generate(
      n,
      (i) => Rect.fromLTWH(_returnMargin, i * (_boxHeight + _vGap), _boxWidth, _boxHeight),
    );
    final totalWidth = _returnMargin + _boxWidth;
    final totalHeight = n * _boxHeight + (n - 1) * _vGap;

    return SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (n > 1)
            Positioned.fill(
              child: CustomPaint(
                painter: _CycleArrowPainter(
                  rects: rects,
                  color: Colors.white.withAlpha(110),
                ),
              ),
            ),
          for (var i = 0; i < n; i++)
            Positioned.fromRect(
              rect: rects[i],
              child: _StepBox(
                step: steps[i],
                active: activeIndex == i,
                accentColor: accentColor,
              ),
            ),
        ],
      ),
    );
  }
}

class _StepBox extends StatelessWidget {
  const _StepBox({required this.step, required this.active, required this.accentColor});
  final CycleStep step;
  final bool active;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final durationLabel = step.countLabel ??
        (step.durationSec != null ? "${step.durationSec}s" : "");
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: active ? accentColor.withAlpha(38) : Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: active ? accentColor : Colors.white.withAlpha(60),
          width: active ? 2 : 1,
        ),
        boxShadow: active
            ? [BoxShadow(color: accentColor.withAlpha(90), blurRadius: 16, spreadRadius: 1)]
            : null,
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                L10n.get(context, step.labelKey),
                textAlign: TextAlign.left,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            if (durationLabel.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                durationLabel,
                style: TextStyle(
                  color: active ? accentColor : Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Draws every forward arrow (step i -> step i+1, always a straight
/// vertical line since each box sits directly under the previous one) plus
/// one return arrow from the last step back to the first, routed through
/// the reserved left margin so it never crosses a box.
class _CycleArrowPainter extends CustomPainter {
  _CycleArrowPainter({required this.rects, required this.color});
  final List<Rect> rects;
  final Color color;

  static const double _arrowSize = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final n = rects.length;

    for (var i = 0; i < n - 1; i++) {
      final start = Offset(rects[i].center.dx, rects[i].bottom);
      final end = Offset(rects[i + 1].center.dx, rects[i + 1].top);
      canvas.drawLine(start, end, paint);
      _drawArrowhead(canvas, paint, start, end);
    }
    _drawReturnArrow(canvas, paint, rects[n - 1], rects[0]);
  }

  void _drawArrowhead(Canvas canvas, Paint paint, Offset from, Offset to) {
    final angle = (to - from).direction;
    final p1 = to - Offset.fromDirection(angle - 0.5, _arrowSize);
    final p2 = to - Offset.fromDirection(angle + 0.5, _arrowSize);
    final fillPaint = Paint()..color = paint.color..style = PaintingStyle.fill;
    canvas.drawPath(
      Path()
        ..moveTo(to.dx, to.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close(),
      fillPaint,
    );
  }

  /// From the last box's left edge, out into the reserved margin, up to the
  /// first box's row, and back in to its left edge — a clean 3-segment
  /// path that never crosses any box in between, regardless of how many
  /// rows sit between them.
  void _drawReturnArrow(Canvas canvas, Paint paint, Rect from, Rect to) {
    final marginX = to.left - 18;
    final start = Offset(from.left, from.center.dy);
    final end = Offset(to.left, to.center.dy);
    final radius = 10.0;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(marginX + radius, start.dy)
      ..quadraticBezierTo(marginX, start.dy, marginX, start.dy - radius)
      ..lineTo(marginX, end.dy + radius)
      ..quadraticBezierTo(marginX, end.dy, marginX + radius, end.dy);
    canvas.drawPath(path, paint);
    _drawArrowhead(canvas, paint, Offset(marginX, end.dy), end);
  }

  @override
  bool shouldRepaint(covariant _CycleArrowPainter old) =>
      old.rects != rects || old.color != color;
}
