import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/theme.dart';

/// A small uppercase label above a group of related content (e.g. "KONTO I
/// SYNCHRONIZACJA") — consolidates what used to be several near-identical
/// private `_SectionHeader` classes copy-pasted per screen, each with
/// slightly different sizing/spacing.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm, bottom: AppSpacing.sm),
      child: Text(text, style: AppTheme.sectionLabel),
    );
  }
}
