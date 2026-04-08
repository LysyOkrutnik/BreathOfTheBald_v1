import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/ui/widgets/particle_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

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
    _sessionsFuture = _loadSessions();
  }

  Future<List<Map<String, dynamic>>> _loadSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionStrings = prefs.getStringList('sessions') ?? [];
      
      final sessions = sessionStrings
          .map((s) {
            try {
              return jsonDecode(s) as Map<String, dynamic>;
            } catch (e) {
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();
      
      sessions.sort((a, b) {
        final dateA = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(0);
        final dateB = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(0);
        return dateB.compareTo(dateA);
      });

      return sessions;
    } catch (e) {
      debugPrint('Error loading sessions: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          const Positioned.fill(child: ParticleBackground()),
          SafeArea(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _sessionsFuture,
              builder: (context, snapshot) {
                final sessions = snapshot.data ?? [];
                
                if (isLandscape) {
                  return _buildLandscapeContent(context, sessions, snapshot.connectionState == ConnectionState.waiting);
                }

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildSliverAppBar(context),
                    if (sessions.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _buildProgressChart(sessions),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildPremiumSessionCard(sessions[index], index, sessions.length),
                            childCount: sessions.length,
                          ),
                        ),
                      ),
                    ] else if (snapshot.connectionState != ConnectionState.waiting)
                      _buildEmptyState()
                    else
                      const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeContent(BuildContext context, List<Map<String, dynamic>> sessions, bool isLoading) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              Text(
                L10n.get(context, 'history_title'),
                style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w200, fontSize: 18, letterSpacing: 4.0),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Expanded(
          child: isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : sessions.isEmpty 
              ? _buildEmptyStateWidget()
              : Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildProgressChart(sessions),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: sessions.length,
                        itemBuilder: (context, index) => _buildPremiumSessionCard(sessions[index], index, sessions.length),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyStateWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_toggle_off, color: Colors.white10, size: 64),
          const SizedBox(height: 16),
          Text(L10n.get(context, 'history_empty'), style: const TextStyle(color: AppTheme.textDim, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      centerTitle: true,
      title: Text(
        L10n.get(context, 'history_title'),
        style: const TextStyle(
          color: AppTheme.textLight,
          fontWeight: FontWeight.w200,
          fontSize: 22,
          letterSpacing: 4.0,
        ),
      ),
      floating: true,
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: _buildEmptyStateWidget(),
    );
  }

  Widget _buildProgressChart(List<Map<String, dynamic>> sessions) {
    final now = DateTime.now();
    final Map<int, double> dailySeconds = {};
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      dailySeconds[date.weekday] = 0;
    }

    for (var s in sessions) {
      final dt = DateTime.tryParse(s['timestamp'] ?? '');
      if (dt != null && now.difference(dt).inDays < 7) {
        dailySeconds[dt.weekday] = (dailySeconds[dt.weekday] ?? 0) + (s['duration'] ?? 0);
      }
    }

    final List<BarChartGroupData> barGroups = [];
    for (int i = 6; i >= 0; i--) {
      final dayDt = now.subtract(Duration(days: i));
      final day = dayDt.weekday;
      final val = (dailySeconds[day] ?? 0) / 60.0;
      
      barGroups.add(
        BarChartGroupData(
          x: 6 - i,
          barRods: [
            BarChartRodData(
              toY: val,
              color: AppTheme.primary,
              width: 12,
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: 20,
                color: Colors.white.withAlpha(13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(L10n.get(context, 'history_weekly_activity'), style: const TextStyle(color: AppTheme.textDim, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              Text(L10n.get(context, 'history_last_7_days'), style: TextStyle(color: Colors.white.withAlpha(51), fontSize: 10)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                barGroups: barGroups,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final keys = ['day_m', 'day_t', 'day_w', 'day_th', 'day_f', 'day_sa', 'day_su'];
                        final dayIndex = now.subtract(Duration(days: 6 - val.toInt())).weekday - 1;
                        return Text(L10n.get(context, keys[dayIndex]), style: const TextStyle(color: Colors.white24, fontSize: 10));
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumSessionCard(Map<String, dynamic> session, int index, int total) {
    final levelKey = session['levelKey'] ?? 'mild';
    final level = LevelData.levels[levelKey];
    final date = DateTime.tryParse(session['timestamp'] ?? '') ?? DateTime.now();
    final duration = session['duration'] ?? 0;
    final rounds = session['rounds'] ?? 0;
    final color = level?.color ?? AppTheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(color: Colors.white.withAlpha(13), border: Border.all(color: Colors.white.withAlpha(26))),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 4, decoration: BoxDecoration(color: color, boxShadow: [BoxShadow(color: color.withAlpha(128), blurRadius: 8)])),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(L10n.get(context, level?.title ?? levelKey).toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                const SizedBox(height: 2),
                                Text(DateFormat('MMM d • HH:mm').format(date), style: TextStyle(color: Colors.white.withAlpha(77), fontSize: 10)),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_sweep_outlined, color: AppTheme.danger, size: 18),
                              onPressed: () => _deleteSession(index),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMiniStat(Icons.timer_outlined, "${duration ~/ 60}m ${duration % 60}s"),
                            _buildMiniStat(Icons.refresh_rounded, "$rounds ${L10n.get(context, 'desc_rounds_pl').toLowerCase()}"),
                            _buildMiniStat(Icons.favorite_border_rounded, "${session['retentionSeconds'] ?? 0}s ${L10n.get(context, 'history_stat_hold')}"),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white30, size: 14),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Future<void> _deleteSession(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionStrings = prefs.getStringList('sessions') ?? [];
      final sessions = await _sessionsFuture;
      final sessionToDelete = sessions[index];
      
      sessionStrings.removeWhere((s) {
        final data = jsonDecode(s);
        return data['timestamp'] == sessionToDelete['timestamp'];
      });

      await prefs.setStringList('sessions', sessionStrings);
      setState(() => _sessionsFuture = _loadSessions());
    } catch (e) {
      debugPrint('Error deleting session: $e');
    }
  }
}
