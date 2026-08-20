import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/logic/providers/sync_providers.dart';

/// A time-boxed community challenge, e.g. "longest streak this month" —
/// mirrors the backend's `Challenge` + this-user's-participation shape from
/// `GET /challenges` (see server/src/routes/challenges.ts).
class Challenge {
  const Challenge({
    required this.id,
    required this.key,
    required this.title,
    required this.description,
    required this.metric,
    required this.startsAt,
    required this.endsAt,
    required this.joined,
  });

  final String id;
  final String key;
  final String title;
  final String description;
  final String metric;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool joined;

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
        id: json['id'] as String,
        key: json['key'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        metric: json['metric'] as String,
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: DateTime.parse(json['endsAt'] as String),
        joined: json['joined'] as bool,
      );
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.value,
  });

  final int rank;
  final String userId;
  final String displayName;
  final int value;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
        rank: json['rank'] as int,
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        value: (json['value'] as num).toInt(),
      );
}

/// `autoDispose` — a leaderboard/challenge list this stale is worse than
/// refetched, and neither is worth keeping alive once the user navigates
/// away from the section that shows them.
final challengesProvider = FutureProvider.autoDispose<List<Challenge>>((ref) async {
  final raw = await ref.watch(syncApiClientProvider).getChallenges();
  return raw.map((e) => Challenge.fromJson(e as Map<String, dynamic>)).toList();
});

final leaderboardProvider =
    FutureProvider.autoDispose.family<List<LeaderboardEntry>, String>((ref, challengeId) async {
  final data = await ref.watch(syncApiClientProvider).getLeaderboard(challengeId);
  return (data['leaderboard'] as List)
      .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Join/leave actions, kept separate from the list provider itself — each
/// invalidates [challengesProvider] so the `joined` flag (and hence the
/// button state) reflects the server's view right after the call succeeds,
/// rather than the UI guessing at optimistic local state.
class ChallengeActions {
  ChallengeActions(this._ref);
  final Ref _ref;

  Future<void> join(String id) async {
    await _ref.read(syncApiClientProvider).joinChallenge(id);
    _ref.invalidate(challengesProvider);
  }

  Future<void> leave(String id) async {
    await _ref.read(syncApiClientProvider).leaveChallenge(id);
    _ref.invalidate(challengesProvider);
  }
}

final challengeActionsProvider = Provider<ChallengeActions>((ref) => ChallengeActions(ref));
