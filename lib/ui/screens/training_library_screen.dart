import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/ui/screens/freediving/freediving_home_screen.dart';
import 'package:okrutnik_breath/ui/screens/mobility_screen.dart';
import 'package:okrutnik_breath/ui/screens/scheduler_screen.dart';
import 'package:okrutnik_breath/ui/screens/special_screen.dart';
import 'package:okrutnik_breath/ui/screens/wim_hof_screen.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';

/// The "Trening" bottom-nav tab — a single browsable library replacing what
/// used to be three separate tabs (Wim Hof / Ćwiczenia specjalne /
/// Freediving), each its own disconnected "world". A segmented control swaps
/// between the exact same three screens (their internal logic and content
/// are unchanged — only the navigation surrounding them collapsed from 3
/// bottom-nav destinations into 3 segments of one). A calendar icon opens the
/// existing Scheduler unchanged — manual date-based planning is a distinct,
/// less-frequent action from browsing what to train.
class TrainingLibraryScreen extends StatefulWidget {
  const TrainingLibraryScreen({super.key});

  @override
  State<TrainingLibraryScreen> createState() => _TrainingLibraryScreenState();
}

class _TrainingLibraryScreenState extends State<TrainingLibraryScreen> {
  int _segment = 0;

  static const _sections = [
    WimHofScreen(),
    SpecialScreen(),
    FreedivingHomeScreen(),
    MobilityScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: _SegmentedControl(
                    labels: [
                      L10n.get(context, 'training_segment_classic'),
                      L10n.get(context, 'training_segment_special'),
                      L10n.get(context, 'training_segment_freediving'),
                      L10n.get(context, 'training_segment_mobility'),
                    ],
                    selected: _segment,
                    onChanged: (i) => setState(() => _segment = i),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _CalendarButton(
                  onTap: () => Navigator.of(context)
                      .push(fadeThroughRoute(const SchedulerScreen())),
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _segment,
              children: _sections,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppTheme.glassBorder.withAlpha(40)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == selected ? AppTheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: i == selected ? Colors.black : AppTheme.textDim,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CalendarButton extends StatelessWidget {
  const _CalendarButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withAlpha(14),
          border: Border.all(color: AppTheme.glassBorder.withAlpha(40)),
        ),
        child: const Icon(Icons.calendar_month_outlined, color: AppTheme.textLight, size: 20),
      ),
    );
  }
}
