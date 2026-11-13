import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pacer/src/cache/pacer_cache.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/swr_helper.dart';
import 'package:pacer/src/teams/team_model.dart';

/// Offline-first team repository (DFD process 5.0 PACER TEAM).
///
/// Team lists, membership, and rosters use SWR local persistence so previously
/// fetched clubs remain browsable offline. Code-based joins, invite codes, and
/// coach team management remain server-authoritative.
class TeamRepository {
  final SupabaseClient? _clientOverride;
  final LocalStore? _storeOverride;

  TeamRepository({SupabaseClient? client, LocalStore? store})
    : _clientOverride = client,
      _storeOverride = store;

  SupabaseClient? get _client => safeSupabaseClient(_clientOverride);
  LocalStore get _store => _storeOverride ?? LocalStore.instance;

  SupabaseClient _requireClient() {
    final c = _client;
    if (c == null) throw StateError('No backend configured.');
    return c;
  }

  String _requireLiveUserId() {
    final id = _requireClient().auth.currentUser?.id;
    if (id == null) throw StateError('No signed-in user.');
    return id;
  }

  Future<Team> createTeam({
    required String nama,
    double? targetNilai,
    bool isPrivate = true,
  }) async {
    final c = _requireClient();
    final userId = _requireLiveUserId();
    final payload = <String, dynamic>{
      'nama': nama,
      'dibuat_oleh': userId,
      'is_private': isPrivate,
    };
    if (targetNilai != null) payload['target_nilai'] = targetNilai;
    final row = await c.from('teams').insert(payload).select().single();
    final team = Team.fromJson(Map<String, dynamic>.from(row));
    await _store.saveTeams(userId, [team], isMine: true);
    PacerCache.instance.invalidatePrefix('teams_');
    return team;
  }

