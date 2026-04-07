import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/data/db/database.dart';
import 'package:okrutnik_breath/data/repositories/user_profile_repository.dart';
import 'package:okrutnik_breath/logic/services/gamification_service.dart';

// Database
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

// Repositories
final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return UserProfileRepository(db);
});

// Services
final gamificationServiceProvider = Provider<GamificationService>((ref) {
  final repo = ref.watch(userProfileRepositoryProvider);
  return GamificationService(repo);
});

