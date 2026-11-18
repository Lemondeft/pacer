import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:pacer/src/cache/pacer_cache.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/swr_helper.dart';
import 'package:pacer/src/notifications/notification_model.dart';
import 'package:pacer/src/notifications/notification_repository.dart';
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

  Future<void> _expireTeamSyncMeta(String userId, {String? teamId}) async {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    await _store.setSyncTimestamp('teams_my_$userId', epoch);
    await _store.setSyncTimestamp('teams_list_$userId', epoch);
    if (teamId != null) {
      await _store.setSyncTimestamp('team_${userId}_$teamId', epoch);
      await _store.setSyncTimestamp('team_roster_${userId}_$teamId', epoch);
    }
  }

  Future<Map<String, int>> _fetchMemberCounts() async {
    final c = _client;
    if (c == null || c.auth.currentUser == null) return const {};
    try {
      final raw = await c.rpc('get_team_member_counts');
      final rows = raw is List ? raw : (raw == null ? const [] : [raw]);
      final counts = <String, int>{};
      for (final item in rows) {
        final row = Map<String, dynamic>.from(item as Map);
        final id = row['team_id'] as String?;
        final n = (row['member_count'] as num?)?.toInt();
        if (id != null && n != null) counts[id] = n;
      }
      return counts;
    } catch (_) {
      return const {};
    }
  }

  List<Team> _mergeCounts(List<Team> teams, Map<String, int> counts) => [
    for (final t in teams)
      counts.containsKey(t.id) ? t.copyWith(memberCount: counts[t.id]) : t,
  ];

  Future<String?> _demoUserId() async {
    final uid = await resolveActiveUserId(client: _client, store: _store);
    return isDemoUserId(uid) ? uid : null;
  }

  Future<Team> createTeam({
    required String nama,
    double? targetNilai,
    bool isPrivate = true,
  }) async {
    final demoUid = await _demoUserId();
    if (demoUid != null) {
      final id = const Uuid().v4();
      final code = id
          .replaceAll('-', '')
          .toUpperCase()
          .padRight(8, 'X')
          .substring(0, 8);
      final team = Team(
        id: id,
        nama: nama,
        targetNilai: targetNilai,
        dibuatOleh: demoUid,
        isPrivate: isPrivate,
        inviteCode: code,
        createdAt: DateTime.now().toUtc(),
        memberCount: 1,
      );
      final prof = await _store.getProfile(demoUid);
      await _store.saveTeams(demoUid, [team], isMine: true);
      await _store.saveTeamRoster(demoUid, team.id, [
        TeamRosterMember(
          userId: demoUid,
          nama: prof?.nama ?? 'andi_wijaya',
          peran: 'ketua',
          appPeran: prof?.peran ?? 'user',
          joinedAt: team.createdAt,
        ),
      ]);
      PacerCache.instance.invalidatePrefix('teams_');
      return team;
    }
    final c = _requireClient();
    final userId = _requireLiveUserId();
    final payload = <String, dynamic>{
      'nama': nama,
      'dibuat_oleh': userId,
      'is_private': isPrivate,
    };
    if (targetNilai != null) payload['target_nilai'] = targetNilai;
    final row = await c.from('teams').insert(payload).select().single();
    final team = Team.fromJson(
      Map<String, dynamic>.from(row),
    ).copyWith(memberCount: 1);
    await _store.saveTeams(userId, [team], isMine: true);
    await _expireTeamSyncMeta(userId, teamId: team.id);
    PacerCache.instance.invalidatePrefix('teams_');
    return team;
  }

  Future<Team> updateTeam(
    String id, {
    String? nama,
    double? targetNilai,
    bool? isPrivate,
  }) async {
    final demoUid = await _demoUserId();
    if (demoUid != null) {
      final existing = await _store.getTeam(demoUid, id);
      if (existing == null) throw StateError('Team not found.');
      final updated = existing.copyWith(
        nama: nama,
        targetNilai: targetNilai,
        isPrivate: isPrivate,
      );
      await _store.saveTeams(demoUid, [updated], isMine: false);
      PacerCache.instance.invalidate('team_$id');
      PacerCache.instance.invalidatePrefix('teams_');
      return updated;
    }
    final c = _requireClient();
    final payload = <String, dynamic>{};
    if (nama != null) payload['nama'] = nama;
    if (targetNilai != null) payload['target_nilai'] = targetNilai;
    if (isPrivate != null) payload['is_private'] = isPrivate;
    if (payload.isEmpty) {
      throw ArgumentError('updateTeam needs at least one field to change.');
    }
    final row = await c
        .from('teams')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    final updated = Team.fromJson(Map<String, dynamic>.from(row));
    final uid = c.auth.currentUser?.id;
    if (uid != null) {
      await _store.saveTeams(uid, [updated], isMine: false);
      await _expireTeamSyncMeta(uid, teamId: id);
    }
    PacerCache.instance.invalidate('team_$id');
    PacerCache.instance.invalidatePrefix('teams_');
    return updated;
  }

  Future<void> deleteTeam(String id) async {
    final demoUid = await _demoUserId();
    if (demoUid != null) {
      await _store.deleteTeamLocal(demoUid, id);
      PacerCache.instance.invalidate('team_$id');
      PacerCache.instance.invalidatePrefix('teams_');
      return;
    }
    final c = _requireClient();
    await c.from('teams').delete().eq('id', id);
    final uid = c.auth.currentUser?.id;
    if (uid != null) {
      await _store.deleteTeamLocal(uid, id);
      await _expireTeamSyncMeta(uid, teamId: id);
    }
    PacerCache.instance.invalidate('team_$id');
    PacerCache.instance.invalidatePrefix('teams_');
  }

  /// All visible teams, newest first (cached locally via SWR for offline browsing).
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
        final countsFuture = _fetchMemberCounts();
        final rows = await c!
            .from('teams')
            .select()
            .order('created_at', ascending: false);
        final counts = await countsFuture;
        final list = _mergeCounts([
          for (final row in rows) Team.fromJson(Map<String, dynamic>.from(row)),
        ], counts);
        await _store.saveTeams(userId, list, isMine: false, replaceAll: true);
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
        final countsFuture = _fetchMemberCounts();
        final row = await c!.from('teams').select().eq('id', id).maybeSingle();
        final counts = await countsFuture;
        if (row == null) return null;
        var team = Team.fromJson(Map<String, dynamic>.from(row));
        if (counts.containsKey(team.id)) {
          team = team.copyWith(memberCount: counts[team.id]);
        }
        await _store.saveTeams(userId, [team], isMine: false);
        return team;
      },
      writeLocal: (_) async {},
      isEmpty: (t) => t == null,
    );
  }

  Future<void> _demoJoinLocal(String uid, Team team) async {
    await _store.setTeamMembershipLocal(
      uid,
      team.id,
      isMine: true,
      memberCountDelta: 1,
    );
    final roster = List<TeamRosterMember>.of(
      await _store.getTeamRoster(uid, team.id),
    );
    if (!roster.any((m) => m.userId == uid)) {
      final prof = await _store.getProfile(uid);
      roster.insert(
        roster.isEmpty ? 0 : 1,
        TeamRosterMember(
          userId: uid,
          nama: prof?.nama ?? 'andi_wijaya',
          peran: team.dibuatOleh == uid ? 'ketua' : 'anggota',
          appPeran: prof?.peran ?? 'user',
          joinedAt: DateTime.now().toUtc(),
        ),
      );
      await _store.saveTeamRoster(uid, team.id, roster);
    }
    PacerCache.instance.invalidatePrefix('teams_my_');
    PacerCache.instance.invalidatePrefix('teams_');
  }

  Future<void> joinTeam(String teamId, String code) async {
    final demoUid = await _demoUserId();
    if (demoUid != null) {
      final team = await _store.getTeam(demoUid, teamId);
      if (team == null) throw StateError('Team not found.');
      if (team.isPrivate &&
          code.trim().toUpperCase() !=
              (team.inviteCode ?? '').trim().toUpperCase()) {
        throw StateError('Invalid invite code.');
      }
      await _demoJoinLocal(demoUid, team);
      return;
    }
    final c = _requireClient();
    await c.rpc(
      'join_team',
      params: {'p_team_id': teamId, 'p_code': code},
    );
    final uid = c.auth.currentUser?.id;
    if (uid != null) {
      await _store.setTeamMembershipLocal(
        uid,
        teamId,
        isMine: true,
        memberCountDelta: 1,
      );
      await _expireTeamSyncMeta(uid, teamId: teamId);
    }
    PacerCache.instance.invalidatePrefix('teams_my_');
    PacerCache.instance.invalidatePrefix('teams_');
  }

  Future<String> joinByCode(String code) async {
    final demoUid = await _demoUserId();
    if (demoUid != null) {
      final normalized = code.trim().toUpperCase();
      final all = await _store.getTeams(demoUid);
      for (final t in all) {
        if ((t.inviteCode ?? '').trim().toUpperCase() == normalized &&
            normalized.isNotEmpty) {
          await _demoJoinLocal(demoUid, t);
          return t.id;
        }
      }
      throw StateError('Invalid invite code.');
    }
    final c = _requireClient();
    final id = await c.rpc(
      'join_team_by_code',
      params: {'p_code': code},
    );
    final teamId = id as String;
    final uid = c.auth.currentUser?.id;
    if (uid != null) {
      await _store.setTeamMembershipLocal(
        uid,
        teamId,
        isMine: true,
        memberCountDelta: 1,
      );
      await _expireTeamSyncMeta(uid, teamId: teamId);
    }
    PacerCache.instance.invalidatePrefix('teams_my_');
    PacerCache.instance.invalidatePrefix('teams_');
    return teamId;
  }

  Future<String?> getInviteCode(String teamId) async {
    final demoUid = await _demoUserId();
    if (demoUid != null) {
      final team = await _store.getTeam(demoUid, teamId);
      if (team == null) return null;
      final mine = await _store.getTeams(demoUid, mineOnly: true);
      final inTeam =
          mine.any((t) => t.id == teamId) || team.dibuatOleh == demoUid;
      return inTeam ? team.inviteCode : null;
    }
    final code = await _requireClient().rpc(
      'get_team_invite_code',
      params: {'p_team_id': teamId},
    );
    return code as String?;
  }

  Future<String> regenerateInviteCode(String teamId) async {
    final demoUid = await _demoUserId();
    if (demoUid != null) {
      final team = await _store.getTeam(demoUid, teamId);
      if (team == null) throw StateError('Team not found.');
      final nextCode = const Uuid()
          .v4()
          .replaceAll('-', '')
          .toUpperCase()
          .substring(0, 8);
      await _store.saveTeams(
        demoUid,
        [team.copyWith(inviteCode: nextCode)],
        isMine: false,
      );
      PacerCache.instance.invalidate('team_$teamId');
      return nextCode;
    }
    final code = await _requireClient().rpc(
      'regenerate_team_invite_code',
      params: {'p_team_id': teamId},
    );
    return code as String;
  }

  Future<void> leaveTeam(String teamId) async {
    final demoUid = await _demoUserId();
    if (demoUid != null) {
      await _store.setTeamMembershipLocal(
        demoUid,
        teamId,
        isMine: false,
        memberCountDelta: -1,
      );
      final roster = [
        for (final m in await _store.getTeamRoster(demoUid, teamId))
          if (m.userId != demoUid) m,
      ];
      await _store.saveTeamRoster(demoUid, teamId, roster);
      PacerCache.instance.invalidatePrefix('teams_my_');
      PacerCache.instance.invalidatePrefix('teams_');
      return;
    }
    final uid = _requireLiveUserId();
    await _requireClient()
        .from('team_members')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', uid);
    await _store.setTeamMembershipLocal(
      uid,
      teamId,
      isMine: false,
      memberCountDelta: -1,
    );
    await _expireTeamSyncMeta(uid, teamId: teamId);
    PacerCache.instance.invalidatePrefix('teams_my_');
    PacerCache.instance.invalidatePrefix('teams_');
  }

  Future<void> removeMember(String teamId, String userId) async {
    final demoUid = await _demoUserId();
    if (demoUid != null) {
      await _store.setTeamMembershipLocal(
        demoUid,
        teamId,
        isMine: demoUid == userId ? false : null,
        memberCountDelta: -1,
      );
      final roster = [
        for (final m in await _store.getTeamRoster(demoUid, teamId))
          if (m.userId != userId) m,
      ];
      await _store.saveTeamRoster(demoUid, teamId, roster);
      PacerCache.instance.invalidatePrefix('teams_my_');
      PacerCache.instance.invalidatePrefix('teams_');
      return;
    }
    final c = _requireClient();
    await c
        .from('team_members')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', userId);
    final callerId = c.auth.currentUser?.id;
    if (callerId != null) {
      await _store.setTeamMembershipLocal(
        callerId,
        teamId,
        isMine: callerId == userId ? false : null,
        memberCountDelta: -1,
      );
      await _expireTeamSyncMeta(callerId, teamId: teamId);
    }
    PacerCache.instance.invalidatePrefix('teams_my_');
    PacerCache.instance.invalidatePrefix('teams_');
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
        final countsFuture = _fetchMemberCounts();
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
        final counts = await countsFuture;
        final list = _mergeCounts([
          for (final row in rows) Team.fromJson(Map<String, dynamic>.from(row)),
        ], counts);
        await _store.saveTeams(userId, list, isMine: true);
        return list;
      },
      writeLocal: (_) async {},
      isEmpty: (list) => list.isEmpty,
    );
  }

  /// Roster with display names, roles, and join date (offline-first SWR).
  Future<List<TeamRosterMember>> teamRoster(
    String teamId, {
    bool forceRefresh = false,
  }) async {
    final ownerId = await resolveActiveUserId(client: _client, store: _store);
    if (ownerId == null) throw StateError('No signed-in user.');
    final c = _client;
    return offlineRead<List<TeamRosterMember>>(
      store: _store,
      syncKey: 'team_roster_${ownerId}_$teamId',
      forceRefresh: forceRefresh,
      hasBackend: c != null && c.auth.currentUser != null,
      staleAfter: const Duration(minutes: 3),
      readLocal: () => _store.getTeamRoster(ownerId, teamId),
      fetchRemote: () async {
        List<TeamRosterMember> roster;
        try {
          final raw = await c!.rpc(
            'get_team_roster',
            params: {'p_team_id': teamId},
          );
          final rows = raw is List ? raw : (raw == null ? const [] : [raw]);
          roster = [
            for (final item in rows)
              () {
                final m = TeamRosterMember.fromJson(
                  Map<String, dynamic>.from(item as Map),
                );
                if (m.nama.isNotEmpty) return m;
                final fallback = m.userId.length > 8
                    ? '${m.userId.substring(0, 8)}…'
                    : m.userId;
                return TeamRosterMember(
                  userId: m.userId,
                  nama: fallback,
                  peran: m.peran,
                  appPeran: m.appPeran,
                  joinedAt: m.joinedAt,
                );
              }(),
          ];
        } on PostgrestException catch (e) {
          final code = (e.code ?? '').toUpperCase();
          if (code != 'PGRST202' && code != '42883') rethrow;
          final rows = await c!
              .from('team_members')
              .select('user_id, peran, created_at, users!inner(nama,peran)')
              .eq('team_id', teamId)
              .order('created_at', ascending: true);
          roster = [
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
                final joinedRaw = row['created_at'] as String?;
                return TeamRosterMember(
                  userId: uid,
                  nama: nama,
                  peran: row['peran'] as String? ?? 'anggota',
                  appPeran: appPeran,
                  joinedAt:
                      joinedRaw == null ? null : DateTime.tryParse(joinedRaw),
                );
              }(),
          ];
        }
        await _store.saveTeamRoster(ownerId, teamId, roster);
        return roster;
      },
      writeLocal: (_) async {},
      isEmpty: (r) => r.isEmpty,
    );
  }

  /// Aggregate weekly/total stats + membership flags for the Teams Dashboard.
  Future<TeamDashboardStats?> getTeamDashboardStats(String teamId) async {
    final demoUid = await _demoUserId();
    if (demoUid != null) {
      final team = await _store.getTeam(demoUid, teamId);
      final mine = await _store.getTeams(demoUid, mineOnly: true);
      final roster = await _store.getTeamRoster(demoUid, teamId);
      final isMember = mine.any((t) => t.id == teamId);
      final me = roster.cast<TeamRosterMember?>().firstWhere(
        (m) => m?.userId == demoUid,
        orElse: () => null,
      );
      final count = team?.memberCount ?? roster.length;
      final canManage =
          team?.dibuatOleh == demoUid || me?.peran == 'ketua';
      return TeamDashboardStats(
        memberCount: count,
        activeMembersWeek:
            count == 0 ? 0 : (count * 0.65).round().clamp(1, count),
        totalWeekSessions: count * 2,
        totalWeekKm: double.parse((count * 5.8).toStringAsFixed(1)),
        totalAllKm: double.parse((count * 24.5).toStringAsFixed(1)),
        isMember: isMember,
        canViewCode: isMember || team?.dibuatOleh == demoUid,
        canManageCode: canManage,
      );
    }
    final c = _client;
    if (c == null || c.auth.currentUser == null) return null;
    try {
      final raw = await c.rpc(
        'get_team_dashboard_stats',
        params: {'p_team_id': teamId},
      );
      final rows = raw is List ? raw : (raw == null ? const [] : [raw]);
      if (rows.isEmpty || rows.first == null) return null;
      return TeamDashboardStats.fromJson(
        Map<String, dynamic>.from(rows.first as Map),
      );
    } on PostgrestException catch (e) {
      final code = (e.code ?? '').toUpperCase();
      if (code == 'PGRST202' || code == '42883') return null;
      rethrow;
    } catch (_) {
      return null;
    }
  }

  /// Promotes or demotes a team member between `'ketua'` and `'anggota'`.
  Future<void> setMemberRole({
    required String teamId,
    required String userId,
    required String peran,
  }) async {
    final demoUid = await _demoUserId();
    if (demoUid != null) {
      final roster = await _store.getTeamRoster(demoUid, teamId);
      final updated = [
        for (final m in roster)
          if (m.userId == userId)
            TeamRosterMember(
              userId: m.userId,
              nama: m.nama,
              peran: peran,
              appPeran: m.appPeran,
              joinedAt: m.joinedAt,
            )
          else
            m,
      ];
      await _store.saveTeamRoster(demoUid, teamId, updated);
      if (userId == demoUid) {
        final team = await _store.getTeam(demoUid, teamId);
        final existingNotifs = await _store.getNotifications(demoUid);
        await _store.saveNotifications(demoUid, [
          AppNotification(
            id: const Uuid().v4(),
            userId: demoUid,
            type: 'team_role_changed',
            title: team?.nama ?? 'Tim Pacer',
            body: peran == 'ketua'
                ? 'Anda ditunjuk menjadi Ketua Tim.'
                : 'Peran Anda di tim diperbarui menjadi Anggota.',
            teamId: teamId,
            createdAt: DateTime.now().toUtc(),
          ),
          ...existingNotifs,
        ]);
        NotificationRepository.unreadCountNotifier.value =
            (await _store.getNotifications(demoUid))
                .where((n) => !n.isRead)
                .length;
        NotificationRepository.revisionNotifier.value++;
      }
      PacerCache.instance.invalidatePrefix('teams_my_');
      PacerCache.instance.invalidatePrefix('teams_');
      return;
    }
    final c = _requireClient();
    await c.rpc(
      'set_team_member_role',
      params: {
        'p_team_id': teamId,
        'p_user_id': userId,
        'p_peran': peran,
      },
    );
    final callerId = c.auth.currentUser?.id;
    if (callerId != null) {
      await _expireTeamSyncMeta(callerId, teamId: teamId);
    }
    PacerCache.instance.invalidatePrefix('teams_my_');
    PacerCache.instance.invalidatePrefix('teams_');
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
