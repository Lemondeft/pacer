import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pacer/src/cache/pacer_cache.dart';
import 'package:pacer/src/leaderboard/leaderboard_model.dart';
import 'package:pacer/supabase.dart';

/// Backend-only leaderboard reads (DFD process 4.0 LEADERBOARD & PERINGKAT). No widgets.
///
/// RLS: all authenticated users read leaderboard/peringkat; writes are
/// coach/admin only (is_coach_or_admin), so this repository is read-only.
class LeaderboardRepository {
  final SupabaseClient _client;

  LeaderboardRepository({SupabaseClient? client}) : _client = client ?? supa;

  /// Lists leaderboard boards, newest first.
  /// In-memory cached for 2 minutes to keep navigation responsive.
  Future<List<Leaderboard>> listLeaderboards({
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'leaderboard_boards_$limit';
    if (!forceRefresh) {
      final cached = PacerCache.instance.get<List<Leaderboard>>(cacheKey);
      if (cached != null) return cached;
    }
    final rows = await _client
        .from('leaderboard')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    final list = [
      for (final row in rows)
        Leaderboard.fromJson(Map<String, dynamic>.from(row)),
    ];
    PacerCache.instance.set(cacheKey, list, ttl: const Duration(minutes: 2));
    return list;
  }

  /// Standings of one board ordered by nilai desc (best first), capped at [limit].
  Future<List<Peringkat>> getPeringkatList(
    String leaderboardId, {
    int limit = 50,
  }) async {
    final rows = await _client
        .from('peringkat')
        .select()
        .eq('leaderboard_id', leaderboardId)
        .order('nilai', ascending: false)
        .limit(limit);
    return [
      for (final row in rows)
        Peringkat.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Standings with display names via the peringkat→users FK.
  /// Falls back to a shortened user id when the nested row is absent,
  /// so the UI never breaks on join-shape differences.
  /// In-memory cached for 2 minutes.
  Future<List<({Peringkat entry, String nama})>> getPeringkatWithNames(
    String leaderboardId, {
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'leaderboard_peringkat_${leaderboardId}_$limit';
    if (!forceRefresh) {
      final cached =
          PacerCache.instance.get<List<({Peringkat entry, String nama})>>(
            cacheKey,
          );
      if (cached != null) return cached;
    }
    final rows = await _client
        .from('peringkat')
        .select(
          'id, leaderboard_id, user_id, nilai, posisi, updated_at, users!inner(nama)',
        )
        .eq('leaderboard_id', leaderboardId)
        .order('nilai', ascending: false)
        .limit(limit);
    final list = [
      for (final raw in rows)
        () {
          final row = Map<String, dynamic>.from(raw as Map);
          final entry = Peringkat.fromJson(row);
          return (entry: entry, nama: _displayName(row, entry.userId));
        }(),
    ];
    PacerCache.instance.set(cacheKey, list, ttl: const Duration(minutes: 2));
    return list;
  }

  /// User ids inside a leaderboard scope: 'team' (people sharing a team with
  /// the caller), 'region' (same users.region), or 'global' (everyone).
  /// Server-side rpc, so rosters of other teams are never exposed.
  Future<Set<String>> scopeUserIds(
    String scope, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'leaderboard_scope_$scope';
    if (!forceRefresh) {
      final cached = PacerCache.instance.get<Set<String>>(cacheKey);
      if (cached != null) return cached;
    }
    final rows = await _client.rpc(
      'leaderboard_scope_user_ids',
      params: {'p_scope': scope},
    );
    final set = {
      for (final r in (rows as List))
        r is String ? r : '${(r as Map).values.first}',
    };
    PacerCache.instance.set(cacheKey, set, ttl: const Duration(minutes: 2));
    return set;
  }

  String _displayName(Map<String, dynamic> row, String userId) {
    final nested = row['users'];
    final candidate = nested is Map
        ? nested['nama']
        : (nested is List && nested.isNotEmpty
              ? (nested.first as Map)['nama']
              : null);
    if (candidate is String && candidate.isNotEmpty) return candidate;
    return userId.length > 8 ? '${userId.substring(0, 8)}…' : userId;
  }

  /// The caller's own ranked entries across all boards, newest update first.
  Future<List<Peringkat>> myPeringkat() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('No signed-in user.');
    final rows = await _client
        .from('peringkat')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    return [
      for (final row in rows)
        Peringkat.fromJson(Map<String, dynamic>.from(row)),
    ];
  }
}
