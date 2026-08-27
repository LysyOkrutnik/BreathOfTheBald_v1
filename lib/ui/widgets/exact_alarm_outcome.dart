import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/core/notifications/notification_service.dart';

/// Shows the outcome snackbar right after one or more `scheduleOneTime`
/// calls — either the plain success message, or (when exact-alarm
/// scheduling isn't currently allowed) a warning that the reminder(s) may
/// fire imprecisely, with a CTA straight to the system permission prompt.
/// Copy-pasted at every place that just finished scheduling reminders (the
/// Scheduler's single add-flow, the Max PB Test's "schedule next test",
/// Twoja Ścieżka's bulk week-scheduling) before this, with one copy
/// silently missing the CTA button the other two had.
///
/// [onAllowPressed] runs in addition to requesting the permission — e.g.
/// the Scheduler's own persistent alarm-permission card needs to re-check
/// its visibility afterward, which is specific to that screen.
Future<void> showSchedulingOutcomeSnackBar(
  BuildContext context, {
  required NotificationService notifications,
  required String successMessageKey,
  VoidCallback? onAllowPressed,
}) async {
  final canScheduleExact = await notifications.canScheduleExactAlarms();
  if (!context.mounted) return;
  if (canScheduleExact) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(L10n.get(context, successMessageKey))));
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(L10n.get(context, 'planner_saved_needs_permission')),
    action: SnackBarAction(
      label: L10n.get(context, 'planner_exact_alarm_allow'),
      onPressed: () {
        notifications.requestExactAlarmsPermission();
        onAllowPressed?.call();
      },
    ),
  ));
}
