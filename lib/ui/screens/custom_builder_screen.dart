import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/logic/notifiers/session_notifier.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/ui/screens/session_screen.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';

class CustomBuilderScreen extends ConsumerStatefulWidget {
  const CustomBuilderScreen({super.key, this.existingPreset});

  /// Non-null when opened to edit an already-saved preset instead of
  /// creating a new one — pre-fills every field and Save overwrites it in
  /// place instead of inserting a second, separate preset.
  final CustomPreset? existingPreset;

  @override
  ConsumerState<CustomBuilderScreen> createState() => _CustomBuilderScreenState();
}

class _CustomBuilderScreenState extends ConsumerState<CustomBuilderScreen> {
  late final _nameController =
      TextEditingController(text: widget.existingPreset?.name ?? '');
  late int _inhale = widget.existingPreset?.inhaleSec ?? 4;
  late int _holdIn = widget.existingPreset?.holdInSec ?? 4;
  late int _exhale = widget.existingPreset?.exhaleSec ?? 4;
  late int _holdOut = widget.existingPreset?.holdOutSec ?? 4;
  late int _cycles = widget.existingPreset?.cycles ?? 8;
  late int _rounds = widget.existingPreset?.rounds ?? 1;

  bool get _isEditing => widget.existingPreset != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int get _totalSeconds =>
      (_inhale + _holdIn + _exhale + _holdOut) * _cycles * _rounds;

  bool get _isValid => _inhale > 0 || _exhale > 0;

  String _fmt(int s) => "${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}";

  LevelData _buildLevel() {
    final name = _nameController.text.trim();
    return LevelData.custom(
      name: name.isEmpty ? L10n.get(context, 'custom_title') : name,
      inhaleSec: _inhale,
      holdInSec: _holdIn,
      exhaleSec: _exhale,
      holdOutSec: _holdOut,
      cycles: _cycles,
      rounds: _rounds,
    );
  }

  void _start() {
    ref.read(sessionProvider.notifier).startSession(_buildLevel());
    Navigator.of(context).pushReplacement(fadeThroughRoute(const SessionScreen()));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final savedMsg = L10n.get(context, 'custom_saved');
    if (name.isEmpty) {
      FocusScope.of(context).requestFocus(FocusNode());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.get(context, 'custom_name_hint'))),
      );
      return;
    }
    try {
      final repo = ref.read(customPresetRepositoryProvider);
      final existing = widget.existingPreset;
      if (existing != null) {
        await repo.updatePreset(
          id: existing.id,
          name: name,
          inhaleSec: _inhale,
          holdInSec: _holdIn,
          exhaleSec: _exhale,
          holdOutSec: _holdOut,
          cycles: _cycles,
          rounds: _rounds,
        );
      } else {
        await repo.addPreset(
          name: name,
          inhaleSec: _inhale,
          holdInSec: _holdIn,
          exhaleSec: _exhale,
          holdOutSec: _holdOut,
          cycles: _cycles,
          rounds: _rounds,
          createdAt: DateTime.now(),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(savedMsg)));
        if (existing != null) Navigator.of(context).pop();
      }
    } catch (e, st) {
      developer.log('Error saving preset',
          name: 'CustomBuilder', error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground(sectionAccent: AppTheme.accent)),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.isTablet ? 640 : 520),
                child: Column(
                  children: [
                    ScreenHeader(
                        title: L10n.get(
                            context, _isEditing ? 'custom_edit_title' : 'custom_title')),
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                        children: [
                          GlassCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg),
                            child: TextField(
                              controller: _nameController,
                              style: const TextStyle(color: AppTheme.textLight),
                              cursorColor: AppTheme.primary,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: L10n.get(context, 'custom_name_hint'),
                                hintStyle: const TextStyle(color: AppTheme.textDim),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _StepperRow(
                            label: L10n.get(context, 'custom_inhale'),
                            value: _inhale,
                            suffix: 's',
                            min: 0,
                            max: 20,
                            color: AppTheme.breathInhale,
                            onChanged: (v) => setState(() => _inhale = v),
                          ),
                          _StepperRow(
                            label: L10n.get(context, 'custom_hold_in'),
                            value: _holdIn,
                            suffix: 's',
                            min: 0,
                            max: 30,
                            color: AppTheme.textDim,
                            onChanged: (v) => setState(() => _holdIn = v),
                          ),
                          _StepperRow(
                            label: L10n.get(context, 'custom_exhale'),
                            value: _exhale,
                            suffix: 's',
                            min: 0,
                            max: 20,
                            color: AppTheme.breathExhale,
                            onChanged: (v) => setState(() => _exhale = v),
                          ),
                          _StepperRow(
                            label: L10n.get(context, 'custom_hold_out'),
                            value: _holdOut,
                            suffix: 's',
                            min: 0,
                            max: 30,
                            color: AppTheme.textDim,
                            onChanged: (v) => setState(() => _holdOut = v),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _StepperRow(
                            label: L10n.get(context, 'custom_cycles'),
                            value: _cycles,
                            min: 1,
                            max: 60,
                            color: AppTheme.primary,
                            onChanged: (v) => setState(() => _cycles = v),
                          ),
                          _StepperRow(
                            label: L10n.get(context, 'custom_rounds'),
                            value: _rounds,
                            min: 1,
                            max: 10,
                            color: AppTheme.primary,
                            onChanged: (v) => setState(() => _rounds = v),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _TotalTime(label: L10n.get(context, 'custom_total'), value: _fmt(_totalSeconds)),
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
                                  enabled: _isValid,
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

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.onChanged,
    this.suffix = '',
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final Color color;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
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
                  style: const TextStyle(
                      color: AppTheme.textLight, fontSize: 14)),
            ),
            _circleButton(Icons.remove_rounded,
                value > min ? () => onChanged(value - 1) : null),
            SizedBox(
              width: 52,
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
                value < max ? () => onChanged(value + 1) : null),
          ],
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback? onTap) {
    return Material(
      color: onTap == null ? Colors.white10 : AppTheme.primary.withAlpha(40),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        // Icon+padding alone was ~32x32 — below the 48dp minimum recommended
        // touch target, on a control tapped repeatedly while dialing in a
        // pattern's timings.
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Icon(icon,
                size: 20,
                color: onTap == null ? Colors.white24 : AppTheme.primary),
          ),
        ),
      ),
    );
  }
}

class _TotalTime extends StatelessWidget {
  const _TotalTime({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      tint: AppTheme.accent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppTheme.accent, size: 20),
              const SizedBox(width: AppSpacing.md),
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textDim,
                      fontSize: 13,
                      letterSpacing: 1.0)),
            ],
          ),
          Text(value,
              style: const TextStyle(
                color: AppTheme.textLight,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              )),
        ],
      ),
    );
  }
}

class _FilledButton extends StatelessWidget {
  const _FilledButton(
      {required this.label, required this.onTap, this.enabled = true});
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: PressableScale(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: enabled ? AppTheme.glow(AppTheme.primary, blur: 20) : null,
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              )),
        ),
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
          border: Border.all(color: AppTheme.primary.withAlpha(120)),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            )),
      ),
    );
  }
}
