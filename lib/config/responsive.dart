import 'package:flutter/widgets.dart';

/// Material 3 window size classes, derived from the shortest side so a device's
/// "type" stays stable across rotation (a tablet is a tablet in any orientation).
enum ScreenSize { compact, medium, expanded }

extension ResponsiveContext on BuildContext {
  Size get _screen => MediaQuery.sizeOf(this);

  double get screenWidth => _screen.width;
  double get screenHeight => _screen.height;
  double get shortestSide => _screen.shortestSide;

  Orientation get orientation => MediaQuery.orientationOf(this);
  bool get isLandscape => orientation == Orientation.landscape;
  bool get isPortrait => orientation == Orientation.portrait;

  /// A tablet (or larger) form factor, independent of orientation.
  bool get isTablet => shortestSide >= 600;

  ScreenSize get screenSize {
    final s = shortestSide;
    if (s >= 840) return ScreenSize.expanded;
    if (s >= 600) return ScreenSize.medium;
    return ScreenSize.compact;
  }

  /// Pick a value per size class, falling back down the chain.
  T responsive<T>({required T compact, T? medium, T? expanded}) {
    switch (screenSize) {
      case ScreenSize.expanded:
        return expanded ?? medium ?? compact;
      case ScreenSize.medium:
        return medium ?? compact;
      case ScreenSize.compact:
        return compact;
    }
  }

  /// Caps content width on large screens so reading lines and cards never
  /// stretch awkwardly across a tablet.
  double get contentMaxWidth => responsive<double>(
        compact: double.infinity,
        medium: 560,
        expanded: 720,
      );
}
