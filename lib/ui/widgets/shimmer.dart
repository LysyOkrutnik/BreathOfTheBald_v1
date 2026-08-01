import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/theme.dart';

/// A lightweight, dependency-free shimmer effect.
///
/// Wrap skeleton placeholders (plain [ShimmerBox]es) in a single [Shimmer] so
/// they share one animation controller and sweep in sync.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
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
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final slide = _controller.value * 2 - 1; // -1 -> 1
            return LinearGradient(
              begin: Alignment(slide - 1, 0),
              end: Alignment(slide + 1, 0),
              colors: const [
                AppTheme.shimmerBase,
                AppTheme.shimmerHighlight,
                AppTheme.shimmerBase,
              ],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

/// A neutral placeholder block. Its color is irrelevant — the enclosing
/// [Shimmer] paints over it with [BlendMode.srcATop].
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 12,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.shimmerBase,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
