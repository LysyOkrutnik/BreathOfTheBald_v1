import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/core/sync/auth_service.dart';
import 'package:okrutnik_breath/core/sync/sync_api_client.dart';
import 'package:okrutnik_breath/core/sync/sync_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final syncApiClientProvider = Provider<SyncApiClient>((ref) {
  return SyncApiClient(ref.watch(authServiceProvider));
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref, ref.watch(syncApiClientProvider), ref.watch(authServiceProvider));
});
