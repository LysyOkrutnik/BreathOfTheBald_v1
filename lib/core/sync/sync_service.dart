import 'dart:convert';
import 'dart:developer' as developer;

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

  /// Called alongside wiping local data on logout/account deletion — without
  /// this, the next login's first pull would start from the old cursor
  /// (whatever this device last synced *as the previous account*) instead
  /// of pulling the new account's full history from scratch.
  Future<void> clearLastSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSyncKey);
  }

  Future<SyncResult> syncNow() async {
    try {
      // Inside the same try as everything else below — `isLoggedIn` reads
      // secure storage, which can throw (a stale/invalidated Keystore entry
      // after an OS update or backup-restore) instead of just returning
      // null. Left uncaught, that exception used to escape syncNow()
      // entirely instead of resolving to a SyncResult like every other
      // failure path here, permanently wedging whatever awaited it.
      if (!await _authService.isLoggedIn) {
        return const SyncResult(SyncOutcome.notLoggedIn);
      }
      return await _runSync();
    } on SyncApiException catch (e) {
      if (!e.isAuthError) return SyncResult(SyncOutcome.network, message: e.toString());

      // The token was rejected — try a silent refresh once before giving
      // up. Without this, ANY 401 (an expired 90-day token, or a
      // password-change-triggered revocation) looked identical to a plain
      // network error, and the user was stuck retrying a sync that could
      // never succeed until they happened to log out and back in
      // themselves.
      // `updateToken` (a secure-storage write) is deliberately inside this
      // same try — it previously sat between the two try/catch blocks,
      // uncaught by either, so a keystore/keychain failure there would
      // propagate out of syncNow() entirely uncaught instead of resolving
      // to a SyncResult like every other failure path here.
      try {
        final refreshedToken = await _apiClient.refreshToken();
        if (refreshedToken == null) {
          await _authService.logout();
          return const SyncResult(SyncOutcome.authExpired);
        }
        await _authService.updateToken(refreshedToken);
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
    final fullyDrained = await _pullAllPages();
    await _recomputeDerivedGamificationState();

    // Only advance the cursor if the pull actually reached the end —
    // otherwise (the pagination cursor stalled; see _pullAllPages) the next
    // sync needs to retry from the *same* `since` rather than resuming past
    // rows it never actually pulled. Re-merging an already-merged page is
    // harmless (idempotent upserts); silently advancing past un-pulled rows
    // was the bug — they'd never be reachable again.
    if (fullyDrained) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    } else {
      // Not an error — the pull cursor stalled on a tied `updatedAt` run
      // (see _pullAllPages) and will retry from the same `since` next time.
      // Logged only so a persistent stall (which would otherwise look like
      // ordinary silent success forever) is at least visible in diagnostics.
      developer.log('Sync cursor stalled — will retry from the same point next sync',
          name: 'SyncService');
    }
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
              'timestamp': s.timestamp.toUtc().toIso8601String(),
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
              'timestamp': l.timestamp.toUtc().toIso8601String(),
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
              'createdAt': p.createdAt.toUtc().toIso8601String(),
              'deletedAt': p.deletedAt?.toUtc().toIso8601String(),
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
              'createdAt': p.createdAt.toUtc().toIso8601String(),
              'deletedAt': p.deletedAt?.toUtc().toIso8601String(),
            },
      ],
      'profileState': {
        'verifiedPbSec': freedivingProfile.verifiedPbSec,
        'verifiedPbAt': freedivingProfile.verifiedPbAt?.toUtc().toIso8601String(),
        'verifiedPbCo2Sec': freedivingProfile.verifiedPbCo2Sec,
        'verifiedPbCo2At': freedivingProfile.verifiedPbCo2At?.toUtc().toIso8601String(),
        'safetyAcknowledgedAt': freedivingProfile.safetyAcknowledgedAt?.toUtc().toIso8601String(),
        'wimHofCurrentLevelKey': wimHofProgress.currentLevelKey,
        'wimHofCurrentLevelSetAt': wimHofProgress.currentLevelSetAt?.toUtc().toIso8601String(),
        'availableWeekdaysMask': SettingsNotifier.maskFromWeekdays(settings.availableWeekdays),
        'availableHourStart': settings.availableHourStart,
        'availableHourEnd': settings.availableHourEnd,
        'allowMultiplePerDay': settings.allowMultipleSessionsPerDay,
        'dailyReminderEnabled': settings.dailyReminderEnabled,
        // `Invalid ISO datetime` from the server — Zod's z.string().datetime()
        // requires a UTC "Z"/offset suffix, which Dart's toIso8601String()
        // omits for a local-time DateTime (the norm here, since these all
        // come from plain DateTime.now() calls). Every push of real data
        // failed this validation until `.toUtc()` was added here and above.
        'clientUpdatedAt': profileClientUpdatedAt.toUtc().toIso8601String(),
      },
    };

    await _apiClient.pushSync(body);
  }

  /// Keeps pulling while the server reports `hasMore` — a user with more
  /// rows than fit in one page would otherwise silently only ever see the
  /// first page's worth on a full (no-`since`) sync. Each page's own max
  /// `updatedAt` becomes the next page's `since`, rather than any single
  /// fixed cursor computed up front.
  ///
  /// Returns `true` only if pulling actually reached the end (`hasMore` went
  /// false). Returns `false` if the cursor stalled — plausible when many
  /// rows share the exact same `updatedAt` (e.g. a bulk migration/backfill)
  /// and a page boundary lands inside that run, so no timestamp in the page
  /// is strictly after the page's own `since`. The caller must NOT advance
  /// `lastSyncedAt` when this returns false, or the un-pulled remainder of
  /// that tied group becomes permanently unreachable (every future sync
  /// would start its cursor past it).
  Future<bool> _pullAllPages() async {
    var since = await lastSyncedAt;
    while (true) {
      final pulled = await _apiClient.pullSync(since: since);
      await _mergePulled(pulled);

      final hasMore = pulled['hasMore'] == true;
      if (!hasMore) return true;

      final next = _maxUpdatedAt(pulled);
      if (next == null || (since != null && !next.isAfter(since))) return false;
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
        verifiedPbCo2Sec: profileState['verifiedPbCo2Sec'] as int?,
        verifiedPbCo2At: profileState['verifiedPbCo2At'] != null
            ? DateTime.parse(profileState['verifiedPbCo2At'] as String)
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
