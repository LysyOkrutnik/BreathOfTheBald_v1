import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionHistoryProvider).value ?? const <Session>[];
    final profile = ref.watch(userProfileProvider).value;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.isTablet ? 760 : 560),
                child: Column(
                  children: [
                    ScreenHeader(title: L10n.get(context, 'stats_title')),
                    Expanded(
                      child: sessions.isEmpty
                          ? _empty(context)
                          : _content(context, sessions, profile),
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

  Widget _empty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insights_rounded,
              size: 64, color: AppTheme.textDim.withAlpha(110)),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              L10n.get(context, 'stats_empty'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textDim, fontSize: 15),
            ),
          ),
        ],
      ).animate().fadeIn(duration: AppMotion.slow),
    );
  }

  Widget _content(
      BuildContext context, List<Session> sessions, UserProfileData? profile) {
    final totalMinutes =
        sessions.fold<int>(0, (s, e) => s + e.durationSec) ~/ 60;
    final level = profile?.level ?? 1;
    final totalXp = profile?.totalXp ?? 0;
    final streak = profile?.dailyStreak ?? 0;

    final prevThreshold = (level - 1) * 500;
    final nextThreshold = level * 500;
    final xpProgress = nextThreshold > prevThreshold
        ? ((totalXp - prevThreshold) / (nextThreshold - prevThreshold))
            .clamp(0.0, 1.0)
        : 0.0;

    // Retention trend (oldest -> newest), only sessions that had a hold.
    final retention = sessions
        .where((s) => s.retentionSec > 0)
        .map((s) => s.retentionSec.toDouble())
        .toList()
        .reversed
        .toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
      children: [
        _HeroGrid(
          level: level,
          streak: streak,
          sessions: sessions.length,
          minutes: totalMinutes,
        ),
        const SizedBox(height: AppSpacing.md),
        _XpBar(level: level, progress: xpProgress, totalXp: totalXp),
        const SizedBox(height: AppSpacing.lg),
        if (retention.length >= 2) ...[
          _ChartCard(
            title: L10n.get(context, 'stats_retention_trend'),
            child: SizedBox(
              height: 120,
              child: CustomPaint(
                painter: _LineChartPainter(retention),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        _ChartCard(
          title: L10n.get(context, 'stats_activity'),
          child: _Heatmap(sessions: sessions),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ChartCard(
          title: L10n.get(context, 'stats_by_technique'),
          child: _TechniqueBreakdown(sessions: sessions),
        ),
      ],
    ).animate().fadeIn(duration: AppMotion.medium);
  }
}

class _HeroGrid extends StatelessWidget {
  const _HeroGrid({
    required this.level,
    required this.streak,
    required this.sessions,
    required this.minutes,
  });

  final int level;
  final int streak;
  final int sessions;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final cols = context.isTablet ? 4 : 2;
    final items = [
      (Icons.military_tech_outlined, '$level', L10n.get(context, 'stats_level')),
      (Icons.local_fire_department_outlined, '$streak',
          L10n.get(context, 'stats_streak')),
      (Icons.self_improvement, '$sessions',
          L10n.get(context, 'stats_sessions')),
      (Icons.timer_outlined, '$minutes', L10n.get(context, 'stats_minutes')),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        const gap = AppSpacing.md;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final it in items)
              SizedBox(
                width: w,
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg, horizontal: AppSpacing.md),
                  child: Column(
                    children: [
                      Icon(it.$1, color: AppTheme.primary, size: 24),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        it.$2,
                        style: const TextStyle(
                          color: AppTheme.textLight,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        it.$3,
                        style: const TextStyle(
                            color: AppTheme.textDim,
                            fontSize: 10,
                            letterSpacing: 1.0),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _XpBar extends StatelessWidget {
  const _XpBar(
      {required this.level, required this.progress, required this.totalXp});
  final int level;
  final double progress;
  final int totalXp;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  L10n.get(context, 'stats_xp_to_next'),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textDim, fontSize: 12),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$totalXp XP',
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: AppMotion.slow,
              curve: AppMotion.emphasized,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: Colors.white10,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                color: AppTheme.textDim,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter(this.values);
  final List<double> values;
  final Color color = AppTheme.primary;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final range = (maxV - minV).abs() < 1 ? 1.0 : (maxV - minV);

    Offset pt(int i) {
      final x = size.width * i / (values.length - 1);
      final norm = (values[i] - minV) / range;
      final y = size.height - norm * (size.height - 8) - 4;
      return Offset(x, y);
    }

    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(pt(i).dx, pt(i).dy);
    }

    // Gradient area fill under the line.
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withAlpha(80), color.withAlpha(0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    // Endpoint dot.
    final last = pt(values.length - 1);
    canvas.drawCircle(last, 4, Paint()..color = color);
    canvas.drawCircle(last, 7, Paint()..color = color.withAlpha(60));
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.values != values || old.color != color;
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.sessions});
  final List<Session> sessions;

  @override
  Widget build(BuildContext context) {
    const weeks = 12;
    final counts = <DateTime, int>{};
    for (final s in sessions) {
      final d = StatsScreen._dateOnly(s.timestamp);
      counts[d] = (counts[d] ?? 0) + 1;
    }
    final today = StatsScreen._dateOnly(DateTime.now());
    // Monday of the current week.
    final startMonday = today
        .subtract(Duration(days: (today.weekday - 1) + (weeks - 1) * 7));

    return LayoutBuilder(
      builder: (context, c) {
        // Each cell carries 3px of horizontal margin (1.5 each side), so the
        // slot per week is cell + 3. Subtract weeks*3 to avoid a few px overflow.
        final cell = ((c.maxWidth - weeks * 3) / weeks).clamp(8.0, 22.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var w = 0; w < weeks; w++)
              Column(
                children: [
                  for (var d = 0; d < 7; d++)
                    Builder(builder: (_) {
                      final date = startMonday.add(Duration(days: w * 7 + d));
                      final future = date.isAfter(today);
                      final n = counts[date] ?? 0;
                      return Container(
                        width: cell,
                        height: cell,
                        margin: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: future
                              ? Colors.transparent
                              : n == 0
                                  ? Colors.white.withAlpha(12)
                                  : AppTheme.primary
                                      .withAlpha((70 + n * 60).clamp(70, 255)),
                        ),
                      );
                    }),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _TechniqueBreakdown extends StatelessWidget {
  const _TechniqueBreakdown({required this.sessions});
  final List<Session> sessions;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final s in sessions) {
      counts[s.levelKey] = (counts[s.levelKey] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = entries.isEmpty ? 1 : entries.first.value;

    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _bar(context, e.key, e.value, maxCount),
          ),
      ],
    );
  }

  Widget _bar(BuildContext context, String levelKey, int count, int maxCount) {
    final level = LevelData.levels[levelKey];
    final color = level?.color ?? AppTheme.accent;
    final name = level != null ? L10n.get(context, level.title) : levelKey;
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textLight, fontSize: 12),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Stack(
              children: [
                Container(height: 10, color: Colors.white.withAlpha(12)),
                FractionallySizedBox(
                  widthFactor: (count / maxCount).clamp(0.05, 1.0),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      boxShadow: AppTheme.glow(color, blur: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 24,
          child: Text(
            '$count',
            textAlign: TextAlign.right,
            style: const TextStyle(
                color: AppTheme.textDim,
                fontSize: 12,
                fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
