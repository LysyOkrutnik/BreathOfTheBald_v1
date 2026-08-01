import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/theme.dart';

/// A gentle fade-through + subtle scale transition for navigation, matching the
/// app's calm motion language. Use instead of [MaterialPageRoute] for a
/// consistent, premium feel (Hero animations still run on top).
Route<T> fadeThroughRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: AppMotion.medium,
    reverseTransitionDuration: AppMotion.fast,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: AppMotion.emphasized);
      return FadeTransition(
        opacity: curved,
        child: Transform.scale(
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved).value,
          child: child,
        ),
      );
    },
  );
}
