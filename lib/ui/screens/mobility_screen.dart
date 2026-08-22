import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/ui/widgets/level_grid.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';

/// The "Mobilność" segment of the Trening tab: lung-mobility/diaphragm
/// exercises — chest/intercostal stretch, Uddiyana Bandha, resisted
/// breathing, and the three-part yogic breath (plus a holds-free "gentle"
/// variant of the last one). Packing lives in the Freediving segment
/// instead (it's a freediving-specific technique, already gated behind
/// that section's safety consent).
class MobilityScreen extends StatelessWidget {
  const MobilityScreen({super.key});

  static const _mobility = [
    'stretch_chest',
    'uddiyana_bandha',
    'resisted_breathing',
    'three_part_breath',
    'three_part_breath_gentle',
  ];

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
                title: L10n.get(context, 'menu_section_mobility'),
                showBackButton: false,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  L10n.get(context, 'menu_mobility_subtitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textDim.withAlpha(200),
                    letterSpacing: 1.0,
                  ),
                ),
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
                  child: LevelGrid(keys: _mobility, columns: columns),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
