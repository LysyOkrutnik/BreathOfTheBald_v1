import 'package:shared_preferences/shared_preferences.dart';

class ChangelogEntry {
  const ChangelogEntry({required this.version, required this.notesPl, required this.notesEn});
  final String version;
  final List<String> notesPl;
  final List<String> notesEn;
}

/// Newest first. Only [changelogEntries].first is ever shown (see
/// [pendingChangelogEntry]) — older entries are kept here purely as a
/// historical record, not something the UI walks through one by one.
const changelogEntries = <ChangelogEntry>[
  ChangelogEntry(
    version: '1.1.0',
    notesPl: [
      'Nowe ćwiczenia mobilności: rozciąganie klatki piersiowej, Uddiyana Bandha, oddychanie z oporem, pełny oddech trzyczęściowy.',
      'Packing w sekcji Freediving, z ostrzeżeniem bezpieczeństwa.',
      'Sugestia poziomu Wim Hof na bazie Twojego Testu PB.',
      'Zgłaszanie problemów i opinii prosto z apki (Ustawienia).',
      'Eksport historii treningowej do CSV (Ustawienia).',
    ],
    notesEn: [
      'New mobility exercises: chest stretch, Uddiyana Bandha, resisted breathing, full three-part breath.',
      'Packing in the Freediving tab, with a safety warning.',
      'Wim Hof level suggestion based on your PB test.',
      'Report problems or feedback right from the app (Settings).',
      'Export your training history as CSV (Settings).',
    ],
  ),
];

const _lastSeenVersionKey = 'changelog_last_seen_version';

/// The newest changelog entry, only if it hasn't already been shown on this
/// device — null once it has. Marks it as seen as a side effect, so this
/// must only be called from the one place that actually shows the dialog.
/// A brand-new install also sees this once (there's no stored "seen"
/// version yet to compare against) — showing a first-launch "what's new"
/// is harmless, and the alternative (a special case for null) would mean
/// existing users updating straight into this version never see the very
/// entry that motivated adding this feature.
Future<ChangelogEntry?> pendingChangelogEntry() async {
  if (changelogEntries.isEmpty) return null;
  final latest = changelogEntries.first;
  final prefs = await SharedPreferences.getInstance();
  final lastSeen = prefs.getString(_lastSeenVersionKey);
  await prefs.setString(_lastSeenVersionKey, latest.version);
  return lastSeen == latest.version ? null : latest;
}
