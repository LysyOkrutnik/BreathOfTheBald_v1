import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/theme.dart';

/// A blurred, glass confirmation dialog. Returns `true` when the user confirms,
/// `false` (or null) otherwise.
Future<bool> showGlassConfirm(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required String cancelLabel,
  IconData icon = Icons.logout_rounded,
  Color confirmColor = AppTheme.danger,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withAlpha(160),
    builder: (dialogContext) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(16),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: Colors.white.withAlpha(28)),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 40, spreadRadius: 8),
            ],
          ),
          child: Column(
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
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(cancelLabel,
                          style: const TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(confirmLabel,
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}
