import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/ui/widgets/particle_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Map<String, dynamic>>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh sessions whenever screen comes into focus
    _sessionsFuture = _loadSessions();
  }

  Future<List<Map<String, dynamic>>> _loadSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionStrings = prefs.getStringList('sessions') ?? [];
      debugPrint('Total sessions found: ${sessionStrings.length}');

      final sessions = sessionStrings
          .map((s) {
            try {
              return jsonDecode(s) as Map<String, dynamic>;
            } catch (e) {
              debugPrint('Error decoding session: $e');
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList()
          .reversed
          .toList();

      return sessions;
    } catch (e) {
      debugPrint('Error loading sessions: $e');
      return [];
    }
  }

  String _getLevelName(String levelKey, BuildContext context) {
    final level = LevelData.levels[levelKey];
    if (level != null) {
      return L10n.get(context, level.title);
    }
    return levelKey;
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd.MM.yyyy HH:mm').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          const Positioned.fill(child: ParticleBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          L10n.get(context, 'history_title'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textLight,
                            fontWeight: FontWeight.w300,
                            fontSize: 20,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      setState(() {
                        _sessionsFuture = _loadSessions();
                      });
                      await _sessionsFuture;
                    },
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _sessionsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: AppTheme.primary),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(
                            child: Text(
                              L10n.get(context, 'history_empty'),
                              style: TextStyle(color: AppTheme.textDim, fontSize: 16),
                            ),
                          );
                        }

                        final sessions = snapshot.data!;
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: sessions.length,
                          itemBuilder: (context, index) {
                            final session = sessions[index];
                            final levelName = _getLevelName(session['levelKey'], context);
                            final duration = _formatDuration(session['duration'] ?? 0);
                            final date = _formatDate(session['timestamp'] ?? '');

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primary.withAlpha(38),
                                    Colors.transparent,
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.primary.withAlpha(77), width: 1),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          levelName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.textLight,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          date,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textDim.withAlpha(179),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          duration,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${session['rounds']} ${L10n.get(context, 'desc_rounds')}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textDim.withAlpha(179),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
