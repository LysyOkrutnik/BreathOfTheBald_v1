import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';

class InstructionScreen extends StatelessWidget {
  const InstructionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.isTablet ? 760 : double.infinity),
                child: Column(
                  children: [
                    ScreenHeader(title: L10n.get(context, 'guide_title')),
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                        children: [
                      Text(
                        L10n.get(context, 'guide_select_topic'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white30, fontSize: 12),
                      ),
                      const SizedBox(height: 20),

                      _buildTechniqueCard(
                        context: context,
                        titleKey: "guide_app_usage_title",
                        subtitleKey: "guide_app_usage_subtitle",
                        color: Colors.white,
                        icon: Icons.touch_app,
                        descriptionKey: "guide_app_usage_desc",
                        benefitKeys: [
                          "guide_app_usage_benefit1",
                          "guide_app_usage_benefit2",
                          "guide_app_usage_benefit3"
                        ],
                        warningKeys: [],
                        stepKeys: [
                          "guide_app_usage_step1",
                          "guide_app_usage_step2",
                          "guide_app_usage_step3",
                          "guide_app_usage_step4"
                        ],
                      ),

                      const SizedBox(height: 20),

                      _buildTechniqueCard(
                        context: context,
                        titleKey: "guide_classic_method_title",
                        subtitleKey: "guide_classic_method_subtitle",
                        color: const Color(0xFF4DB6AC),
                        icon: Icons.waves,
                        descriptionKey: "guide_classic_method_desc",
                        benefitKeys: [
                          "guide_classic_method_benefit1",
                          "guide_classic_method_benefit2",
                          "guide_classic_method_benefit3",
                          "guide_classic_method_benefit4"
                        ],
                        warningKeys: [
                          "guide_classic_method_warning1",
                          "guide_classic_method_warning2",
                          "guide_classic_method_warning3",
                          "guide_classic_method_warning4"
                        ],
                        stepKeys: [
                          "guide_classic_method_step1",
                          "guide_classic_method_step2",
                          "guide_classic_method_step3",
                          "guide_classic_method_step4"
                        ],
                      ),

                      const SizedBox(height: 20),

                      _buildTechniqueCard(
                        context: context,
                        titleKey: "guide_box_breathing_title",
                        subtitleKey: "guide_box_breathing_subtitle",
                        color: const Color(0xFF5C6BC0),
                        icon: Icons.crop_square,
                        descriptionKey: "guide_box_breathing_desc",
                        benefitKeys: [
                          "guide_box_breathing_benefit1",
                          "guide_box_breathing_benefit2",
                          "guide_box_breathing_benefit3",
                          "guide_box_breathing_benefit4"
                        ],
                        warningKeys: ["guide_box_breathing_warning1", "guide_box_breathing_warning2"],
                        stepKeys: [
                          "guide_box_breathing_step1",
                          "guide_box_breathing_step2",
                          "guide_box_breathing_step3",
                          "guide_box_breathing_step4"
                        ],
                      ),

                      const SizedBox(height: 20),

                      _buildTechniqueCard(
                        context: context,
                        titleKey: "guide_478_title",
                        subtitleKey: "guide_478_subtitle",
                        color: const Color(0xFFBA68C8),
                        icon: Icons.nights_stay,
                        descriptionKey: "guide_478_desc",
                        benefitKeys: [
                          "guide_478_benefit1",
                          "guide_478_benefit2",
                          "guide_478_benefit3",
                          "guide_478_benefit4"
                        ],
                        warningKeys: ["guide_478_warning1", "guide_478_warning2"],
                        stepKeys: [
                          "guide_478_step1",
                          "guide_478_step2",
                          "guide_478_step3"
                        ],
                      ),

                      const SizedBox(height: 20),

                      _buildTechniqueCard(
                        context: context,
                        titleKey: "guide_fire_breath_title",
                        subtitleKey: "guide_fire_breath_subtitle",
                        color: AppTheme.danger,
                        icon: Icons.local_fire_department,
                        descriptionKey: "guide_fire_breath_desc",
                        benefitKeys: [
                          "guide_fire_breath_benefit1",
                          "guide_fire_breath_benefit2",
                          "guide_fire_breath_benefit3",
                          "guide_fire_breath_benefit4"
                        ],
                        warningKeys: [
                          "guide_fire_breath_warning1",
                          "guide_fire_breath_warning2",
                          "guide_fire_breath_warning3",
                          "guide_fire_breath_warning4"
                        ],
                        stepKeys: [
                          "guide_fire_breath_step1",
                          "guide_fire_breath_step2",
                          "guide_fire_breath_step3",
                          "guide_fire_breath_step4"
                        ],
                      ),

                      const SizedBox(height: 20),

                      _buildTechniqueCard(
                        context: context,
                        titleKey: "guide_freediving_title",
                        subtitleKey: "guide_freediving_subtitle",
                        color: const Color(0xFF4FC3F7),
                        icon: Icons.co2_rounded,
                        descriptionKey: "guide_freediving_desc",
                        benefitKeys: [
                          "guide_freediving_benefit1",
                          "guide_freediving_benefit2",
                          "guide_freediving_benefit3"
                        ],
                        warningKeys: [
                          "guide_freediving_warning1",
                          "guide_freediving_warning2",
                          "guide_freediving_warning3",
                          "guide_freediving_warning4"
                        ],
                        stepKeys: [
                          "guide_freediving_step1",
                          "guide_freediving_step2",
                          "guide_freediving_step3",
                          "guide_freediving_step4"
                        ],
                      ),

                      const SizedBox(height: 20),

                      _buildTechniqueCard(
                        context: context,
                        titleKey: "guide_path_title",
                        subtitleKey: "guide_path_subtitle",
                        color: AppTheme.accent,
                        icon: Icons.route_rounded,
                        descriptionKey: "guide_path_desc",
                        benefitKeys: [
                          "guide_path_benefit1",
                          "guide_path_benefit2",
                        ],
                        warningKeys: const [],
                        stepKeys: [
                          "guide_path_step1",
                          "guide_path_step2",
                          "guide_path_step3",
                        ],
                      ),

                      const SizedBox(height: 20),

                      _buildTechniqueCard(
                        context: context,
                        titleKey: "guide_coldshower_title",
                        subtitleKey: "guide_coldshower_subtitle",
                        color: const Color(0xFF80D8FF),
                        icon: Icons.ac_unit_rounded,
                        descriptionKey: "guide_coldshower_desc",
                        benefitKeys: [
                          "guide_coldshower_benefit1",
                          "guide_coldshower_benefit2",
                          "guide_coldshower_benefit3",
                        ],
                        warningKeys: [
                          "guide_coldshower_warning1",
                          "guide_coldshower_warning2",
                        ],
                        stepKeys: [
                          "guide_coldshower_step1",
                          "guide_coldshower_step2",
                          "guide_coldshower_step3",
                        ],
                      ),

                      const SizedBox(height: 20),

                      _buildTechniqueCard(
                        context: context,
                        titleKey: "guide_rules_title",
                        subtitleKey: "guide_rules_subtitle",
                        color: Colors.grey,
                        icon: Icons.lightbulb,
                        descriptionKey: "guide_rules_desc",
                        benefitKeys: [
                          "guide_rules_benefit1",
                          "guide_rules_benefit2"
                        ],
                        warningKeys: [],
                        stepKeys: [
                          "guide_rules_step1",
                          "guide_rules_step2",
                          "guide_rules_step3",
                          "guide_rules_step4"
                        ],
                      ),

                      const SizedBox(height: 40),

                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white12),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.black26,
                        ),
                        child: Text(
                          L10n.get(context, 'guide_disclaimer'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white30, fontSize: 11, fontStyle: FontStyle.italic, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechniqueCard({
    required BuildContext context,
    required String titleKey,
    required String subtitleKey,
    required Color color,
    required IconData icon,
    required String descriptionKey,
    required List<String> benefitKeys,
    required List<String> warningKeys,
    required List<String> stepKeys,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedIconColor: color,
          iconColor: color,
          tilePadding: const EdgeInsets.all(16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(38),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          title: Text(
            L10n.get(context, titleKey),
            style: const TextStyle(
              color: AppTheme.textLight,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          subtitle: Text(
            L10n.get(context, subtitleKey),
            style: TextStyle(color: color.withAlpha(204), fontSize: 12),
          ),
          children: [
            Text(L10n.get(context, descriptionKey), style: const TextStyle(color: Colors.white70, height: 1.5, fontSize: 14)),
            const SizedBox(height: 15),

            if (benefitKeys.isNotEmpty) ...[
              _buildSectionHeader(L10n.get(context, 'guide_section_benefits'), Colors.greenAccent),
              ...benefitKeys.map((key) => _buildBullet(context, key)),
              const SizedBox(height: 15),
            ],

            if (warningKeys.isNotEmpty) ...[
              _buildSectionHeader(L10n.get(context, 'guide_section_warnings'), Colors.redAccent),
              ...warningKeys.map((key) => _buildBullet(context, key, isWarning: true)),
              const SizedBox(height: 15),
            ],

            _buildSectionHeader(L10n.get(context, 'guide_section_instructions'), Colors.blueAccent),
            ...stepKeys.map((key) => _buildBullet(context, key, isStep: true)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Row(
        children: [
          Container(width: 3, height: 14, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.0)),
        ],
      ),
    );
  }

  Widget _buildBullet(BuildContext context, String textKey, {bool isWarning = false, bool isStep = false}) {
    final text = L10n.get(context, textKey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("• ", style: TextStyle(color: isWarning ? AppTheme.danger : (isStep ? Colors.white54 : Colors.green), fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: TextStyle(color: isWarning ? AppTheme.danger : Colors.white70, fontSize: 13))),
        ],
      ),
    );
  }
}