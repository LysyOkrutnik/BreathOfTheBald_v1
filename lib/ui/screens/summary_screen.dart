import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/logic/notifiers/session_notifier.dart';
import 'package:okrutnik_breath/ui/screens/menu_screen.dart';
import 'package:okrutnik_breath/ui/widgets/particle_background.dart';

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.read(sessionProvider);
    final duration = state.sessionDuration ?? Duration.zero;
    final String durationStr = "${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          const Positioned.fill(child: ParticleBackground()),
          SafeArea(
            child: isLandscape 
                ? _buildLandscapeLayout(context, state, durationStr)
                : _buildPortraitLayout(context, state, durationStr),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context, dynamic state, String durationStr) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(30.0),
        child: Column(
          children: [
            _buildSuccessHeader(context),
            const SizedBox(height: 40),
            _buildStatRow(context, Icons.timer, 'summary_stat_duration', durationStr),
            if (state.totalRounds > 1) ...[
              const SizedBox(height: 16),
              _buildStatRow(context, Icons.refresh, 'summary_stat_rounds', "${state.currentRound} / ${state.totalRounds}"),
            ],
            if (state.retentionLogs.isNotEmpty) ...[
              const SizedBox(height: 30),
              _buildRetentionGrid(context, state.retentionLogs),
            ],
            const SizedBox(height: 50),
            _buildMenuButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context, dynamic state, String durationStr) {
    return Row(
      children: [
        
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSuccessHeader(context, small: true),
                const SizedBox(height: 32),
                _buildStatRow(context, Icons.timer, 'summary_stat_duration', durationStr),
                if (state.totalRounds > 1) ...[
                  const SizedBox(height: 12),
                  _buildStatRow(context, Icons.refresh, 'summary_stat_rounds', "${state.currentRound} / ${state.totalRounds}"),
                ],
                const SizedBox(height: 32),
                _buildMenuButton(context),
              ],
            ),
          ),
        ),
        VerticalDivider(color: Colors.white.withAlpha(13), width: 1),
        
        Expanded(
          flex: 5,
          child: state.retentionLogs.isNotEmpty 
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L10n.get(context, 'summary_retention_times').toUpperCase(),
                        style: const TextStyle(color: AppTheme.textDim, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
                      ),
                      const SizedBox(height: 20),
                      _buildRetentionGrid(context, state.retentionLogs, isCompact: true),
                    ],
                  ),
                )
              : const Center(child: Icon(Icons.spa_outlined, color: Colors.white10, size: 64)),
        ),
      ],
    );
  }

  Widget _buildSuccessHeader(BuildContext context, {bool small = false}) {
    return Column(
      children: [
        Icon(Icons.check_circle_outline, color: AppTheme.primary, size: small ? 48 : 64),
        const SizedBox(height: 16),
        Text(
          L10n.get(context, 'summary_title'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: small ? 20 : 24, fontWeight: FontWeight.w200, letterSpacing: 4.0),
        ),
        const SizedBox(height: 8),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(color: Colors.white.withAlpha(153), fontSize: small ? 13 : 15),
            children: [
              TextSpan(text: "${L10n.get(context, 'summary_great_job')}, "),
              TextSpan(text: L10n.get(context, 'summary_okrutnik'), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
              const TextSpan(text: "."),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(BuildContext context, IconData icon, String labelKey, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(13)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 22),
          const SizedBox(width: 16),
          Expanded(child: Text(L10n.get(context, labelKey), style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.2))),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRetentionGrid(BuildContext context, List<Duration> logs, {bool isCompact = false}) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: logs.asMap().entries.map((entry) {
        final i = entry.key + 1;
        final d = entry.value;
        final time = "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha(13)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("${L10n.get(context, 'summary_retention_round')} $i", style: const TextStyle(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.bold)),
              Text(time, style: const TextStyle(color: AppTheme.textLight, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MenuScreen()),
          (route) => false,
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      child: Text(
        L10n.get(context, 'summary_back_to_menu').toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
    );
  }
}