  Future<Team> updateTeam(
    String id, {
    String? nama,
    double? targetNilai,
  }) async {
    final c = _requireClient();
    final payload = <String, dynamic>{};
    if (nama != null) payload['nama'] = nama;
    if (targetNilai != null) payload['target_nilai'] = targetNilai;
    if (payload.isEmpty) {
      throw ArgumentError('updateTeam needs nama or targetNilai to change.');
    }
    final row = await c
        .from('teams')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    PacerCache.instance.invalidate('team_$id');
    PacerCache.instance.invalidatePrefix('teams_');
    return Team.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteTeam(String id) async {
    await _requireClient().from('teams').delete().eq('id', id);
    PacerCache.instance.invalidate('team_$id');
    PacerCache.instance.invalidatePrefix('teams_');
  }

  /// All teams, newest first (cached locally via SWR for offline browsing).
  Future<List<Team>> listTeams({bool forceRefresh = false}) async {
    final userId = await resolveActiveUserId(client: _client, store: _store);
    if (userId == null) throw StateError('No signed-in user.');
    final c = _client;
    return offlineRead<List<Team>>(
      store: _store,
      syncKey: 'teams_list_$userId',
      forceRefresh: forceRefresh,
      hasBackend: c != null && c.auth.currentUser != null,
      staleAfter: const Duration(minutes: 3),
      readLocal: () => _store.getTeams(userId),
      fetchRemote: () async {
        final rows = await c!
            .from('teams')
            .select()
            .order('created_at', ascending: false);
        final list = [
          for (final row in rows) Team.fromJson(Map<String, dynamic>.from(row)),
        ];
        await _store.saveTeams(userId, list, isMine: false);
        return list;
      },
      writeLocal: (_) async {},
      isEmpty: (list) => list.isEmpty,
    );
  }

  /// One team by id; reads cached snapshot offline.
  Future<Team?> getTeam(String id, {bool forceRefresh = false}) async {
    final userId = await resolveActiveUserId(client: _client, store: _store);
    if (userId == null) throw StateError('No signed-in user.');
    final c = _client;
    return offlineRead<Team?>(
      store: _store,
      syncKey: 'team_${userId}_$id',
      forceRefresh: forceRefresh,
      hasBackend: c != null && c.auth.currentUser != null,
      staleAfter: const Duration(minutes: 3),
      readLocal: () => _store.getTeam(userId, id),
      fetchRemote: () async {
        final row = await c!.from('teams').select().eq('id', id).maybeSingle();
        if (row == null) return null;
        final team = Team.fromJson(Map<String, dynamic>.from(row));
        await _store.saveTeams(userId, [team], isMine: false);
        return team;
      },
      writeLocal: (_) async {},
      isEmpty: (t) => t == null,
    );
  }

  Future<void> joinTeam(String teamId, String code) async {
    await _requireClient().rpc(
      'join_team',
      params: {'p_team_id': teamId, 'p_code': code},
    );
    PacerCache.instance.invalidatePrefix('teams_my_');
  }

  Future<String> joinByCode(String code) async {
    final id = await _requireClient().rpc(
      'join_team_by_code',
      params: {'p_code': code},
    );
    PacerCache.instance.invalidatePrefix('teams_my_');
    return id as String;
  }

  Future<String?> getInviteCode(String teamId) async {
    final code = await _requireClient().rpc(
      'get_team_invite_code',
      params: {'p_team_id': teamId},
    );
    return code as String?;
  }

  Future<String> regenerateInviteCode(String teamId) async {
    final code = await _requireClient().rpc(
      'regenerate_team_invite_code',
      params: {'p_team_id': teamId},
    );
    return code as String;
  }

  Future<void> leaveTeam(String teamId) async {
    await _requireClient()
        .from('team_members')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', _requireLiveUserId());
    PacerCache.instance.invalidatePrefix('teams_my_');
  }

  Future<void> removeMember(String teamId, String userId) async {
    await _requireClient()
        .from('team_members')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', userId);
    PacerCache.instance.invalidatePrefix('teams_my_');
  }

  /// Teams the caller belongs to, newest first (offline-first SWR).
  Future<List<Team>> myTeams({bool forceRefresh = false}) async {
    final userId = await resolveActiveUserId(client: _client, store: _store);
    if (userId == null) throw StateError('No signed-in user.');
    final c = _client;
    return offlineRead<List<Team>>(
      store: _store,
      syncKey: 'teams_my_$userId',
      forceRefresh: forceRefresh,
      hasBackend: c != null && c.auth.currentUser != null,
      staleAfter: const Duration(minutes: 3),
      readLocal: () => _store.getTeams(userId, mineOnly: true),
      fetchRemote: () async {
        final memberRows = await c!
            .from('team_members')
            .select('team_id')
            .eq('user_id', userId);
        final teamIds = [for (final row in memberRows) row['team_id'] as String];
        if (teamIds.isEmpty) {
          await _store.saveTeams(userId, const [], isMine: true);
          return <Team>[];
        }
        final rows = await c
            .from('teams')
            .select()
            .inFilter('id', teamIds)
            .order('created_at', ascending: false);
        final list = [
          for (final row in rows) Team.fromJson(Map<String, dynamic>.from(row)),
        ];
        await _store.saveTeams(userId, list, isMine: true);
        return list;
      },
      writeLocal: (_) async {},
      isEmpty: (list) => list.isEmpty,
    );
  }

  /// Roster with display names + app roles (offline-first SWR).
  Future<List<({String userId, String nama, String peran, String appPeran})>>
  teamRoster(String teamId, {bool forceRefresh = false}) async {
    final ownerId = await resolveActiveUserId(client: _client, store: _store);
    if (ownerId == null) throw StateError('No signed-in user.');
    final c = _client;
    return offlineRead<
      List<({String userId, String nama, String peran, String appPeran})>
    >(
      store: _store,
      syncKey: 'team_roster_${ownerId}_$teamId',
      forceRefresh: forceRefresh,
      hasBackend: c != null && c.auth.currentUser != null,
      staleAfter: const Duration(minutes: 3),
      readLocal: () => _store.getTeamRoster(ownerId, teamId),
      fetchRemote: () async {
        final rows = await c!
            .from('team_members')
            .select('user_id, peran, users!inner(nama,peran)')
            .eq('team_id', teamId)
            .order('created_at', ascending: true);
        final roster = [
          for (final raw in rows)
            () {
              final row = Map<String, dynamic>.from(raw as Map);
              final uid = row['user_id'] as String;
              final nested = row['users'];
              final nestedMap = nested is Map
                  ? nested
                  : (nested is List && nested.isNotEmpty
                        ? (nested.first as Map)
                        : const <String, dynamic>{});
              final nameRaw = nestedMap['nama'];
              final roleRaw = nestedMap['peran'];
              final nama = nameRaw is String && nameRaw.isNotEmpty
                  ? nameRaw
                  : (uid.length > 8 ? '${uid.substring(0, 8)}…' : uid);
              final appPeran = roleRaw is String ? roleRaw : 'user';
              return (
                userId: uid,
                nama: nama,
                peran: row['peran'] as String? ?? 'anggota',
                appPeran: appPeran,
              );
            }(),
        ];
        await _store.saveTeamRoster(ownerId, teamId, roster);
        return roster;
      },
      writeLocal: (_) async {},
      isEmpty: (r) => r.isEmpty,
    );
  }

  Future<List<TeamMember>> teamMembers(String teamId) async {
    final rows = await _requireClient()
        .from('team_members')
        .select()
        .eq('team_id', teamId)
        .order('created_at', ascending: true);
    return [
      for (final row in rows)
        TeamMember.fromJson(Map<String, dynamic>.from(row)),
    ];
  }
}
