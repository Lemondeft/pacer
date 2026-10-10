import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pacer/supabase.dart';
import 'package:pacer/src/aktivitas/activity_model.dart';

/// Backend-only activity tracking (DFD process 2.0 AKTIVITAS & STATISTIK). No widgets.
///
/// Implements the manual flowcharts: tracking olahraga, GPS & rute, riwayat &
/// statistik, streak. Uses the anon-key client from [supa]; RLS keeps rows owner-only.
class ActivityRepository {
  final SupabaseClient _client;

  ActivityRepository({SupabaseClient? client}) : _client = client ?? supa;

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('No signed-in user.');
    return id;
  }

  /// Starts a workout: inserts aktivitas with mulai_at = now and returns the mapped row.
  Future<Activity> createActivity({required String jenis}) async {
    if (!aktivitasJenis.contains(jenis)) {
      throw ArgumentError.value(
        jenis,
        'jenis',
        'must be one of $aktivitasJenis',
      );
    }
    final row = await _client
        .from('aktivitas')
        .insert({
          'user_id': _requireUserId(),
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
    final rows = <Map<String, dynamic>>[
      for (final point in points)
        {...point.toJson(), 'aktivitas_id': aktivitasId},
    ];
    await _client.from('rute_points').insert(rows);
  }

  /// Finishes a workout: reads mulai_at, sets selesai_at = now and durasi_s (>= 0).
  Future<Activity> finishActivity(String id, {double? jarakM}) async {
    if (jarakM != null && jarakM < 0) {
      throw ArgumentError.value(jarakM, 'jarakM', 'must be >= 0');
    }
    final row = await _client
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
      'durasi_s': computeDurasiS(DateTime.parse(mulaiRaw), selesai),
    };
    if (jarakM != null) update['jarak_m'] = jarakM;
    final updated = await _client
        .from('aktivitas')
        .update(update)
        .eq('id', id)
        .select()
        .single();
    return Activity.fromJson(Map<String, dynamic>.from(updated));
  }

  /// Riwayat: newest workouts first (mulai_at desc), capped at [limit].
  Future<List<Activity>> listActivities({int limit = 20}) async {
    final rows = await _client
        .from('aktivitas')
        .select()
        .order('mulai_at', ascending: false)
        .limit(limit);
    return [
      for (final row in rows) Activity.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// GPS & rute: all track points of one aktivitas ordered by urutan asc.
  Future<List<RutePoint>> getRoute(String aktivitasId) async {
    final rows = await _client
        .from('rute_points')
        .select()
        .eq('aktivitas_id', aktivitasId)
        .order('urutan', ascending: true);
    return [
      for (final row in rows)
        RutePoint.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Reads the caller's streak row without writing (null when never recorded).
  /// Unlike [recordStreak], this never touches terakhir_olahraga_tgl.
  Future<({int berjalan, DateTime? terakhir})?> getStreak() async {
    final userId = _requireUserId();
    final row = await _client
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

  /// Reads the caller's statistik totals for [periode] (null when none yet).
  Future<({double jarakM, int waktuS})?> getStatistik(String periode) async {
    final userId = _requireUserId();
    final row = await _client
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

  /// Statistik: rpc-free read-then-write; adds [jarakM]/[waktuS] into [periode] totals.
  Future<void> upsertStatistik(
    String periode,
    double jarakM,
    int waktuS,
  ) async {
    final userId = _requireUserId();
    final existing = await _client
        .from('statistik')
        .select('id, total_jarak_m, total_waktu_s')
        .eq('periode', periode)
        .maybeSingle();
    if (existing == null) {
      await _client.from('statistik').insert({
        'user_id': userId,
        'periode': periode,
        'total_jarak_m': jarakM,
        'total_waktu_s': waktuS,
      });
      return;
    }
    await _client
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
    final userId = _requireUserId();
    final row = await _client
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
      await _client.from('streak').insert({...payload, 'user_id': userId});
    } else {
      await _client.from('streak').update(payload).eq('user_id', userId);
    }
    return next;
  }

  /// Formats a calendar date as YYYY-MM-DD for the streak date column.
  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
