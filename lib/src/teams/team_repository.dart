import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pacer/supabase.dart';
import 'package:pacer/src/teams/team_model.dart';

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

  /// Creates a team and returns the mapped row.
  ///
  /// RLS teams_insert gates this to coach/admin (is_coach_or_admin());
  /// regular users get a PostgrestException (42501) from the server.
  Future<Team> createTeam({required String nama, double? targetNilai}) async {
    final payload = <String, dynamic>{'nama': nama};
    if (targetNilai != null) payload['target_nilai'] = targetNilai;
    final row = await _client.from('teams').insert(payload).select().single();
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
    return Team.fromJson(Map<String, dynamic>.from(row));
  }

  /// Deletes a team (its team_members rows cascade in the DB).
  /// RLS teams_write gates this to coach/admin.
  Future<void> deleteTeam(String id) async {
    await _client.from('teams').delete().eq('id', id);
  }

  /// All teams, newest first (created_at desc). Readable by any
  /// authenticated user (teams_select using true).
  Future<List<Team>> listTeams() async {
    final rows = await _client
        .from('teams')
        .select()
        .order('created_at', ascending: false);
    return [
      for (final row in rows) Team.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// One team by id; null when missing.
  Future<Team?> getTeam(String id) async {
    final row = await _client.from('teams').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return Team.fromJson(Map<String, dynamic>.from(row));
  }

  /// Joins the caller to a team: inserts their own team_members row
  /// (RLS members_insert allows user_id = auth.uid()). The DB unique
  /// (team_id, user_id) constraint rejects double joins; peran defaults
  /// to 'anggota' server-side.
  Future<TeamMember> joinTeam(String teamId) async {
    final row = await _client
        .from('team_members')
        .insert({'team_id': teamId, 'user_id': _requireUserId()})
        .select()
        .single();
    return TeamMember.fromJson(Map<String, dynamic>.from(row));
  }

  /// Removes the caller's own membership row (RLS members_delete allows
  /// user_id = auth.uid()).
  Future<void> leaveTeam(String teamId) async {
    await _client
        .from('team_members')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', _requireUserId());
  }

  /// Teams the caller belongs to, newest first. Rpc-free read-then-read:
  /// own team_members rows give the team ids, then teams are fetched.
  Future<List<Team>> myTeams() async {
    final memberRows = await _client
        .from('team_members')
        .select('team_id')
        .eq('user_id', _requireUserId());
    final teamIds = [for (final row in memberRows) row['team_id'] as String];
    if (teamIds.isEmpty) return [];
    final rows = await _client
        .from('teams')
        .select()
        .inFilter('id', teamIds)
        .order('created_at', ascending: false);
    return [
      for (final row in rows) Team.fromJson(Map<String, dynamic>.from(row)),
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
