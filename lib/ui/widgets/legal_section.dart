import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/theme.dart';

/// One heading+body block in a long-form legal document screen — shared by
/// PrivacyScreen and TermsScreen so both stay visually identical.
class LegalSection extends StatelessWidget {
  const LegalSection({super.key, required this.heading, required this.body});
  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          body,
          style: const TextStyle(
              color: AppTheme.textDim, fontSize: 14, height: 1.55),
        ),
      ],
    );
  }
}
