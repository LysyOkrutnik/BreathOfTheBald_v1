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
    // Use ref.read for immutable state, as the session is finished and will not change.
    final state = ref.read(sessionProvider);

    final duration = state.sessionDuration ?? Duration.zero;
    final String durationStr = "${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(child: ParticleBackground()),
          Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.check_circle_outline, color: AppTheme.primary, size: 80),
                  const SizedBox(height: 20),
                  Text(
                    L10n.get(context, 'summary_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 3.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.white.withAlpha(153),
                        fontSize: 16,
                      ),
                      children: [
                        TextSpan(text: "${L10n.get(context, 'summary_great_job')}, "),
                        TextSpan(
                          text: L10n.get(context, 'summary_okrutnik'),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                        const TextSpan(text: "."),
                      ],
                    ),
                  ),

                  const SizedBox(height: 50),

                  _buildStatRow(context, Icons.timer, 'summary_stat_duration', durationStr),

                  // Conditionally display the round counter only for multi-round sessions.
                  if (state.totalRounds > 1) ...[
                    const SizedBox(height: 20),
                    _buildStatRow(context, Icons.all_inclusive, 'summary_stat_rounds', "${state.totalRounds}"),
                  ],

                  // Display retention times only if the session included breath holds.
                  if (state.retentionLogs.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    Text(
                      L10n.get(context, 'summary_retention_times'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textDim, fontSize: 12, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 15),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: state.retentionLogs.asMap().entries.map((entry) {
                        final i = entry.key + 1;
                        final d = entry.value;
                        final time = "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(13),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text("${L10n.get(context, 'summary_retention_round')} $i: $time", style: const TextStyle(color: Colors.white70)),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 60),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const MenuScreen()),
                            (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text(
                      L10n.get(context, 'summary_back_to_menu'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, IconData icon, String labelKey, String value) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 28),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              L10n.get(context, labelKey),
              style: const TextStyle(color: Colors.white54, letterSpacing: 1.5, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}