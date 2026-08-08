import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/ui/widgets/level_grid.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';

/// The "Wim Hof" bottom-nav tab: the classic ladder (Nowicjusz → Okrutnik).
/// Only ever shown as a shell tab root — the shared background lives in
/// HomeShellScreen so it isn't torn down and rebuilt (with its animation
/// restarting) every time the tab is switched.
class WimHofScreen extends StatelessWidget {
  const WimHofScreen({super.key});

  static const _classic = ['mild', 'strong', 'beast', 'guru'];

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
                title: L10n.get(context, 'menu_section_classic'),
                showBackButton: false,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  L10n.get(context, 'menu_select_rhythm'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textDim.withAlpha(200),
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w600,
                  ),
                ).animate().fadeIn(duration: AppMotion.slow),
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
                  child: LevelGrid(keys: _classic, columns: columns),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
