import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/theme.dart';

/// The app's one "already completed" treatment for a list row: a dimmed
/// opacity over the whole row, a strikethrough on its label, and a trailing
/// checkmark in place of whatever "act on this" icon would otherwise sit
/// there. `_PlanTile` (Scheduler) and `_TodayActionRow` (Dziś) each grew
/// their own copy of these three cues independently — this is the one
/// place that combination lives now.
abstract final class DoneMarker {
  static const double dimOpacity = 0.6;

  static const Widget icon =
      Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20);

  static TextDecoration? decoration(bool done) =>
      done ? TextDecoration.lineThrough : null;
}
