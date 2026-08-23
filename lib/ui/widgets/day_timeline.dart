import 'package:flutter/material.dart';

/// A vertical hour-ruled timeline for a single day. Each event is a fixed-
/// height card positioned at its start time (not a duration-scaled block —
/// most sessions are short enough that a literal proportional height would
/// be smaller than the card's own content needs to stay legible); when a
/// [TimelineItem] carries a known [TimelineItem.durationSec], a thin
/// coloured bar alongside it shows how long the session actually runs, and
/// turns red when [TimelineItem.hasOverlap] flags a same-day clash with
/// another item — a real answer to "does this collide with something
/// else today" instead of every plan reading as an identical, duration-less
/// point in time.
class DayTimeline extends StatelessWidget {
  const DayTimeline({
    super.key,
    required this.items,
    this.startHour = 0,
    this.endHour = 23,
    this.hourHeight = 64,
  });

  final List<TimelineItem> items;
  final int startHour;
  final int endHour;
  final double hourHeight;

  @override
  Widget build(BuildContext context) {
    final hourCount = endHour - startHour + 1;
    final totalHeight = hourCount * hourHeight;
    const labelWidth = 44.0;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          // A plain Column of fixed-height rows for the hour ruler — a Stack
          // whose children are *all* Positioned has no non-positioned child
          // to size itself against, which is exactly the kind of layout this
          // widget doesn't need to lean on. The ruler is its own regular
          // child here instead, guaranteeing every hour actually lays out.
          // Excluded from semantics: a screen reader stepping through 24
          // "00:00", "01:00"... labels before ever reaching an actual event
          // is pure noise — each event's own merged label below already
          // states its time.
          ExcludeSemantics(
            child: Column(
              children: [
                for (var h = 0; h < hourCount; h++)
                  SizedBox(
                    height: hourHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: labelWidth,
                          child: Text(
                            '${(startHour + h).toString().padLeft(2, '0')}:00',
                            style: const TextStyle(
                                color: Colors.white30, fontSize: 10),
                          ),
                        ),
                        Expanded(
                          child: Container(
                              height: 1, color: Colors.white.withAlpha(18)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Drawn first (behind the cards, which have their own opaque
          // background) — a slim bar in the gap between the hour labels
          // and the cards, spanning from an item's start time to its
          // estimated end. Sits alongside the ruler rather than on the
          // card itself, since most sessions are short enough that a truly
          // duration-scaled card would be smaller than its own content.
          for (final item in items)
            if (item.durationSec != null && item.durationSec! > 0)
              Positioned(
                top: _offsetFor(item.time),
                left: labelWidth + 2,
                width: 4,
                height: (item.durationSec! / 3600 * hourHeight)
                    .clamp(4.0, totalHeight - _offsetFor(item.time)),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: item.hasOverlap ? Colors.redAccent : Colors.white38,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          for (final item in items)
            Positioned(
              top: (_offsetFor(item.time) - 20).clamp(0.0, totalHeight - 40),
              left: labelWidth + 8,
              right: 0,
              // Merges whatever the item's child exposes (e.g. a time label
              // and a title as separate Text widgets) into one semantic
              // node, so a screen reader reads it as a single coherent
              // phrase instead of disconnected fragments.
              child: MergeSemantics(child: item.child),
            ),
        ],
      ),
    );
  }

  double _offsetFor(TimeOfDay time) {
    final clampedHour = time.hour.clamp(startHour, endHour);
    return (clampedHour - startHour) * hourHeight +
        (time.minute / 60) * hourHeight;
  }
}

class TimelineItem {
  const TimelineItem({
    required this.time,
    required this.child,
    this.durationSec,
    this.hasOverlap = false,
  });
  final TimeOfDay time;
  final Widget child;

  /// Estimated length in seconds — null for a plan saved before this field
  /// existed, or one whose duration genuinely isn't knowable. Null draws no
  /// duration bar at all rather than guessing.
  final int? durationSec;

  /// True when this item's [time]..[time]+[durationSec] range overlaps
  /// another item's on the same day — computed by the caller (it has the
  /// full day's list to compare against), this widget only renders it.
  final bool hasOverlap;
}
