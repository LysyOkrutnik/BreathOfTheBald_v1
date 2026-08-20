import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/core/sync/auth_service.dart';
import 'package:okrutnik_breath/core/sync/profile_sync_marker.dart';
import 'package:okrutnik_breath/core/sync/sync_api_client.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/logic/providers/settings_provider.dart';
import 'package:okrutnik_breath/logic/services/derived_gamification.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SyncOutcome { success, notLoggedIn, authExpired, network }

class SyncResult {
  const SyncResult(this.outcome, {this.message});
  final SyncOutcome outcome;
  final String? message;
}

/// Pushes the full local dataset, pulls whatever changed since the last
/// sync, and merges the result back into the local database. Sessions and
/// freediving logs are append-only and immutable once logged (barring
/// rpeScore/symptomTag), so re-pushing the full set every time is simple and
/// correct — the server's upsert-by-id is idempotent either way.
///
/// XP/level/streak are deliberately NOT part of this — they're derived
/// state, recomputed from the merged session history by
/// [recomputeDerivedGamificationState] after every successful pull, rather
/// than synced as mutable counters that could drift or double-count.
class SyncService {
  SyncService(this._ref, this._apiClient, this._authService);

  final Ref _ref;
  final SyncApiClient _apiClient;
  final AuthService _authService;

  static const _lastSyncKey = 'sync_last_synced_at';

