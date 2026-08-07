import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:okrutnik_breath/config/theme.dart';

/// A consistent top bar: a glass back button, a centred title, and optional
/// trailing action — used across the app's secondary screens.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.showBackButton = true,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  /// Set to false when this screen is a bottom-nav tab root rather than a
  /// pushed route — there's nothing to go back to, so no arrow is shown.
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(
        children: [
          if (showBackButton)
            _GlassIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
            )
          else
            const SizedBox(width: 44),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textLight,
                fontWeight: FontWeight.w300,
                fontSize: 18,
                letterSpacing: 2.5,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: trailing != null
                ? Align(alignment: Alignment.centerRight, child: trailing)
                : null,
          ),
        ],
      ),
    ).animate().fadeIn(duration: AppMotion.medium);
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white70, size: 22),
        ),
      ),
    );
  }
}
