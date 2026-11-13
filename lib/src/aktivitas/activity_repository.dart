import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/cache/pacer_cache.dart';
import 'package:pacer/src/local/local_models.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/swr_helper.dart';
import 'package:pacer/src/sync/connectivity_service.dart';

/// Offline-first activity repository (DFD process 2.0 AKTIVITAS & STATISTIK).
///
/// Reads from [LocalStore] as the Single Source of Truth with Stale-While-
/// Revalidate background sync when online; local runs merge seamlessly with
/// pending outbox records so finished offline runs appear immediately everywhere.
class ActivityRepository {
  final SupabaseClient? _clientOverride;
  final LocalStore? _storeOverride;

  ActivityRepository({SupabaseClient? client, LocalStore? store})
    : _clientOverride = client,
      _storeOverride = store;

  SupabaseClient? get _client => safeSupabaseClient(_clientOverride);
  LocalStore get _store => _storeOverride ?? LocalStore.instance;

  Future<String> _requireUserId() async {
    final id = await resolveActiveUserId(client: _client, store: _store);
    if (id == null) throw StateError('No signed-in user.');
    return id;
  }

  /// Starts a workout directly on Supabase (online callers). [RunRecorder]
  /// prefers offline-first draft storage in [LocalStore].
  Future<Activity> createActivity({required String jenis}) async {
    if (!aktivitasJenis.contains(jenis)) {
      throw ArgumentError.value(
        jenis,
        'jenis',
        'must be one of $aktivitasJenis',
      );
    }
    final c = _client;
    if (c == null) throw StateError('No backend configured.');
    final uid = c.auth.currentUser?.id;
    if (uid == null) throw StateError('No signed-in user.');
    final row = await c
        .from('aktivitas')
        .insert({
          'user_id': uid,
          'jenis': jenis,
          'mulai_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();
    return Activity.fromJson(Map<String, dynamic>.from(row));
  }

  /// Batch-inserts GPS points for one aktivitas (unique (aktivitas_id, urutan)).
  Future<void> addRoutePoints(
    String aktivitasId,
    List<RutePoint> points,
  ) async {
    if (points.isEmpty) return;
    for (final point in points) {
      if (!isValidLatLng(point.lat, point.lng)) {
        throw ArgumentError.value(
          point,
          'points',
          'invalid lat/lng at urutan ${point.urutan}',
        );
      }
    }
    final c = _client;
    if (c == null) throw StateError('No backend configured.');
    final rows = <Map<String, dynamic>>[
      for (final point in points)
        {...point.toJson(), 'aktivitas_id': aktivitasId},
    ];
    await c.from('rute_points').upsert(rows, onConflict: 'aktivitas_id,urutan');
  }

  /// Finishes a remote workout directly (online callers).
  Future<Activity> finishActivity(
    String id, {
    double? jarakM,
    int? durasiS,
  }) async {
    if (jarakM != null && jarakM < 0) {
      throw ArgumentError.value(jarakM, 'jarakM', 'must be >= 0');
    }
    if (durasiS != null && durasiS < 0) {
      throw ArgumentError.value(durasiS, 'durasiS', 'must be >= 0');
    }
    final c = _client;
    if (c == null) throw StateError('No backend configured.');
    final row = await c
        .from('aktivitas')
        .select('mulai_at')
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('Aktivitas $id not found or not owned by caller.');
    }
    final mulaiRaw = row['mulai_at'];
    if (mulaiRaw is! String) {
      throw StateError('Aktivitas $id has no mulai_at; it was never started.');
    }
    final selesai = DateTime.now();
    final update = <String, dynamic>{
      'selesai_at': selesai.toUtc().toIso8601String(),
      'durasi_s': durasiS ?? computeDurasiS(DateTime.parse(mulaiRaw), selesai),
    };
    if (jarakM != null) update['jarak_m'] = jarakM;
    final updated = await c
        .from('aktivitas')
        .update(update)
        .eq('id', id)
        .select()
        .single();
    PacerCache.instance.invalidatePrefix('activities_');
    PacerCache.instance.invalidatePrefix('streak_');
    PacerCache.instance.invalidatePrefix('leaderboard_');
    return Activity.fromJson(Map<String, dynamic>.from(updated));
  }

  /// Deletes one aktivitas locally and (when synced) remotely.
  Future<void> deleteActivity(String id) async {
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    await _store.deleteActivityLocal(id);
    if (c != null && uid != null && ConnectivityService.instance.value) {
      try {
        await c.from('aktivitas').delete().eq('id', id).eq('user_id', uid);
      } catch (e) {
        if (!isTransientNetworkError(e)) rethrow;
      }
    }
    PacerCache.instance.invalidatePrefix('activities_');
    PacerCache.instance.invalidatePrefix('streak_');
    PacerCache.instance.invalidatePrefix('leaderboard_');
  }

  /// Returns locally stored finished workouts (synced + pending) with SWR sync.
  Future<List<LocalActivity>> listLocalActivities({
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final userId = await _requireUserId();
    final c = _client;
    return offlineRead<List<LocalActivity>>(
      store: _store,
      syncKey: 'activities_${userId}_$limit',
      forceRefresh: forceRefresh,
      hasBackend: c != null && c.auth.currentUser != null,
      staleAfter: const Duration(minutes: 2),
      readLocal: () => _store.listActivities(userId, limit: limit),
      fetchRemote: () async {
        final rows = await c!
            .from('aktivitas')
            .select()
            .order('mulai_at', ascending: false)
            .limit(limit);
        final list = [
          for (final row in rows)
            Activity.fromJson(Map<String, dynamic>.from(row)),
        ];
        await _store.mergeRemoteActivities(userId, list);
        return _store.listActivities(userId, limit: limit);
      },
      writeLocal: (_) async {
        // Already merged inside fetchRemote before re-reading local pending rows.
      },
      isEmpty: (list) => list.isEmpty,
    );
  }

  /// Riwayat: newest workouts first (synced + local pending), capped at [limit].
  Future<List<Activity>> listActivities({
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final list = await listLocalActivities(
      limit: limit,
      forceRefresh: forceRefresh,
    );
    return [for (final item in list) item.activity];
  }

  /// Coach read: one student's workouts, newest first.
  Future<List<Activity>> listActivitiesFor(
    String userId, {
    int limit = 50,
  }) async {
    final c = _client;
    if (c == null) throw StateError('No backend configured.');
    final rows = await c
        .from('aktivitas')
        .select()
        .eq('user_id', userId)
        .order('mulai_at', ascending: false)
        .limit(limit);
    return [
      for (final row in rows) Activity.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Coach read: one student's streak row (null when never recorded).
  Future<({int berjalan, DateTime? terakhir})?> getStreakFor(
    String userId,
  ) async {
    final c = _client;
    if (c == null) throw StateError('No backend configured.');
    final row = await c
        .from('streak')
        .select('streak_berjalan, terakhir_olahraga_tgl')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    final tglRaw = row['terakhir_olahraga_tgl'] as String?;
    return (
      berjalan: (row['streak_berjalan'] as num?)?.toInt() ?? 0,
      terakhir: tglRaw == null ? null : DateTime.parse(tglRaw),
    );
  }

  /// Coach read: one student's totals for [periode] (null when none yet).
  Future<({double jarakM, int waktuS})?> getStatistikFor(
    String userId,
    String periode,
  ) async {
    final c = _client;
    if (c == null) throw StateError('No backend configured.');
    final row = await c
        .from('statistik')
        .select('total_jarak_m, total_waktu_s')
        .eq('user_id', userId)
        .eq('periode', periode)
        .maybeSingle();
    if (row == null) return null;
    return (
      jarakM: jsonToDouble(row['total_jarak_m']) ?? 0,
      waktuS: (row['total_waktu_s'] as num?)?.toInt() ?? 0,
    );
  }

  /// GPS & rute: offline-first route lookup cached permanently after first read.
  Future<List<RutePoint>> getRoute(
    String aktivitasId, {
    bool forceRefresh = false,
  }) async {
    final c = _client;
    return offlineRead<List<RutePoint>>(
      store: _store,
      syncKey: 'route_$aktivitasId',
      forceRefresh: forceRefresh,
      hasBackend: c != null && c.auth.currentUser != null,
      staleAfter: const Duration(days: 30),
      readLocal: () => _store.getRoutePoints(aktivitasId),
      fetchRemote: () async {
        final rows = await c!
            .from('rute_points')
            .select()
            .eq('aktivitas_id', aktivitasId)
            .order('urutan', ascending: true);
        final list = [
          for (final row in rows)
            RutePoint.fromJson(Map<String, dynamic>.from(row)),
        ];
        await _store.saveRoutePoints(aktivitasId, list);
        return _store.getRoutePoints(aktivitasId);
      },
      writeLocal: (_) async {},
      isEmpty: (pts) => pts.isEmpty,
    );
  }

  /// Effective streak: server baseline + queued offline workout dates.
  Future<({int berjalan, DateTime? terakhir})?> getStreak({
    bool forceRefresh = false,
  }) async {
    final userId = await _requireUserId();
    final c = _client;
    return offlineRead<({int berjalan, DateTime? terakhir})?>(
      store: _store,
      syncKey: 'streak_$userId',
      forceRefresh: forceRefresh,
      hasBackend: c != null && c.auth.currentUser != null,
      staleAfter: const Duration(minutes: 2),
      readLocal: () => _store.getStreakEffective(userId),
      fetchRemote: () async {
        final row = await c!
            .from('streak')
            .select('streak_berjalan, terakhir_olahraga_tgl')
            .eq('user_id', userId)
            .maybeSingle();
        if (row == null) {
          await _store.saveStreakBaseline(userId, 0, null);
        } else {
          final tglRaw = row['terakhir_olahraga_tgl'] as String?;
          await _store.saveStreakBaseline(
            userId,
            (row['streak_berjalan'] as num?)?.toInt() ?? 0,
            tglRaw == null ? null : DateTime.parse(tglRaw),
          );
        }
        return _store.getStreakEffective(userId);
      },
      writeLocal: (_) async {},
      isEmpty: (s) => s == null,
    );
  }

  /// Effective weekly statistics: server baseline + queued offline activities.
  Future<({double jarakM, int waktuS})?> getStatistik(
    String periode, {
    bool forceRefresh = false,
  }) async {
    final userId = await _requireUserId();
    final c = _client;
    return offlineRead<({double jarakM, int waktuS})?>(
      store: _store,
      syncKey: 'stats_${userId}_$periode',
      forceRefresh: forceRefresh,
      hasBackend: c != null && c.auth.currentUser != null,
      staleAfter: const Duration(minutes: 2),
      readLocal: () => _store.getStatistikEffective(userId, periode),
      fetchRemote: () async {
        final row = await c!
            .from('statistik')
            .select('total_jarak_m, total_waktu_s')
            .eq('user_id', userId)
            .eq('periode', periode)
            .maybeSingle();
        if (row == null) {
          await _store.saveStatistikBaseline(userId, periode, 0, 0);
        } else {
          await _store.saveStatistikBaseline(
            userId,
            periode,
            jsonToDouble(row['total_jarak_m']) ?? 0,
            (row['total_waktu_s'] as num?)?.toInt() ?? 0,
          );
        }
        return _store.getStatistikEffective(userId, periode);
      },
      writeLocal: (_) async {},
      isEmpty: (s) => s == null,
    );
  }

  /// Direct remote upsert helper kept for compatibility; [SyncEngine] uses
  /// the idempotent rollup RPC on outbox sync.
  Future<void> upsertStatistik(
    String periode,
    double jarakM,
    int waktuS,
  ) async {
    final c = _client;
    if (c == null) throw StateError('No backend configured.');
    final userId = await _requireUserId();
    final existing = await c
        .from('statistik')
        .select('id, total_jarak_m, total_waktu_s')
        .eq('user_id', userId)
        .eq('periode', periode)
        .maybeSingle();
    if (existing == null) {
      await c.from('statistik').insert({
        'user_id': userId,
        'periode': periode,
        'total_jarak_m': jarakM,
        'total_waktu_s': waktuS,
      });
      return;
    }
    await c
        .from('statistik')
        .update({
          'total_jarak_m':
              (jsonToDouble(existing['total_jarak_m']) ?? 0) + jarakM,
          'total_waktu_s':
              ((existing['total_waktu_s'] as num?)?.toInt() ?? 0) + waktuS,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', existing['id'] as String);
  }

  /// Streak flowchart: same day no change, yesterday +1, gap resets, first ever = 1.
  Future<int> recordStreak(DateTime today) async {
    final c = _client;
    if (c == null) throw StateError('No backend configured.');
    final userId = await _requireUserId();
    final row = await c
        .from('streak')
        .select('streak_berjalan, terakhir_olahraga_tgl')
        .eq('user_id', userId)
        .maybeSingle();
    final terakhirRaw = row?['terakhir_olahraga_tgl'] as String?;
    final next = streakNext(
      terakhirTgl: terakhirRaw == null ? null : DateTime.parse(terakhirRaw),
      today: today,
      current: (row?['streak_berjalan'] as num?)?.toInt() ?? 0,
    );
    final payload = <String, dynamic>{
      'streak_berjalan': next,
      'terakhir_olahraga_tgl': _isoDate(today),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (row == null) {
      await c.from('streak').insert({...payload, 'user_id': userId});
    } else {
      await c.from('streak').update(payload).eq('user_id', userId);
    }
    return next;
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
