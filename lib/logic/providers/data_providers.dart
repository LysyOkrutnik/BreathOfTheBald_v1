import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/data/repositories/custom_preset_repository.dart';
import 'package:okrutnik_breath/data/repositories/freediving_repository.dart';
import 'package:okrutnik_breath/data/repositories/planner_repository.dart';
import 'package:okrutnik_breath/data/repositories/session_repository.dart';
import 'package:okrutnik_breath/data/repositories/user_profile_repository.dart';
import 'package:okrutnik_breath/logic/services/gamification_service.dart';

// Database
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  // Release the SQLite connection when the provider is disposed.
  ref.onDispose(db.close);
  return db;
});

// Repositories
final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return UserProfileRepository(db);
});

/// Reactive user profile (level, XP, streak); null until the first session.
final userProfileProvider = StreamProvider<UserProfileData?>((ref) {
  return ref.watch(userProfileRepositoryProvider).watchUserProfileOrNull();
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SessionRepository(db);
});

// Services
final gamificationServiceProvider = Provider<GamificationService>((ref) {
  final repo = ref.watch(userProfileRepositoryProvider);
  return GamificationService(repo);
});

/// Reactive stream of the user's session history, newest first.
final sessionHistoryProvider = StreamProvider<List<Session>>((ref) {
  return ref.watch(sessionRepositoryProvider).watchSessions();
});

final plannerRepositoryProvider = Provider<PlannerRepository>((ref) {
  return PlannerRepository(ref.watch(databaseProvider));
});

/// Reactive stream of all planned sessions, soonest first.
final plannedSessionsProvider = StreamProvider<List<PlannedSession>>((ref) {
  return ref.watch(plannerRepositoryProvider).watchPlans();
});

final customPresetRepositoryProvider = Provider<CustomPresetRepository>((ref) {
  return CustomPresetRepository(ref.watch(databaseProvider));
});

/// Reactive stream of saved custom breathing presets, newest first.
final customPresetsProvider = StreamProvider<List<CustomPreset>>((ref) {
  return ref.watch(customPresetRepositoryProvider).watchPresets();
});

final freedivingRepositoryProvider = Provider<FreedivingRepository>((ref) {
  return FreedivingRepository(ref.watch(databaseProvider));
});

/// Reactive freediving profile (verified/working PBs, safety-consent flag);
/// null only before the very first read (getProfile() lazily creates the row).
final freedivingProfileProvider =
    StreamProvider<FreedivingProfileData?>((ref) {
  return ref.watch(freedivingRepositoryProvider).watchProfile();
});
