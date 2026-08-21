import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/theme.dart';

/// A live diagram of every step in one repeating cycle of an exercise —
/// boxes connected by arrows in cycle order, the currently active one
/// highlighted, the last one looping back to the first. Modelled on the
/// classic "box breathing" diagrams other breathwork apps show (a 2x2 grid
/// with arrows going right/down/left/up), generalized here to any step
/// count via a 2-column "snake" grid instead of a fixed 2x2 — three_part
/// breath alone needs 8 nodes.
///
/// All box positions are computed analytically from fixed dimensions rather
/// than measured after layout, so the connecting arrows (painted in the same
/// coordinate space) always line up with the boxes exactly, in one pass.
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

  static const double _boxWidth = 132;
  static const double _boxHeight = 60;
  static const double _hGap = 40;
  static const double _vGap = 28;
  // Reserved at the left for the wrap-around arrow's vertical run, so it
  // never has to cross through a box.
  static const double _wrapMargin = 30;

  @override
  Widget build(BuildContext context) {
    final n = steps.length;
    if (n == 0) return const SizedBox.shrink();
    if (n == 1) {
      return Center(child: _StepBox(step: steps[0], active: activeIndex == 0, accentColor: accentColor));
    }

    final rows = (n / 2).ceil();
    // rects[i] = the box rect for sequential step i, placed by the snake
    // (left-to-right on even rows, right-to-left on odd rows) — see the
    // module doc for why a lone last item continues from whichever column
    // the previous row ended on, instead of always the left column.
    final rects = List<Rect>.filled(n, Rect.zero);
    var idx = 0;
    var lastCol = 1; // row -1 is treated as if it "ended" on the right,
    // so the very first row starts on the left, matching every reference
    // box-breathing diagram (inhale always top-left).
    for (var r = 0; r < rows; r++) {
      final remaining = n - idx;
      final rowIsLoneItem = remaining == 1;
      final leftToRight = lastCol == 1;
      final cols = rowIsLoneItem ? [leftToRight ? 0 : 1] : (leftToRight ? [0, 1] : [1, 0]);
      for (final c in cols) {
        rects[idx] = Rect.fromLTWH(
          _wrapMargin + c * (_boxWidth + _hGap),
          r * (_boxHeight + _vGap),
          _boxWidth,
          _boxHeight,
        );
        idx++;
      }
      lastCol = cols.last;
    }

    final totalWidth = _wrapMargin + _boxWidth * 2 + _hGap;
    final totalHeight = rows * _boxHeight + (rows - 1) * _vGap;

    return SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _CycleArrowPainter(
                rects: rects,
                color: Colors.white.withAlpha(90),
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
      decoration: BoxDecoration(
        color: active ? accentColor.withAlpha(46) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: active ? accentColor : Colors.white.withAlpha(70),
          width: active ? 2 : 1,
        ),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              L10n.get(context, step.labelKey),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            if (durationLabel.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                durationLabel,
                style: TextStyle(
                  color: active ? accentColor : Colors.white38,
                  fontSize: 11,
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

/// Draws every forward arrow (step i -> step i+1, edge to edge between the
/// boxes' actual rects) plus one wrap arrow from the last step back to the
/// first, routed around the outside through the reserved left margin so it
/// never crosses a box — this handles any box arrangement, not just the
/// aligned case a fixed 2x2 grid gets for free.
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
      _drawStraightArrow(canvas, paint, rects[i], rects[i + 1]);
    }
    _drawWrapArrow(canvas, paint, rects[n - 1], rects[0]);
  }

  void _drawStraightArrow(Canvas canvas, Paint paint, Rect from, Rect to) {
    final start = _edgePoint(from, to);
    final end = _edgePoint(to, from);
    canvas.drawLine(start, end, paint);
    _drawArrowhead(canvas, paint, start, end);
  }

  /// The point on [rect]'s border closest to [other]'s center — lets a
  /// straight line start/end right at a box's edge instead of its center
  /// (which would visually cut through the box).
  Offset _edgePoint(Rect rect, Rect other) {
    final dx = other.center.dx - rect.center.dx;
    final dy = other.center.dy - rect.center.dy;
    if (dx.abs() > dy.abs()) {
      return Offset(dx > 0 ? rect.right : rect.left, rect.center.dy);
    } else {
      return Offset(rect.center.dx, dy > 0 ? rect.bottom : rect.top);
    }
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

  /// Routes through the left margin reserved outside every box's leftmost
  /// edge, regardless of which column [from]/[to] actually sit in — a
  /// simple 3-segment path (left, vertical, right) that never crosses a box
  /// in between, unlike a straight line would for most box arrangements.
  void _drawWrapArrow(Canvas canvas, Paint paint, Rect from, Rect to) {
    final marginX = (rects.map((r) => r.left).reduce((a, b) => a < b ? a : b)) - 16;
    final start = Offset(from.left, from.center.dy);
    final end = Offset(to.left, to.center.dy);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(marginX, start.dy)
      ..lineTo(marginX, end.dy)
      ..lineTo(end.dx, end.dy);
    canvas.drawPath(path, paint);
    _drawArrowhead(canvas, paint, Offset(marginX, end.dy), end);
  }

  @override
  bool shouldRepaint(covariant _CycleArrowPainter old) =>
      old.rects != rects || old.color != color;
}
