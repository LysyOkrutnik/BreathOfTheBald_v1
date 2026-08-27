import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';

/// The app's one modal visual language: a blurred backdrop behind a
/// translucent glass card. Used for every dialog — confirmations, forms,
/// and plain informational messages alike — so nothing suddenly reads as a
/// different, flatter "system dialog" mid-app.
Future<T?> showGlassDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double? maxWidth,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withAlpha(160),
    builder: (dialogContext) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          // Dialogs have no natural width cap of their own — on a tablet
          // this would otherwise stretch to the full inset width.
          constraints: BoxConstraints(
              maxWidth: maxWidth ?? (dialogContext.isTablet ? 420 : double.infinity)),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(16),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: Colors.white.withAlpha(28)),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 40, spreadRadius: 8),
              ],
            ),
            child: builder(dialogContext),
          ),
        ),
      ),
    ),
  );
}

/// A blurred, glass confirmation dialog. Returns `true` when the user confirms,
/// `false` (or null) otherwise.
Future<bool> showGlassConfirm(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required String cancelLabel,
  String? body,
  IconData icon = Icons.logout_rounded,
  Color confirmColor = AppTheme.danger,
}) async {
  final result = await showGlassDialog<bool>(
    context,
    builder: (dialogContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: confirmColor, size: 34),
        const SizedBox(height: AppSpacing.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w300,
            letterSpacing: 2.0,
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child:
                    Text(cancelLabel, style: const TextStyle(color: Colors.white70)),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel, style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return result ?? false;
}
