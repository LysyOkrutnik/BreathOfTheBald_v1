import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/ui/widgets/level_grid.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';

/// The "Ćwiczenia specjalne" bottom-nav tab: special techniques plus the
/// user's own custom presets. Only ever shown as a shell tab root — the
/// shared background lives in HomeShellScreen so it isn't torn down and
/// rebuilt (with its animation restarting) every time the tab is switched.
class SpecialScreen extends StatelessWidget {
  const SpecialScreen({super.key});

  static const _special = ['box', 'relax', 'fire'];

  @override
  Widget build(BuildContext context) {
    final columns = (context.isTablet || context.isLandscape) ? 2 : 1;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: context.isTablet ? 900 : double.infinity,
          ),
          child: Column(
            children: [
              ScreenHeader(
                title: L10n.get(context, 'menu_section_special'),
                showBackButton: false,
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LevelGrid(keys: _special, columns: columns),
                      const SizedBox(height: AppSpacing.xl),
                      const CustomSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
