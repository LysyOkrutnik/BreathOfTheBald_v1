import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/formatters.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/logic/freediving/co2_o2_table_generator.dart';
import 'package:okrutnik_breath/logic/notifiers/session_notifier.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/ui/screens/session_screen.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/confirm_dialog.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';

/// Lets the user build their own breath-hold table by hand — a fixed
/// apnea/rest schedule, linearly interpolated across rounds, rather than one
/// generated from their PB. Mirrors CustomBuilderScreen's pattern (name +
/// steppers + inline save/start) for the breathing-pattern builder.
class CustomFreedivingBuilderScreen extends ConsumerStatefulWidget {
  const CustomFreedivingBuilderScreen({super.key, this.existingPreset});

  /// Non-null when opened to edit an already-saved preset instead of
  /// creating a new one — pre-fills every field and Save overwrites it in
  /// place instead of inserting a second, separate preset.
  final CustomFreedivingPreset? existingPreset;

  @override
  ConsumerState<CustomFreedivingBuilderScreen> createState() =>
      _CustomFreedivingBuilderScreenState();
}

class _CustomFreedivingBuilderScreenState
    extends ConsumerState<CustomFreedivingBuilderScreen> {
  // This builder is deliberately free-form (no PB-relative cap the way the
  // generated CO2/O2 tables have one) — but leaving it completely blind to
  // the user's own PB meant it was easy to build a table more aggressive
  // than anything the app would ever generate itself, with nothing on
  // screen to notice. This is a soft heads-up, not a block: same
  // philosophy as _InvertedProgressionHint below.
  static const double _pbWarningRatio = 0.9;

  late final _nameController =
      TextEditingController(text: widget.existingPreset?.name ?? '');
  late int _startApnea = widget.existingPreset?.startApneaSec ?? 30;
  late int _endApnea = widget.existingPreset?.endApneaSec ?? 90;
  late int _startRest = widget.existingPreset?.startRestSec ?? 120;
  late int _endRest = widget.existingPreset?.endRestSec ?? 60;
  late int _rounds = widget.existingPreset?.rounds ?? 6;

  bool get _isEditing => widget.existingPreset != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  List<BreathHoldRound> get _rows => Co2O2TableGenerator.generateCustomTable(
        startApneaSec: _startApnea,
        endApneaSec: _endApnea,
        startRestSec: _startRest,
        endRestSec: _endRest,
        rounds: _rounds,
      );

  // Includes each round's breathe-up + final inhale + exhale, matching
  // FreedivingTableIntroScreen's estimate — omitting that overhead
  // understated real session length by several minutes over a full table.
  int get _totalSeconds => _rows.fold<int>(
      0,
      (s, r) =>
          s + r.apneaSec + r.restSec + FreedivingSessionTiming.perRoundOverheadSec);

  LevelData _buildLevel() {
    final name = _nameController.text.trim();
    return LevelData.customFreedivingTable(
      name: name.isEmpty ? L10n.get(context, 'custom_freediving_title') : name,
      rounds: _rows,
    );
  }

  int? get _verifiedPbSec => ref.read(freedivingProfileProvider).value?.verifiedPbSec;

  /// The table's peak apnea (the longer of start/end, since a soft-form
  /// table isn't guaranteed to grow) as a fraction of the user's own last
  /// verified PB — null when no PB is on file to compare against.
  double? get _peakPbRatio {
    final pb = _verifiedPbSec;
    if (pb == null || pb <= 0) return null;
    final peak = _startApnea > _endApnea ? _startApnea : _endApnea;
    return peak / pb;
  }

  // Unlike the generated CO2/O2 tables, a custom table has no PB-relative
  // safety cap at all — this is the one and only safety checkpoint it gets,
  // so it must never be skippable the way it was before (this screen used
  // to jump straight into SessionScreen).
  Future<void> _start() async {
    final ratio = _peakPbRatio;
    final approachesPb = ratio != null && ratio >= _pbWarningRatio;
    final confirmed = await showGlassDialog<bool>(
      context,
      builder: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 34),
          const SizedBox(height: AppSpacing.lg),
          Text(
            L10n.get(context, 'freediving_safety_rule1'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
          ),
          if (approachesPb) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              L10n.get(context, 'custom_freediving_pb_warning')
                  .replaceAll('{pct}', '${(ratio * 100).round()}'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.danger, fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    L10n.get(context, 'common_cancel'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    L10n.get(context, 'freediving_start_table'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref.read(sessionProvider.notifier).startSession(_buildLevel());
    Navigator.of(context).pushReplacement(fadeThroughRoute(const SessionScreen()));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      FocusScope.of(context).requestFocus(FocusNode());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.get(context, 'custom_name_hint'))),
      );
      return;
    }
    try {
      final repo = ref.read(customFreedivingRepositoryProvider);
      final existing = widget.existingPreset;
      if (existing != null) {
        await repo.updatePreset(
          id: existing.id,
          name: name,
          startApneaSec: _startApnea,
          endApneaSec: _endApnea,
          startRestSec: _startRest,
          endRestSec: _endRest,
          rounds: _rounds,
        );
      } else {
        await repo.addPreset(
          name: name,
          startApneaSec: _startApnea,
          endApneaSec: _endApnea,
          startRestSec: _startRest,
          endRestSec: _endRest,
          rounds: _rounds,
          createdAt: DateTime.now(),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.get(context, 'custom_saved'))),
        );
        if (existing != null) Navigator.of(context).pop();
      }
    } catch (e, st) {
      developer.log('Error saving custom freediving preset',
          name: 'CustomFreedivingBuilder', error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground(sectionAccent: AppTheme.danger)),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.isTablet ? 640 : 520),
                child: Column(
                  children: [
                    ScreenHeader(
                        title: L10n.get(context,
                            _isEditing ? 'custom_edit_title' : 'custom_freediving_title')),
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                        children: [
                          GlassCard(
                            padding:
                                const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                            child: TextField(
                              controller: _nameController,
                              style: const TextStyle(color: AppTheme.textLight),
                              cursorColor: AppTheme.danger,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: L10n.get(context, 'custom_name_hint'),
                                hintStyle: const TextStyle(color: AppTheme.textDim),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _Stepper(
                            label: L10n.get(context, 'custom_freediving_start_apnea'),
                            value: _startApnea,
                            suffix: 's',
                            min: 10,
                            max: 600,
                            step: 5,
                            color: AppTheme.danger,
                            onChanged: (v) => setState(() => _startApnea = v),
                          ),
                          _Stepper(
                            label: L10n.get(context, 'custom_freediving_end_apnea'),
                            value: _endApnea,
                            suffix: 's',
                            min: 10,
                            max: 600,
                            step: 5,
                            color: AppTheme.danger,
                            onChanged: (v) => setState(() => _endApnea = v),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _Stepper(
                            label: L10n.get(context, 'custom_freediving_start_rest'),
                            value: _startRest,
                            suffix: 's',
                            min: 10,
                            max: 300,
                            step: 5,
                            color: AppTheme.accent,
                            onChanged: (v) => setState(() => _startRest = v),
                          ),
                          _Stepper(
                            label: L10n.get(context, 'custom_freediving_end_rest'),
                            value: _endRest,
                            suffix: 's',
                            min: 10,
                            max: 300,
                            step: 5,
                            color: AppTheme.accent,
                            onChanged: (v) => setState(() => _endRest = v),
                          ),
                          if (_peakPbRatio != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            _PbRatioHint(
                              ratio: _peakPbRatio!,
                              warningRatio: _pbWarningRatio,
                              peakSeconds: _startApnea > _endApnea ? _startApnea : _endApnea,
                              pbSeconds: _verifiedPbSec!,
                            ),
                          ],
                          if (_endApnea < _startApnea || _endRest > _startRest) ...[
                            const SizedBox(height: AppSpacing.xs),
                            _InvertedProgressionHint(
                                apneaShrinks: _endApnea < _startApnea,
                                restGrows: _endRest > _startRest),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          _Stepper(
                            label: L10n.get(context, 'custom_rounds'),
                            value: _rounds,
                            min: 2,
                            max: 15,
                            step: 1,
                            color: AppTheme.primary,
                            onChanged: (v) => setState(() => _rounds = v),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          GlassCard(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            tint: AppTheme.danger,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.timer_outlined,
                                        color: AppTheme.danger, size: 20),
                                    const SizedBox(width: AppSpacing.md),
                                    Text(L10n.get(context, 'custom_total'),
                                        style: const TextStyle(
                                            color: AppTheme.textDim,
                                            fontSize: 13,
                                            letterSpacing: 1.0)),
                                  ],
                                ),
                                Text(formatMmSs(_totalSeconds),
                                    style: const TextStyle(
                                      color: AppTheme.textLight,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    )),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            children: [
                              Expanded(
                                child: _OutlineButton(
                                  label: L10n.get(context, 'custom_save'),
                                  onTap: _save,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _FilledButton(
                                  label: L10n.get(context, 'custom_start'),
                                  onTap: _start,
                                ),
                              ),
                            ],
                          ),
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
}

/// Shows the table's peak apnea as a percentage of the user's own last
/// verified PB, whenever one is on file — this builder has no other way to
/// tell someone dialing in raw seconds whether they've quietly built
/// something more aggressive than the app's own generated CO2/O2 tables
/// would ever produce.
class _PbRatioHint extends StatelessWidget {
  const _PbRatioHint({
    required this.ratio,
    required this.warningRatio,
    required this.peakSeconds,
    required this.pbSeconds,
  });
  final double ratio;
  final double warningRatio;
  final int peakSeconds;
  final int pbSeconds;

  @override
  Widget build(BuildContext context) {
    final warning = ratio >= warningRatio;
    final color = warning ? AppTheme.danger : AppTheme.textDim;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(warning ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
              color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              L10n.get(context, 'custom_freediving_pb_ratio_hint')
                  .replaceAll('{peak}', '$peakSeconds')
                  .replaceAll('{pct}', '${(ratio * 100).round()}')
                  .replaceAll('{pb}', '$pbSeconds'),
              style: TextStyle(color: color, fontSize: 11, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// A soft heads-up (not a block — this builder is deliberately free-form)
/// when the picked start/end values make the table get *easier* round over
/// round instead of harder, in case that wasn't intentional.
class _InvertedProgressionHint extends StatelessWidget {
  const _InvertedProgressionHint({required this.apneaShrinks, required this.restGrows});
  final bool apneaShrinks;
  final bool restGrows;

  @override
  Widget build(BuildContext context) {
    final key = apneaShrinks && restGrows
        ? 'custom_freediving_easier_both_hint'
        : apneaShrinks
            ? 'custom_freediving_easier_apnea_hint'
            : 'custom_freediving_easier_rest_hint';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.textDim, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              L10n.get(context, key),
              style: const TextStyle(color: AppTheme.textDim, fontSize: 11, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.color,
    required this.onChanged,
    this.suffix = '',
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final Color color;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GlassCard(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: AppTheme.textLight, fontSize: 14)),
            ),
            _circleButton(Icons.remove_rounded,
                value > min ? () => onChanged(value - step) : null),
            SizedBox(
              width: 56,
              child: Text(
                '$value$suffix',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            _circleButton(Icons.add_rounded,
                value < max ? () => onChanged(value + step) : null),
          ],
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback? onTap) {
    return Material(
      color: onTap == null ? Colors.white10 : AppTheme.danger.withAlpha(40),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        // Icon+padding alone was ~32x32 — below the 48dp minimum recommended
        // touch target, on a control tapped repeatedly while dialing in a
        // table's parameters.
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Icon(icon,
                size: 20, color: onTap == null ? Colors.white24 : AppTheme.danger),
          ),
        ),
      ),
    );
  }
}

class _FilledButton extends StatelessWidget {
  const _FilledButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppTheme.danger,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppTheme.glow(AppTheme.danger, blur: 20),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            )),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppTheme.danger.withAlpha(120)),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.danger,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            )),
      ),
    );
  }
}
