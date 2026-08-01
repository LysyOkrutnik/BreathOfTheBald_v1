import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/theme.dart';

/// A frosted-glass surface. Blur is opt-in because [BackdropFilter] is costly —
/// use it for hero surfaces and dialogs, but leave it off inside long lists.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.lg,
    this.tint,
    this.gradient,
    this.blur = false,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final Gradient? gradient;
  final bool blur;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: gradient == null ? (tint ?? Colors.white).withAlpha(14) : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: border
          ? Border.all(color: Colors.white.withAlpha(28))
          : null,
    );

    final content = Container(
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (!blur) return content;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: content,
      ),
    );
  }
}

/// Wraps a tappable child with a quick spring-scale on press for tactile
/// feedback. Honours [onTap]; pass null to disable interaction.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: widget.onTap == null ? null : (_) => _set(false),
      onTapCancel: widget.onTap == null ? null : () => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.emphasized,
        child: widget.child,
      ),
    );
  }
}
