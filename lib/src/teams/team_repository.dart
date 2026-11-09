import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pacer/src/cache/pacer_cache.dart';
import 'package:pacer/src/teams/team_model.dart';
import 'package:pacer/supabase.dart';

/// Backend-only team management (DFD process 5.0 PACER TEAM). No widgets.
///
/// Uses the anon-key client from [supa]. RLS (migration 20261009120000):
/// teams are readable by all authenticated users, but insert/update/delete
/// require is_coach_or_admin(); team_members rows are owned by their user,
/// coach/admin manage all.
class TeamRepository {
  final SupabaseClient _client;

  TeamRepository({SupabaseClient? client}) : _client = client ?? supa;

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('No signed-in user.');
    return id;
  }

  /// Creates a team and returns the mapped row. Records the creator in
  /// dibuat_oleh and joins them, so the team shows in myTeams()/Home
  /// immediately instead of waiting for a manual join.
  ///
  /// RLS teams_insert gates this to coach/admin (is_coach_or_admin());
  /// regular users get a PostgrestException (42501) from the server.
  Future<Team> createTeam({
    required String nama,
    double? targetNilai,
    bool isPrivate = true,
  }) async {
    final userId = _requireUserId();
    final payload = <String, dynamic>{
      'nama': nama,
      'dibuat_oleh': userId,
      'is_private': isPrivate,
    };
    if (targetNilai != null) payload['target_nilai'] = targetNilai;
    final row = await _client.from('teams').insert(payload).select().single();
    // A DB trigger adds the creator as 'ketua' and generates the secret code.
    PacerCache.instance.invalidatePrefix('teams_');
    return Team.fromJson(Map<String, dynamic>.from(row));
  }

  /// Updates nama and/or target_nilai, returns the mapped row.
  /// RLS teams_write gates this to coach/admin.
  Future<Team> updateTeam(
    String id, {
    String? nama,
    double? targetNilai,
  }) async {
    final payload = <String, dynamic>{};
    if (nama != null) payload['nama'] = nama;
    if (targetNilai != null) payload['target_nilai'] = targetNilai;
    if (payload.isEmpty) {
      throw ArgumentError('updateTeam needs nama or targetNilai to change.');
    }
    final row = await _client
        .from('teams')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    PacerCache.instance.invalidate('team_$id');
    PacerCache.instance.invalidatePrefix('teams_');
    return Team.fromJson(Map<String, dynamic>.from(row));
  }

  /// Deletes a team (its team_members rows cascade in the DB).
  /// RLS teams_write gates this to coach/admin.
  Future<void> deleteTeam(String id) async {
    await _client.from('teams').delete().eq('id', id);
    PacerCache.instance.invalidate('team_$id');
    PacerCache.instance.invalidatePrefix('teams_');
  }

  /// All teams, newest first (created_at desc). Readable by any
  /// authenticated user (teams_select using true).
  /// In-memory cached for 3 minutes to avoid redundant DB reads on navigation.
  Future<List<Team>> listTeams({bool forceRefresh = false}) async {
    const cacheKey = 'teams_list';
    if (!forceRefresh) {
      final cached = PacerCache.instance.get<List<Team>>(cacheKey);
      if (cached != null) return cached;
    }
    final rows = await _client
        .from('teams')
        .select()
        .order('created_at', ascending: false);
    final list = [
      for (final row in rows) Team.fromJson(Map<String, dynamic>.from(row)),
    ];
    PacerCache.instance.set(cacheKey, list, ttl: const Duration(minutes: 3));
    return list;
  }

  /// One team by id; null when missing.
  Future<Team?> getTeam(String id, {bool forceRefresh = false}) async {
    final cacheKey = 'team_$id';
    if (!forceRefresh) {
      final cached = PacerCache.instance.get<Team>(cacheKey);
      if (cached != null) return cached;
    }
    final row = await _client.from('teams').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    final team = Team.fromJson(Map<String, dynamic>.from(row));
    PacerCache.instance.set(cacheKey, team, ttl: const Duration(minutes: 3));
    return team;
  }

  /// Joins via invite code through the code-checked join_team() rpc
  /// (server verifies the code; wrong codes raise PostgrestException).
  /// Idempotent: re-joining returns silently. The DB unique
  /// (team_id, user_id) constraint is the backstop.
  Future<void> joinTeam(String teamId, String code) async {
    await _client.rpc(
      'join_team',
      params: {'p_team_id': teamId, 'p_code': code},
    );
    PacerCache.instance.invalidatePrefix('teams_my_');
  }

  /// Joins knowing only the secret code (private teams are not listed).
  /// Returns the joined team id; a wrong code raises PostgrestException.
  Future<String> joinByCode(String code) async {
    final id = await _client.rpc('join_team_by_code', params: {'p_code': code});
    PacerCache.instance.invalidatePrefix('teams_my_');
    return id as String;
  }

  /// The secret invite code. Server returns it only to managers of this
  /// team (admin, creator, ketua, or a coach member); others get a
  /// PostgrestException (42501).
  Future<String?> getInviteCode(String teamId) async {
    final code = await _client.rpc(
      'get_team_invite_code',
      params: {'p_team_id': teamId},
    );
    return code as String?;
  }

  /// Replaces a leaked code. Same permission rule as [getInviteCode].
  Future<String> regenerateInviteCode(String teamId) async {
    final code = await _client.rpc(
      'regenerate_team_invite_code',
      params: {'p_team_id': teamId},
    );
    return code as String;
  }

  /// Removes the caller's own membership row (RLS members_delete allows
  /// user_id = auth.uid()).
  Future<void> leaveTeam(String teamId) async {
    await _client
        .from('team_members')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', _requireUserId());
    PacerCache.instance.invalidatePrefix('teams_my_');
  }

  /// Coach kick: removes any member row. RLS members_delete gates this to
  /// coach/admin; regular users get a 42501 from the server.
  Future<void> removeMember(String teamId, String userId) async {
    await _client
        .from('team_members')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', userId);
    PacerCache.instance.invalidatePrefix('teams_my_');
  }

  /// Teams the caller belongs to, newest first. Rpc-free read-then-read:
  /// own team_members rows give the team ids, then teams are fetched.
  /// In-memory cached for 3 minutes to avoid redundant DB reads on navigation.
  Future<List<Team>> myTeams({bool forceRefresh = false}) async {
    final userId = _requireUserId();
    final cacheKey = 'teams_my_$userId';
    if (!forceRefresh) {
      final cached = PacerCache.instance.get<List<Team>>(cacheKey);
      if (cached != null) return cached;
    }
    final memberRows = await _client
        .from('team_members')
        .select('team_id')
        .eq('user_id', userId);
    final teamIds = [for (final row in memberRows) row['team_id'] as String];
    if (teamIds.isEmpty) {
      PacerCache.instance.set(cacheKey, <Team>[], ttl: const Duration(minutes: 3));
      return [];
    }
    final rows = await _client
        .from('teams')
        .select()
        .inFilter('id', teamIds)
        .order('created_at', ascending: false);
    final list = [
      for (final row in rows) Team.fromJson(Map<String, dynamic>.from(row)),
    ];
    PacerCache.instance.set(cacheKey, list, ttl: const Duration(minutes: 3));
    return list;
  }

  /// Roster with display names + app roles via the team_members→users FK.
  /// Legal under members_select (coach read-all) + users_select (public to
  /// authenticated). Names fall back to shortened ids so UI never breaks.
  /// [appPeran] is the global users.peran (coach/admin/user) for badges;
  /// [peran] stays the in-team role (anggota/ketua).
  Future<List<({String userId, String nama, String peran, String appPeran})>>
  teamRoster(String teamId) async {
    final rows = await _client
        .from('team_members')
        .select('user_id, peran, users!inner(nama,peran)')
        .eq('team_id', teamId)
        .order('created_at', ascending: true);
    return [
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
  }

  /// Members of one team, join order (created_at asc).
  ///
  /// RLS caveat (members_select): regular users only see their OWN
  /// membership rows — for them this returns at most their own row, and an
  /// empty list when they are not a member. Coach/admin see the full roster.
  Future<List<TeamMember>> teamMembers(String teamId) async {
    final rows = await _client
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
