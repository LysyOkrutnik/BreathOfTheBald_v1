import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/ui/widgets/particle_background.dart';

class InstructionScreen extends StatefulWidget {
  const InstructionScreen({super.key});

  @override
  State<InstructionScreen> createState() => _InstructionScreenState();
}

class _InstructionScreenState extends State<InstructionScreen> {
  int _selectedTopicIndex = 0;

  final List<Map<String, dynamic>> _topics = [
    {
      "titleKey": "guide_app_usage_title",
      "subtitleKey": "guide_app_usage_subtitle",
      "color": Colors.white,
      "icon": Icons.touch_app,
      "descriptionKey": "guide_app_usage_desc",
      "benefitKeys": ["guide_app_usage_benefit1", "guide_app_usage_benefit2", "guide_app_usage_benefit3"],
      "warningKeys": [],
      "stepKeys": ["guide_app_usage_step1", "guide_app_usage_step2", "guide_app_usage_step3", "guide_app_usage_step4"],
    },
    {
      "titleKey": "guide_classic_method_title",
      "subtitleKey": "guide_classic_method_subtitle",
      "color": const Color(0xFF4DB6AC),
      "icon": Icons.waves,
      "descriptionKey": "guide_classic_method_desc",
      "benefitKeys": ["guide_classic_method_benefit1", "guide_classic_method_benefit2", "guide_classic_method_benefit3", "guide_classic_method_benefit4"],
      "warningKeys": ["guide_classic_method_warning1", "guide_classic_method_warning2", "guide_classic_method_warning3", "guide_classic_method_warning4"],
      "stepKeys": ["guide_classic_method_step1", "guide_classic_method_step2", "guide_classic_method_step3", "guide_classic_method_step4"],
    },
    {
      "titleKey": "guide_box_breathing_title",
      "subtitleKey": "guide_box_breathing_subtitle",
      "color": const Color(0xFF5C6BC0),
      "icon": Icons.crop_square,
      "descriptionKey": "guide_box_breathing_desc",
      "benefitKeys": ["guide_box_breathing_benefit1", "guide_box_breathing_benefit2", "guide_box_breathing_benefit3", "guide_box_breathing_benefit4"],
      "warningKeys": ["guide_box_breathing_warning1", "guide_box_breathing_warning2"],
      "stepKeys": ["guide_box_breathing_step1", "guide_box_breathing_step2", "guide_box_breathing_step3", "guide_box_breathing_step4"],
    },
    {
      "titleKey": "guide_478_title",
      "subtitleKey": "guide_478_subtitle",
      "color": const Color(0xFFBA68C8),
      "icon": Icons.nights_stay,
      "descriptionKey": "guide_478_desc",
      "benefitKeys": ["guide_478_benefit1", "guide_478_benefit2", "guide_478_benefit3", "guide_478_benefit4"],
      "warningKeys": ["guide_478_warning1", "guide_478_warning2"],
      "stepKeys": ["guide_478_step1", "guide_478_step2", "guide_478_step3"],
    },
    {
      "titleKey": "guide_fire_breath_title",
      "subtitleKey": "guide_fire_breath_subtitle",
      "color": AppTheme.danger,
      "icon": Icons.local_fire_department,
      "descriptionKey": "guide_fire_breath_desc",
      "benefitKeys": ["guide_fire_breath_benefit1", "guide_fire_breath_benefit2", "guide_fire_breath_benefit3", "guide_fire_breath_benefit4"],
      "warningKeys": ["guide_fire_breath_warning1", "guide_fire_breath_warning2", "guide_fire_breath_warning3", "guide_fire_breath_warning4"],
      "stepKeys": ["guide_fire_breath_step1", "guide_fire_breath_step2", "guide_fire_breath_step3", "guide_fire_breath_step4"],
    },
    {
      "titleKey": "guide_rules_title",
      "subtitleKey": "guide_rules_subtitle",
      "color": Colors.grey,
      "icon": Icons.lightbulb,
      "descriptionKey": "guide_rules_desc",
      "benefitKeys": ["guide_rules_benefit1", "guide_rules_benefit2"],
      "warningKeys": [],
      "stepKeys": ["guide_rules_step1", "guide_rules_step2", "guide_rules_step3", "guide_rules_step4"],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          const Positioned.fill(child: ParticleBackground()),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(77),
                    Colors.transparent,
                    Colors.black.withAlpha(204),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, isLandscape),
                Expanded(
                  child: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isLandscape) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: isLandscape ? 10 : 20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              L10n.get(context, 'guide_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textLight,
                  fontWeight: FontWeight.w300,
                  fontSize: isLandscape ? 18 : 20,
                  letterSpacing: 2.0
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
      itemCount: _topics.length + 2, 
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Text(
              L10n.get(context, 'guide_select_topic'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white30, fontSize: 12),
            ),
          );
        }
        if (index == _topics.length + 1) {
          return _buildDisclaimer();
        }
        final topic = _topics[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: _buildTechniqueExpansionTile(topic),
        );
      },
    );
  }

  Widget _buildLandscapeLayout() {
    final selectedTopic = _topics[_selectedTopicIndex];

    return Row(
      children: [
        
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.white.withAlpha(13))),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _topics.length,
              itemBuilder: (context, index) {
                final topic = _topics[index];
                final isSelected = _selectedTopicIndex == index;
                final color = topic['color'] as Color;

                return GestureDetector(
                  onTap: () => setState(() => _selectedTopicIndex = index),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withAlpha(38) : Colors.white.withAlpha(13),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? color.withAlpha(128) : Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        Icon(topic['icon'] as IconData, color: isSelected ? color : Colors.white30, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            L10n.get(context, topic['titleKey']),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopicContent(selectedTopic),
                const SizedBox(height: 40),
                _buildDisclaimer(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopicContent(Map<String, dynamic> topic) {
    final color = topic['color'] as Color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withAlpha(38), shape: BoxShape.circle),
              child: Icon(topic['icon'] as IconData, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L10n.get(context, topic['titleKey']), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  Text(L10n.get(context, topic['subtitleKey']), style: TextStyle(color: color.withAlpha(204), fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Text(L10n.get(context, topic['descriptionKey']), style: const TextStyle(color: Colors.white70, height: 1.6, fontSize: 15)),
        const SizedBox(height: 25),

        if ((topic['benefitKeys'] as List).isNotEmpty) ...[
          _buildSectionHeader(L10n.get(context, 'guide_section_benefits'), Colors.greenAccent),
          ...(topic['benefitKeys'] as List<String>).map((key) => _buildBullet(context, key)),
          const SizedBox(height: 20),
        ],

        if ((topic['warningKeys'] as List).isNotEmpty) ...[
          _buildSectionHeader(L10n.get(context, 'guide_section_warnings'), Colors.redAccent),
          ...(topic['warningKeys'] as List<String>).map((key) => _buildBullet(context, key, isWarning: true)),
          const SizedBox(height: 20),
        ],

        _buildSectionHeader(L10n.get(context, 'guide_section_instructions'), Colors.blueAccent),
        ...(topic['stepKeys'] as List<String>).map((key) => _buildBullet(context, key, isStep: true)),
      ],
    );
  }

  Widget _buildTechniqueExpansionTile(Map<String, dynamic> topic) {
    final color = topic['color'] as Color;
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
            decoration: BoxDecoration(color: color.withAlpha(38), shape: BoxShape.circle),
            child: Icon(topic['icon'] as IconData, color: color, size: 28),
          ),
          title: Text(
            L10n.get(context, topic['titleKey']),
            style: const TextStyle(color: AppTheme.textLight, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          subtitle: Text(
            L10n.get(context, topic['subtitleKey']),
            style: TextStyle(color: color.withAlpha(204), fontSize: 12),
          ),
          children: [
            _buildTopicContent(topic),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 12.0),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: color),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0)),
        ],
      ),
    );
  }

  Widget _buildBullet(BuildContext context, String textKey, {bool isWarning = false, bool isStep = false}) {
    final text = L10n.get(context, textKey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("• ", style: TextStyle(color: isWarning ? Colors.red : (isStep ? Colors.white54 : Colors.green), fontWeight: FontWeight.bold, fontSize: 16)),
          Expanded(child: Text(text, style: TextStyle(color: isWarning ? const Color(0xFFFFCDD2) : Colors.white70, fontSize: 14, height: 1.4))),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(16),
        color: Colors.black26,
      ),
      child: Text(
        L10n.get(context, 'guide_disclaimer'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white30, fontSize: 11, fontStyle: FontStyle.italic, height: 1.5),
      ),
    );
  }
}
