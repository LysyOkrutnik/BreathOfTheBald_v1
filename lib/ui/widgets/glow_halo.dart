import 'package:flutter/material.dart';

/// A circular element with a soft glow painted *inside* its own bounds.
///
/// Using a [RadialGradient] halo instead of a [BoxShadow] blur matters for two
/// reasons: a box-shadow spills outside the widget's layout box and gets
/// clipped to a hard rectangle whenever an ancestor introduces a layer (e.g.
/// opacity/scale animations or a scroll viewport), and blurs are comparatively
/// expensive to rasterise. The halo here is plain painted content, so it can
/// never be clipped and costs nothing extra.
class GlowHalo extends StatelessWidget {
  const GlowHalo({
    super.key,
    required this.child,
    required this.color,
    this.diameter,
    this.haloScale = 2.0,
    this.intensity = 90,
  });

  final Widget child;
  final Color color;

  /// Diameter of the inner circle. When null the child sizes itself.
  final double? diameter;

  /// Halo size relative to the inner circle.
  final double haloScale;

  /// Peak alpha of the halo (0-255).
  final int intensity;

  @override
  Widget build(BuildContext context) {
    final inner = diameter == null
        ? child
        : SizedBox(width: diameter, height: diameter, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withAlpha(intensity),
            color.withAlpha((intensity * 0.35).round()),
            color.withAlpha(0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Padding(
        // The transparent ring around the child is where the halo fades out.
        padding: EdgeInsets.all(
          diameter != null ? diameter! * (haloScale - 1) / 2 : 24,
        ),
        child: inner,
      ),
    );
  }
}
