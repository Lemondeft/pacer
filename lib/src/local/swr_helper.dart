import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/sync/connectivity_service.dart';
import 'package:pacer/supabase.dart';

/// Returns [override] or global [supa] when initialized; `null` in demo/test
/// environments where Supabase was never configured.
SupabaseClient? safeSupabaseClient([SupabaseClient? override]) {
  if (override != null) return override;
  try {
    return supa;
  } catch (_) {
    return null;
  }
}

/// Resolves the active user id from live auth session or last offline session.
Future<String?> resolveActiveUserId({
  SupabaseClient? client,
  LocalStore? store,
}) async {
  final live = safeSupabaseClient(client)?.auth.currentUser?.id;
  if (live != null) return live;
  return (store ?? LocalStore.instance).getLastUserId();
}

/// True when neither a live session nor a cached offline user session exists,
/// meaning the app is running in Demo Mode and may render sample data.
Future<bool> isDemoAccount({
  SupabaseClient? client,
  LocalStore? store,
}) async => (await resolveActiveUserId(client: client, store: store)) == null;

/// Stale-While-Revalidate reader shared across repositories:
/// - Returns persisted local data immediately when present (or previously synced).
/// - Refreshes in the background when online and older than [staleAfter].
/// - Falls back cleanly to local data on transient network/offline failures.
Future<T> offlineRead<T>({
  required LocalStore store,
  required String syncKey,
  required Future<T> Function() readLocal,
  required Future<T> Function() fetchRemote,
  required Future<void> Function(T remote) writeLocal,
  bool Function(T value)? isEmpty,
  bool forceRefresh = false,
  Duration staleAfter = const Duration(minutes: 2),
  bool hasBackend = true,
}) async {
  final emptyCheck = isEmpty ?? _defaultIsEmpty;

  Future<T> refreshAndSave() async {
    final remote = await fetchRemote();
    ConnectivityService.instance.reportReachable(true);
    await writeLocal(remote);
    await store.setSyncTimestamp(syncKey, DateTime.now().toUtc());
    return remote;
  }

  if (forceRefresh && hasBackend) {
    try {
      return await refreshAndSave();
    } catch (e) {
      if (isTransientNetworkError(e) || !ConnectivityService.instance.value) {
        ConnectivityService.instance.reportReachable(false);
        return readLocal();
      }
      if (isAuthSessionError(e) && !ConnectivityService.instance.value) {
        return readLocal();
      }
      rethrow;
    }
  }

  final local = await readLocal();
  final lastSync = await store.getSyncTimestamp(syncKey);
  final hasCachedState = lastSync != null || !emptyCheck(local);

  if (!hasBackend) return local;

  if (hasCachedState) {
    final isStale =
        lastSync == null ||
        DateTime.now().toUtc().difference(lastSync) > staleAfter;
    if (isStale && ConnectivityService.instance.value) {
      unawaited(() async {
        try {
          await refreshAndSave();
        } catch (e) {
          if (isTransientNetworkError(e)) {
            ConnectivityService.instance.reportReachable(false);
          }
        }
      }());
    }
    return local;
  }

  if (!ConnectivityService.instance.value) {
    return local;
  }

  try {
    return await refreshAndSave();
  } catch (e) {
    if (isTransientNetworkError(e)) {
      ConnectivityService.instance.reportReachable(false);
      return local;
    }
    if (isAuthSessionError(e)) {
      return local;
    }
    rethrow;
  }
}

bool _defaultIsEmpty(dynamic value) {
  if (value == null) return true;
  if (value is Iterable) return value.isEmpty;
  if (value is Map) return value.isEmpty;
  return false;
}