  Future<DateTime?> get lastSyncedAt async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_lastSyncKey);
    return iso == null ? null : DateTime.tryParse(iso);
  }

  Future<SyncResult> syncNow() async {
    if (!await _authService.isLoggedIn) {
      return const SyncResult(SyncOutcome.notLoggedIn);
    }

    try {
      return await _runSync();
    } on SyncApiException catch (e) {
      if (!e.isAuthError) return SyncResult(SyncOutcome.network, message: e.toString());

      // The token was rejected — try a silent refresh once before giving
      // up. Without this, ANY 401 (an expired 90-day token, or a
      // password-change-triggered revocation) looked identical to a plain
      // network error, and the user was stuck retrying a sync that could
      // never succeed until they happened to log out and back in
      // themselves.
      final refreshedToken = await _apiClient.refreshToken();
      if (refreshedToken == null) {
        await _authService.logout();
        return const SyncResult(SyncOutcome.authExpired);
      }
      await _authService.updateToken(refreshedToken);

      try {
        return await _runSync();
      } on SyncApiException catch (e2) {
        if (e2.isAuthError) {
          await _authService.logout();
          return const SyncResult(SyncOutcome.authExpired);
        }
        return SyncResult(SyncOutcome.network, message: e2.toString());
      } catch (e2) {
        return SyncResult(SyncOutcome.network, message: e2.toString());
      }
    } catch (e) {
      return SyncResult(SyncOutcome.network, message: e.toString());
    }
  }

  Future<SyncResult> _runSync() async {
    await _push();
    await _pullAllPages();
    await _recomputeDerivedGamificationState();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    return const SyncResult(SyncOutcome.success);
  }

  Future<void> _push() async {
    final sessionRepo = _ref.read(sessionRepositoryProvider);
    final freedivingRepo = _ref.read(freedivingRepositoryProvider);
    final presetRepo = _ref.read(customPresetRepositoryProvider);
    final freedivingPresetRepo = _ref.read(customFreedivingRepositoryProvider);
    final wimHofRepo = _ref.read(wimHofRepositoryProvider);

    final sessions = await sessionRepo.getAllSessions();
    final logs = await freedivingRepo.getAllLogsOnce();
    final presets = await presetRepo.getAllIncludingDeleted();
    final freedivingPresets = await freedivingPresetRepo.getAllIncludingDeleted();
    final freedivingProfile = await freedivingRepo.getProfile();
    final wimHofProgress = await wimHofRepo.getProgress();
    final settings = _ref.read(settingsProvider);
    final profileClientUpdatedAt = await ProfileSyncMarker.lastChangedAt();

    final body = {
      'sessions': [
        for (final s in sessions)
          if (s.syncId != null)
            {
              'id': s.syncId,
              'levelKey': s.levelKey,
              'timestamp': s.timestamp.toIso8601String(),
              'durationSec': s.durationSec,
              'rounds': s.rounds,
              'retentionSec': s.retentionSec,
              'rpeScore': s.rpeScore,
              'xpEarned': s.xpEarned,
            },
      ],
      'freedivingLogs': [
        for (final l in logs)
          if (l.syncId != null)
            {
              'id': l.syncId,
              'tableType': l.tableType,
              'pbUsedSec': l.pbUsedSec,
              'roundsJson': l.roundsJson,
              'roundsCompleted': l.roundsCompleted,
              'durationSec': l.durationSec,
              'timestamp': l.timestamp.toIso8601String(),
              'rpeScore': l.rpeScore,
              'symptomTag': l.symptomTag,
            },
      ],
      'customPresets': [
        for (final p in presets)
          if (p.syncId != null)
            {
              'id': p.syncId,
              'name': p.name,
              'inhaleSec': p.inhaleSec,
              'holdInSec': p.holdInSec,
              'exhaleSec': p.exhaleSec,
              'holdOutSec': p.holdOutSec,
              'cycles': p.cycles,
              'rounds': p.rounds,
              'createdAt': p.createdAt.toIso8601String(),
              'deletedAt': p.deletedAt?.toIso8601String(),
            },
      ],
      'customFreedivingPresets': [
        for (final p in freedivingPresets)
          if (p.syncId != null)
            {
              'id': p.syncId,
              'name': p.name,
              'startApneaSec': p.startApneaSec,
              'endApneaSec': p.endApneaSec,
              'startRestSec': p.startRestSec,
              'endRestSec': p.endRestSec,
              'rounds': p.rounds,
              'createdAt': p.createdAt.toIso8601String(),
              'deletedAt': p.deletedAt?.toIso8601String(),
            },
      ],
      'profileState': {
        'verifiedPbSec': freedivingProfile.verifiedPbSec,
        'verifiedPbAt': freedivingProfile.verifiedPbAt?.toIso8601String(),
        'safetyAcknowledgedAt': freedivingProfile.safetyAcknowledgedAt?.toIso8601String(),
        'wimHofCurrentLevelKey': wimHofProgress.currentLevelKey,
        'wimHofCurrentLevelSetAt': wimHofProgress.currentLevelSetAt?.toIso8601String(),
        'availableWeekdaysMask': SettingsNotifier.maskFromWeekdays(settings.availableWeekdays),
        'availableHourStart': settings.availableHourStart,
        'availableHourEnd': settings.availableHourEnd,
        'allowMultiplePerDay': settings.allowMultipleSessionsPerDay,
        'dailyReminderEnabled': settings.dailyReminderEnabled,
        'clientUpdatedAt': profileClientUpdatedAt.toIso8601String(),
      },
    };

    await _apiClient.pushSync(body);
  }

  /// Keeps pulling while the server reports `hasMore` — a user with more
  /// rows than fit in one page would otherwise silently only ever see the
  /// first page's worth on a full (no-`since`) sync. Each page's own max
  /// `updatedAt` becomes the next page's `since`, rather than any single
  /// fixed cursor computed up front.
  Future<void> _pullAllPages() async {
    var since = await lastSyncedAt;
    while (true) {
      final pulled = await _apiClient.pullSync(since: since);
      await _mergePulled(pulled);

      final hasMore = pulled['hasMore'] == true;
      if (!hasMore) return;

      final next = _maxUpdatedAt(pulled);
      // Safety net: without forward progress this would loop forever: bail
      // rather than hang if the server ever reports hasMore with no
      // parseable rows to advance the cursor from.
      if (next == null || (since != null && !next.isAfter(since))) return;
      since = next;
    }
  }

  DateTime? _maxUpdatedAt(Map<String, dynamic> pulled) {
    DateTime? max;
    for (final key in const ['sessions', 'freedivingLogs', 'customPresets', 'customFreedivingPresets']) {
      for (final raw in (pulled[key] as List? ?? const [])) {
        final updatedAtStr = (raw as Map<String, dynamic>)['updatedAt'] as String?;
        final updatedAt = updatedAtStr != null ? DateTime.tryParse(updatedAtStr) : null;
        if (updatedAt != null && (max == null || updatedAt.isAfter(max))) max = updatedAt;
      }
    }
    return max;
  }

  Future<void> _mergePulled(Map<String, dynamic> data) async {
    final sessionRepo = _ref.read(sessionRepositoryProvider);
    final freedivingRepo = _ref.read(freedivingRepositoryProvider);
    final presetRepo = _ref.read(customPresetRepositoryProvider);
    final freedivingPresetRepo = _ref.read(customFreedivingRepositoryProvider);
    final wimHofRepo = _ref.read(wimHofRepositoryProvider);
    final settingsNotifier = _ref.read(settingsProvider.notifier);

    for (final raw in (data['sessions'] as List? ?? const [])) {
      final s = raw as Map<String, dynamic>;
      await sessionRepo.upsertFromSync(
        syncId: s['id'] as String,
        levelKey: s['levelKey'] as String,
        timestamp: DateTime.parse(s['timestamp'] as String),
        durationSec: s['durationSec'] as int,
        rounds: s['rounds'] as int,
        retentionSec: s['retentionSec'] as int,
        xpEarned: s['xpEarned'] as int,
        rpeScore: s['rpeScore'] as int?,
      );
    }

    for (final raw in (data['freedivingLogs'] as List? ?? const [])) {
      final l = raw as Map<String, dynamic>;
      final roundsJson = l['roundsJson'] as String;
      // The server has no roundsPlanned column (it's derivable from the
      // schedule already in roundsJson) — recover it here rather than
      // requiring a field the server never sends.
      final roundsPlanned = (jsonDecode(roundsJson) as List).length;
      await freedivingRepo.upsertFromSync(
        syncId: l['id'] as String,
        tableType: l['tableType'] as String,
        pbUsedSec: l['pbUsedSec'] as int,
        roundsPlanned: roundsPlanned,
        roundsCompleted: l['roundsCompleted'] as int,
        roundsJson: roundsJson,
        durationSec: l['durationSec'] as int,
        timestamp: DateTime.parse(l['timestamp'] as String),
        rpeScore: l['rpeScore'] as int?,
        symptomTag: l['symptomTag'] as String?,
      );
    }

    for (final raw in (data['customPresets'] as List? ?? const [])) {
      final p = raw as Map<String, dynamic>;
      await presetRepo.upsertFromSync(
        syncId: p['id'] as String,
        name: p['name'] as String,
        inhaleSec: p['inhaleSec'] as int,
        holdInSec: p['holdInSec'] as int,
        exhaleSec: p['exhaleSec'] as int,
        holdOutSec: p['holdOutSec'] as int,
        cycles: p['cycles'] as int,
        rounds: p['rounds'] as int,
        createdAt: DateTime.parse(p['createdAt'] as String),
        deletedAt: p['deletedAt'] != null ? DateTime.parse(p['deletedAt'] as String) : null,
      );
    }

    for (final raw in (data['customFreedivingPresets'] as List? ?? const [])) {
      final p = raw as Map<String, dynamic>;
      await freedivingPresetRepo.upsertFromSync(
        syncId: p['id'] as String,
        name: p['name'] as String,
        startApneaSec: p['startApneaSec'] as int,
        endApneaSec: p['endApneaSec'] as int,
        startRestSec: p['startRestSec'] as int,
        endRestSec: p['endRestSec'] as int,
        rounds: p['rounds'] as int,
        createdAt: DateTime.parse(p['createdAt'] as String),
        deletedAt: p['deletedAt'] != null ? DateTime.parse(p['deletedAt'] as String) : null,
      );
    }

    final profileState = data['profileState'] as Map<String, dynamic>?;
    if (profileState != null) {
      await freedivingRepo.applyProfileStateFromSync(
        verifiedPbSec: profileState['verifiedPbSec'] as int?,
        verifiedPbAt: profileState['verifiedPbAt'] != null
            ? DateTime.parse(profileState['verifiedPbAt'] as String)
            : null,
        safetyAcknowledgedAt: profileState['safetyAcknowledgedAt'] != null
            ? DateTime.parse(profileState['safetyAcknowledgedAt'] as String)
            : null,
      );
      final wimHofLevelKey = profileState['wimHofCurrentLevelKey'] as String?;
      if (wimHofLevelKey != null) {
        await wimHofRepo.applyFromSync(
          currentLevelKey: wimHofLevelKey,
          currentLevelSetAt: profileState['wimHofCurrentLevelSetAt'] != null
              ? DateTime.parse(profileState['wimHofCurrentLevelSetAt'] as String)
              : null,
        );
      }
      final weekdaysMask = profileState['availableWeekdaysMask'] as int?;
      if (weekdaysMask != null) {
        await settingsNotifier.applyProfileStateFromSync(
          availableWeekdays: SettingsNotifier.weekdaysFromMask(weekdaysMask),
          availableHourStart: profileState['availableHourStart'] as int? ?? 6,
          availableHourEnd: profileState['availableHourEnd'] as int? ?? 21,
          allowMultipleSessionsPerDay: profileState['allowMultiplePerDay'] as bool? ?? true,
          dailyReminderEnabled: profileState['dailyReminderEnabled'] as bool? ?? false,
        );
      }
    }
  }

  /// XP/level/streak are derived, not synced directly — recomputed here from
  /// the now-merged full session history so sessions logged on another
  /// device count too, exactly as if they'd all happened on this one.
  Future<void> _recomputeDerivedGamificationState() async {
    final sessions = await _ref.read(sessionRepositoryProvider).getAllSessions();
    final derived = DerivedGamificationState.fromSessions(sessions);
    await _ref.read(userProfileRepositoryProvider).updateUserProfile(
          UserProfileCompanion(
            totalXp: Value(derived.totalXp),
            level: Value(derived.level),
            dailyStreak: Value(derived.dailyStreak),
          ),
        );
  }
}
