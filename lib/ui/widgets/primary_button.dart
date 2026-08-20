import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';

/// The app's one filled call-to-action button style — consolidates what used
/// to be several near-identical private `_ActionButton` classes copy-pasted
/// per screen (session flows, the PB test, the scheduler's save button).
///
/// A null [onTap] renders the button dimmed and inert (matching the
/// scheduler's "pick an exercise first" disabled state) rather than requiring
/// callers to wrap it in their own `Opacity`.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = AppTheme.primary,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return PressableScale(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: enabled ? AppTheme.glow(color, blur: 22) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
