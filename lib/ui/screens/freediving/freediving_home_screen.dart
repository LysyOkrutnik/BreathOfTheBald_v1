import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/logic/freediving/co2_o2_table_generator.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/ui/screens/freediving/freediving_table_intro_screen.dart';
import 'package:okrutnik_breath/ui/screens/freediving/max_pb_test_screen.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';

/// The "Freediving" bottom-nav tab. Only ever shown as a shell tab root —
/// the shared background lives in HomeShellScreen so it isn't torn down and
/// rebuilt (with its animation restarting) every time the tab is switched.
class FreedivingHomeScreen extends ConsumerWidget {
  const FreedivingHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(freedivingProfileProvider);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.isTablet ? 640 : 560),
          child: Column(
            children: [
              ScreenHeader(
                title: L10n.get(context, 'freediving_title'),
                showBackButton: false,
              ),
              Expanded(
                child: profileAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppTheme.danger),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (profile) {
                    if (profile == null || profile.safetyAcknowledgedAt == null) {
                      return _SafetyConsent(
                        onAccept: () => ref
                            .read(freedivingRepositoryProvider)
                            .acknowledgeSafety(),
                      );
                    }
                    return _FreedivingContent(profile: profile);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyConsent extends StatefulWidget {
  const _SafetyConsent({required this.onAccept});
  final VoidCallback onAccept;

  @override
  State<_SafetyConsent> createState() => _SafetyConsentState();
}

class _SafetyConsentState extends State<_SafetyConsent> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final rules = [
      'freediving_safety_rule1',
      'freediving_safety_rule2',
      'freediving_safety_rule3',
      'freediving_safety_rule4',
      'freediving_safety_rule5',
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
      children: [
        Icon(Icons.health_and_safety_rounded,
                color: AppTheme.danger, size: 48)
            .animate()
            .scale(duration: AppMotion.slow, curve: Curves.easeOutBack),
        const SizedBox(height: AppSpacing.md),
        Text(
          L10n.get(context, 'freediving_safety_title'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textLight,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          L10n.get(context, 'freediving_safety_intro'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textDim, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final key in rules)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: GlassCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              radius: AppRadius.md,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.priority_high_rounded,
                      color: AppTheme.danger, size: 18),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      L10n.get(context, key),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        GestureDetector(
          onTap: () => setState(() => _acknowledged = !_acknowledged),
          behavior: HitTestBehavior.opaque,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _acknowledged,
                activeColor: AppTheme.danger,
                onChanged: (v) => setState(() => _acknowledged = v ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    L10n.get(context, 'freediving_safety_checkbox'),
                    style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Opacity(
          opacity: _acknowledged ? 1.0 : 0.4,
          child: PressableScale(
            onTap: _acknowledged ? widget.onAccept : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppTheme.danger,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                L10n.get(context, 'freediving_safety_accept'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FreedivingContent extends StatelessWidget {
  const _FreedivingContent({required this.profile});
  final FreedivingProfileData profile;

  @override
  Widget build(BuildContext context) {
    final hasPb = profile.verifiedPbSec != null;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
      children: [
        Text(
          L10n.get(context, 'freediving_intro'),
          style: const TextStyle(color: AppTheme.textDim, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.lg),
        _PbCard(profile: profile),
        const SizedBox(height: AppSpacing.xl),
        _TableTile(
          tableType: FreedivingTableType.co2,
          titleKey: 'freediving_co2_title',
          subtitleKey: 'freediving_co2_subtitle',
          color: const Color(0xFF4FC3F7),
          icon: Icons.co2_rounded,
          pbSeconds: profile.virtualPbCo2Sec ?? profile.verifiedPbSec,
          enabled: hasPb,
        ),
        const SizedBox(height: AppSpacing.md),
        _TableTile(
          tableType: FreedivingTableType.o2,
          titleKey: 'freediving_o2_title',
          subtitleKey: 'freediving_o2_subtitle',
          color: const Color(0xFFFF7043),
          icon: Icons.bolt_rounded,
          pbSeconds: profile.virtualPbO2Sec ?? profile.verifiedPbSec,
          enabled: hasPb,
        ),
      ],
    );
  }
}

class _PbCard extends StatelessWidget {
  const _PbCard({required this.profile});
  final FreedivingProfileData profile;

  @override
  Widget build(BuildContext context) {
    final verified = profile.verifiedPbSec;
    final locale = Localizations.localeOf(context).toString();

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            L10n.get(context, 'freediving_pb_section_title'),
            style: const TextStyle(
                color: AppTheme.textDim,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          if (verified != null) ...[
            Row(
              children: [
                Icon(Icons.timer_outlined, color: AppTheme.primary, size: 22),
                const SizedBox(width: AppSpacing.md),
                Text(
                  '${verified ~/ 60}:${(verified % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: AppTheme.textLight,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(L10n.get(context, 'freediving_pb_verified_label'),
                    style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
              ],
            ),
            if (profile.verifiedPbAt != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${L10n.get(context, 'freediving_pb_tested_on')} '
                '${DateFormat('dd.MM.yyyy', locale).format(profile.verifiedPbAt!)}',
                style: TextStyle(color: AppTheme.textDim.withAlpha(180), fontSize: 11),
              ),
            ],
          ] else
            Text(
              L10n.get(context, 'freediving_pb_none'),
              style: const TextStyle(color: AppTheme.textDim, fontSize: 13),
            ),
          const SizedBox(height: AppSpacing.md),
          PressableScale(
            onTap: () => Navigator.of(context)
                .push(fadeThroughRoute(const MaxPbTestScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppTheme.primary.withAlpha(120)),
              ),
              child: Text(
                L10n.get(context,
                    verified == null ? 'freediving_pb_test_cta' : 'freediving_pb_retest'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableTile extends StatelessWidget {
  const _TableTile({
    required this.tableType,
    required this.titleKey,
    required this.subtitleKey,
    required this.color,
    required this.icon,
    required this.pbSeconds,
    required this.enabled,
  });

  final FreedivingTableType tableType;
  final String titleKey;
  final String subtitleKey;
  final Color color;
  final IconData icon;
  final int? pbSeconds;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final card = GlassCard(
      gradient: enabled ? AppTheme.cardGradient(color) : null,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Icon(icon, color: enabled ? color : AppTheme.textDim, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.get(context, titleKey),
                  style: TextStyle(
                    color: enabled ? AppTheme.textLight : AppTheme.textDim,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  enabled
                      ? L10n.get(context, subtitleKey)
                      : L10n.get(context, 'freediving_locked_no_pb'),
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textDim.withAlpha(190)),
                ),
              ],
            ),
          ),
          Icon(
            enabled ? Icons.chevron_right_rounded : Icons.lock_outline_rounded,
            color: enabled ? color.withAlpha(160) : Colors.white24,
            size: 20,
          ),
        ],
      ),
    );

    if (!enabled) return Opacity(opacity: 0.6, child: card);

    return PressableScale(
      onTap: () => Navigator.of(context).push(fadeThroughRoute(
        FreedivingTableIntroScreen(tableType: tableType, pbSeconds: pbSeconds!),
      )),
      child: card,
    );
  }
}
