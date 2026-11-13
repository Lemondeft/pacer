import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pacer/src/leaderboard/leaderboard_model.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/swr_helper.dart';

/// Offline-first leaderboard repository (DFD process 4.0 LEADERBOARD & PERINGKAT).
class LeaderboardRepository {
  final SupabaseClient? _clientOverride;
  final LocalStore? _storeOverride;

  LeaderboardRepository({SupabaseClient? client, LocalStore? store})
    : _clientOverride = client,
      _storeOverride = store;

  SupabaseClient? get _client => safeSupabaseClient(_clientOverride);
  LocalStore get _store => _storeOverride ?? LocalStore.instance;

  /// Lists leaderboard boards, newest first (offline-first SWR).
  Future<List<Leaderboard>> listLeaderboards({
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final userId = await resolveActiveUserId(client: _client, store: _store);
    if (userId == null) throw StateError('No signed-in user.');
    final c = _client;
    return offlineRead<List<Leaderboard>>(
      store: _store,
      syncKey: 'lb_boards_$userId',
      forceRefresh: forceRefresh,
      hasBackend: c != null && c.auth.currentUser != null,
      staleAfter: const Duration(minutes: 2),
      readLocal: () async {
        final list = await _store.getLeaderboards(userId);
        return list.length <= limit ? list : list.sublist(0, limit);
      },
      fetchRemote: () async {
        final rows = await c!
            .from('leaderboard')
            .select()
            .order('created_at', ascending: false)
            .limit(limit);
        final list = [
          for (final row in rows)
            Leaderboard.fromJson(Map<String, dynamic>.from(row)),
        ];
        await _store.saveLeaderboards(userId, list);
        return list;
      },
      writeLocal: (_) async {},
      isEmpty: (list) => list.isEmpty,
    );
  }

  Future<List<Peringkat>> getPeringkatList(
    String leaderboardId, {
    int limit = 50,
  }) async {
    final c = _client;
    if (c == null) throw StateError('No backend configured.');
    final rows = await c
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

  /// Standings with display names (offline-first SWR).
  Future<List<({Peringkat entry, String nama})>> getPeringkatWithNames(
    String leaderboardId, {
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    final userId = await resolveActiveUserId(client: _client, store: _store);
    if (userId == null) throw StateError('No signed-in user.');
    final c = _client;
    return offlineRead<List<({Peringkat entry, String nama})>>(
      store: _store,
      syncKey: 'lb_entries_${userId}_$leaderboardId',
      forceRefresh: forceRefresh,
      hasBackend: c != null && c.auth.currentUser != null,
      staleAfter: const Duration(minutes: 2),
      readLocal: () async {
        final list = await _store.getLeaderboardEntries(userId, leaderboardId);
        return list.length <= limit ? list : list.sublist(0, limit);
      },
      fetchRemote: () async {
        final rows = await c!
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
        await _store.saveLeaderboardEntries(userId, leaderboardId, list);
        return list;
      },
      writeLocal: (_) async {},
      isEmpty: (list) => list.isEmpty,
    );
  }

  /// User ids inside a leaderboard scope ('team' / 'region' / 'global').
  Future<Set<String>> scopeUserIds(
    String scope, {
    bool forceRefresh = false,
  }) async {
    final userId = await resolveActiveUserId(client: _client, store: _store);
    if (userId == null) throw StateError('No signed-in user.');
    final c = _client;
    return offlineRead<Set<String>>(
      store: _store,
      syncKey: 'lb_scope_${userId}_$scope',
      forceRefresh: forceRefresh,
      hasBackend: c != null && c.auth.currentUser != null,
      staleAfter: const Duration(minutes: 2),
      readLocal: () async =>
          (await _store.getLeaderboardScope(userId, scope)) ?? <String>{},
      fetchRemote: () async {
        final rows = await c!.rpc(
          'leaderboard_scope_user_ids',
          params: {'p_scope': scope},
        );
        final set = {
          for (final r in (rows as List))
            r is String ? r : '${(r as Map).values.first}',
        };
        await _store.saveLeaderboardScope(userId, scope, set);
        return set;
      },
      writeLocal: (_) async {},
      isEmpty: (s) => s.isEmpty,
    );
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

  Future<List<Peringkat>> myPeringkat() async {
    final c = _client;
    if (c == null) throw StateError('No backend configured.');
    final userId = c.auth.currentUser?.id;
    if (userId == null) throw StateError('No signed-in user.');
    final rows = await c
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
