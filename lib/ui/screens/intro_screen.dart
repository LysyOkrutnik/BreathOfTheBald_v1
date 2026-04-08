import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/ui/screens/session_screen.dart';
import 'package:okrutnik_breath/ui/widgets/particle_background.dart';

class IntroScreen extends StatelessWidget {
  final LevelData level;

  const IntroScreen({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          const Positioned.fill(child: ParticleBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, isLandscape),
                Expanded(
                  child: isLandscape ? _buildLandscapeLayout(context) : _buildPortraitLayout(context),
                ),
                _buildStartButton(context),
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
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Text(
            L10n.get(context, level.title).toUpperCase(),
            style: TextStyle(
              color: level.color,
              fontWeight: FontWeight.bold,
              fontSize: isLandscape ? 18 : 22,
              letterSpacing: 4.0,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 30.0),
      child: Column(
        children: [
          Text(
            L10n.get(context, level.instructionDescriptionKey),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 40),
          ...level.instructionStepKeys.map((key) => _buildStepTile(context, key)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, color: level.color.withAlpha(150), size: 48),
                const SizedBox(height: 20),
                Text(
                  L10n.get(context, level.instructionDescriptionKey),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        VerticalDivider(color: Colors.white.withAlpha(13), width: 1),
        Expanded(
          flex: 6,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: level.instructionStepKeys.length,
            itemBuilder: (context, index) => _buildStepTile(context, level.instructionStepKeys[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildStepTile(BuildContext context, String key) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(13)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: level.color.withAlpha(38), shape: BoxShape.circle),
            child: Icon(Icons.check, color: level.color, size: 14),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              L10n.get(context, key),
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: ElevatedButton(
        onPressed: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => SessionScreen(level: level)),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: level.color,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: level.color.withAlpha(128),
        ),
        child: Text(
          L10n.get(context, 'start_session_button').toUpperCase(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2.0),
        ),
      ),
    );
  }
}
