import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/auth/user_model.dart';
import 'package:pacer/src/challenge/challenge_model.dart';
import 'package:pacer/src/chat/chat_model.dart';
import 'package:pacer/src/leaderboard/leaderboard_model.dart';
import 'package:pacer/src/local/local_helpers.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/notifications/notification_model.dart';
import 'package:pacer/src/teams/team_model.dart';

/// Comprehensive in-app dummy data for demo, offline, and preview modes.
class PacerDummyData {
  PacerDummyData._();

  static const String demoUserId = 'demo-user-me';

  static final DateTime _now = DateTime.now();

  /// 12 realistic past activities covering all 4 sport types:
  /// 'lari', 'joging', 'bersepeda', 'berjalan'
  static final List<Activity> activities = [
    Activity(
      id: 'demo-act-001',
      userId: 'demo-user-me',
      jenis: 'lari',
      mulaiAt: _now.subtract(const Duration(hours: 4)),
      selesaiAt: _now.subtract(const Duration(hours: 3, minutes: 31)),
      durasiS: 1740, // 29m 00s
      jarakM: 5200, // 5.2 km
    ),
    Activity(
      id: 'demo-act-002',
      userId: 'demo-user-me',
      jenis: 'joging',
      mulaiAt: _now.subtract(const Duration(days: 1, hours: 2)),
      selesaiAt: _now.subtract(const Duration(days: 1, hours: 1, minutes: 35)),
      durasiS: 1500, // 25m 00s
      jarakM: 3800, // 3.8 km
    ),
    Activity(
      id: 'demo-act-003',
      userId: 'demo-user-me',
      jenis: 'bersepeda',
      mulaiAt: _now.subtract(const Duration(days: 2, hours: 5)),
      selesaiAt: _now.subtract(const Duration(days: 2, hours: 4, minutes: 10)),
      durasiS: 3000, // 50m 00s
      jarakM: 21500, // 21.5 km
    ),
    Activity(
      id: 'demo-act-004',
      userId: 'demo-user-me',
      jenis: 'berjalan',
      mulaiAt: _now.subtract(const Duration(days: 3, hours: 1)),
      selesaiAt: _now.subtract(const Duration(days: 3, minutes: 25)),
      durasiS: 2100, // 35m 00s
      jarakM: 3200, // 3.2 km
    ),
    Activity(
      id: 'demo-act-005',
      userId: 'demo-user-me',
      jenis: 'lari',
      mulaiAt: _now.subtract(const Duration(days: 4, hours: 3)),
      selesaiAt: _now.subtract(const Duration(days: 4, hours: 2, minutes: 5)),
      durasiS: 3300, // 55m 00s
      jarakM: 10050, // 10.05 km
    ),
    Activity(
      id: 'demo-act-006',
      userId: 'demo-user-me',
      jenis: 'joging',
      mulaiAt: _now.subtract(const Duration(days: 5, hours: 4)),
      selesaiAt: _now.subtract(const Duration(days: 5, hours: 3, minutes: 30)),
      durasiS: 1800, // 30m 00s
      jarakM: 4500, // 4.5 km
    ),
    Activity(
      id: 'demo-act-007',
      userId: 'demo-user-me',
      jenis: 'bersepeda',
      mulaiAt: _now.subtract(const Duration(days: 6, hours: 6)),
      selesaiAt: _now.subtract(const Duration(days: 6, hours: 4, minutes: 40)),
      durasiS: 4800, // 1h 20m
      jarakM: 35000, // 35 km
    ),
    Activity(
      id: 'demo-act-008',
      userId: 'demo-user-me',
      jenis: 'berjalan',
      mulaiAt: _now.subtract(const Duration(days: 7, hours: 2)),
      selesaiAt: _now.subtract(const Duration(days: 7, hours: 1, minutes: 15)),
      durasiS: 2700, // 45m 00s
      jarakM: 4100, // 4.1 km
    ),
    Activity(
      id: 'demo-act-009',
      userId: 'demo-user-me',
      jenis: 'lari',
      mulaiAt: _now.subtract(const Duration(days: 8, hours: 5)),
      selesaiAt: _now.subtract(const Duration(days: 8, hours: 4, minutes: 38)),
      durasiS: 1320, // 22m 00s
      jarakM: 4200, // 4.2 km
    ),
    Activity(
      id: 'demo-act-010',
      userId: 'demo-user-me',
      jenis: 'joging',
      mulaiAt: _now.subtract(const Duration(days: 9, hours: 3)),
      selesaiAt: _now.subtract(const Duration(days: 9, hours: 2, minutes: 35)),
      durasiS: 1500, // 25m 00s
      jarakM: 3600, // 3.6 km
    ),
  ];

  /// 6 active clubs with invite codes & targets
  static final List<Team> teams = [
    Team(
      id: '11111111-1111-1111-1111-111111111111',
      nama: 'GBK Runners Elite',
      targetNilai: 120000,
      dibuatOleh: 'demo-coach',
      isPrivate: false,
      inviteCode: 'GBKELITE',
      createdAt: _now.subtract(const Duration(days: 30)),
      memberCount: 18,
    ),
    Team(
      id: '22222222-2222-2222-2222-222222222222',
      nama: 'XI IPA 1 - SMAN 1',
      targetNilai: 100000,
      dibuatOleh: 'demo-coach',
      isPrivate: true,
      inviteCode: 'IPA1RUNS',
      createdAt: _now.subtract(const Duration(days: 25)),
      memberCount: 24,
    ),
    Team(
      id: '33333333-3333-3333-3333-333333333333',
      nama: 'JakBar Pacer Community',
      targetNilai: 75000,
      dibuatOleh: 'demo-user-0',
      isPrivate: true,
      inviteCode: 'JAKBAR01',
      createdAt: _now.subtract(const Duration(days: 20)),
      memberCount: 14,
    ),
    Team(
      id: '44444444-4444-4444-4444-444444444444',
      nama: 'Monas Morning Joggers',
      targetNilai: 60000,
      dibuatOleh: 'demo-user-1',
      isPrivate: false,
      inviteCode: 'MONASRUN',
      createdAt: _now.subtract(const Duration(days: 15)),
      memberCount: 11,
    ),
    Team(
      id: '55555555-5555-5555-5555-555555555555',
      nama: 'Sudirman Night Cyclists',
      targetNilai: 200000,
      dibuatOleh: 'demo-user-4',
      isPrivate: false,
      inviteCode: 'SUDIRCYC',
      createdAt: _now.subtract(const Duration(days: 10)),
      memberCount: 16,
    ),
    Team(
      id: '66666666-6666-6666-6666-666666666666',
      nama: 'Jakarta Strollers 10K',
      targetNilai: 50000,
      dibuatOleh: 'demo-user-6',
      isPrivate: false,
      inviteCode: 'JKTWALKS',
      createdAt: _now.subtract(const Duration(days: 5)),
      memberCount: 9,
    ),
  ];

  static const Set<String> _initialDemoJoinedIds = {
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
  };
  static final Set<String> _demoJoinedIds = {..._initialDemoJoinedIds};
  static final List<Team> _customDemoTeams = [];
  static final Map<String, int> _demoCountOffsets = {};
  static final Map<String, String> _demoInviteOverrides = {};
  static final Set<String> _demoRemovedMembers = {};
  static final Map<String, String> _demoMemberRoleOverrides = {};
  static final List<Activity> _customDemoActivities = [];
  static final List<Challenge> _customDemoChallenges = [];
  static Map<String, PartisipasiChallenge>? _demoParticipationsState;
  static List<AppNotification>? _demoNotificationsState;

  static List<Activity> get demoActivities => [
    ..._customDemoActivities,
    ...activities,
  ];

  static void recordDemoActivity(Activity activity) {
    _customDemoActivities.removeWhere((a) => a.id == activity.id);
    _customDemoActivities.insert(0, activity);
    recordDemoActivityProgress(activity);
  }

  static void resetDemoTeams() {
    _demoJoinedIds
      ..clear()
      ..addAll(_initialDemoJoinedIds);
    _customDemoTeams.clear();
    _demoCountOffsets.clear();
    _demoInviteOverrides.clear();
    _demoRemovedMembers.clear();
    _demoMemberRoleOverrides.clear();
    _customDemoActivities.clear();
    _customDemoChallenges.clear();
    _demoParticipationsState = null;
    _demoNotificationsState = null;
  }

  static List<Team> get demoTeams {
    final combined = [..._customDemoTeams, ...teams];
    return [
      for (final t in combined)
        t.copyWith(
          inviteCode: _demoInviteOverrides[t.id] ?? t.inviteCode,
          memberCount: ((t.memberCount ?? 0) + (_demoCountOffsets[t.id] ?? 0))
              .clamp(0, 1000000),
        ),
    ];
  }

  static List<Team> get demoMyTeams =>
      demoTeams.where((t) => _demoJoinedIds.contains(t.id)).toList();

  static bool isDemoTeamJoined(String teamId) =>
      _demoJoinedIds.contains(teamId);

  static bool joinDemoTeam(String teamId, {String? code}) {
    final team = demoTeams.cast<Team?>().firstWhere(
      (t) => t?.id == teamId,
      orElse: () => null,
    );
    if (team == null) return false;
    if (team.isPrivate) {
      final expected = (team.inviteCode ?? '').toUpperCase();
      if ((code ?? '').trim().toUpperCase() != expected) {
        return false;
      }
    }
    if (_demoJoinedIds.add(teamId)) {
      _demoCountOffsets[teamId] = (_demoCountOffsets[teamId] ?? 0) + 1;
    }
    return true;
  }

  static Team? joinDemoByCode(String code) {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    for (final t in demoTeams) {
      if ((t.inviteCode ?? '').toUpperCase() == normalized) {
        if (_demoJoinedIds.add(t.id)) {
          _demoCountOffsets[t.id] = (_demoCountOffsets[t.id] ?? 0) + 1;
        }
        return demoTeams.firstWhere((e) => e.id == t.id);
      }
    }
    return null;
  }

  static void leaveDemoTeam(String teamId) {
    if (_demoJoinedIds.remove(teamId)) {
      _demoCountOffsets[teamId] = (_demoCountOffsets[teamId] ?? 0) - 1;
    }
  }

  static Team createDemoTeam(
    String nama, {
    required bool isPrivate,
    double? targetNilai,
  }) {
    final id = 'demo-team-${DateTime.now().microsecondsSinceEpoch}';
    final cleaned = id.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();
    final code = cleaned.padRight(8, 'X').substring(0, 8);
    final team = Team(
      id: id,
      nama: nama,
      targetNilai: targetNilai,
      dibuatOleh: 'demo-user-me',
      isPrivate: isPrivate,
      inviteCode: code,
      createdAt: DateTime.now(),
      memberCount: 1,
    );
    _customDemoTeams.insert(0, team);
    _demoJoinedIds.add(id);
    return team;
  }

  static String? getDemoInviteCode(String teamId) {
    final team = demoTeams.cast<Team?>().firstWhere(
      (t) => t?.id == teamId,
      orElse: () => null,
    );
    if (team == null) return null;
    final inTeam = _demoJoinedIds.contains(teamId) ||
        team.dibuatOleh == 'demo-user-me';
    // Private team invite codes are strictly hidden unless creator or in the team.
    if (team.isPrivate && !inTeam) return null;
    if (!inTeam) return null;
    return _demoInviteOverrides[teamId] ?? team.inviteCode;
  }

  static String? regenerateDemoInviteCode(String teamId) {
    final team = demoTeams.cast<Team?>().firstWhere(
      (t) => t?.id == teamId,
      orElse: () => null,
    );
    if (team == null) return null;
    final code = DateTime.now()
        .microsecondsSinceEpoch
        .toRadixString(36)
        .toUpperCase()
        .padLeft(8, 'P')
        .substring(0, 8);
    _demoInviteOverrides[teamId] = code;
    return code;
  }

  static List<TeamRosterMember> getTeamRoster(String teamId) {
    final team = demoTeams.cast<Team?>().firstWhere(
      (t) => t?.id == teamId,
      orElse: () => null,
    );
    if (team == null) return const [];
    final joined = _demoJoinedIds.contains(teamId);
    if (team.isPrivate && !joined) return const [];

    if (_customDemoTeams.any((t) => t.id == teamId)) {
      return [
        TeamRosterMember(
          userId: 'demo-user-me',
          nama: 'andi_wijaya',
          peran: 'ketua',
          appPeran: 'user',
          joinedAt: team.createdAt,
        ),
      ];
    }

    final baseMembers = <TeamRosterMember>[
      TeamRosterMember(
        userId: 'demo-coach',
        nama: 'coach_hendra',
        peran: 'ketua',
        appPeran: 'coach',
        joinedAt: _now.subtract(const Duration(days: 28)),
      ),
      TeamRosterMember(
        userId: 'demo-user-0',
        nama: 'budi_santoso',
        peran: 'anggota',
        appPeran: 'user',
        joinedAt: _now.subtract(const Duration(days: 24)),
      ),
      TeamRosterMember(
        userId: 'demo-user-1',
        nama: 'siti_rahma',
        peran: 'anggota',
        appPeran: 'user',
        joinedAt: _now.subtract(const Duration(days: 20)),
      ),
      TeamRosterMember(
        userId: 'demo-user-3',
        nama: 'dewi_lestari',
        peran: 'anggota',
        appPeran: 'user',
        joinedAt: _now.subtract(const Duration(days: 15)),
      ),
      TeamRosterMember(
        userId: 'demo-user-4',
        nama: 'rizky_pratama',
        peran: 'anggota',
        appPeran: 'user',
        joinedAt: _now.subtract(const Duration(days: 10)),
      ),
      TeamRosterMember(
        userId: 'demo-user-5',
        nama: 'farhan_ramadhan',
        peran: 'anggota',
        appPeran: 'user',
        joinedAt: _now.subtract(const Duration(days: 6)),
      ),
    ];

    final list = [
      for (final m in baseMembers)
        if (!_demoRemovedMembers.contains('${teamId}_${m.userId}'))
          TeamRosterMember(
            userId: m.userId,
            nama: m.nama,
            peran: _demoMemberRoleOverrides['${teamId}_${m.userId}'] ?? m.peran,
            appPeran: m.appPeran,
            joinedAt: m.joinedAt,
          ),
    ];
    if (joined && !list.any((m) => m.userId == 'demo-user-me')) {
      list.insert(
        1,
        TeamRosterMember(
          userId: 'demo-user-me',
          nama: 'andi_wijaya',
          peran:
              _demoMemberRoleOverrides['${teamId}_demo-user-me'] ??
              (team.dibuatOleh == 'demo-user-me' ? 'ketua' : 'anggota'),
          appPeran: 'user',
          joinedAt: _now.subtract(const Duration(days: 12)),
        ),
      );
    }
    return list;
  }

  static void setDemoMemberRole(String teamId, String userId, String peran) {
    _demoMemberRoleOverrides['${teamId}_$userId'] = peran;
    final list = _ensureDemoNotifications();
    final team = demoTeams.cast<Team?>().firstWhere(
      (t) => t?.id == teamId,
      orElse: () => null,
    );
    if (userId == 'demo-user-me') {
      list.insert(
        0,
        AppNotification(
          id: 'demo-notif-role-${DateTime.now().microsecondsSinceEpoch}',
          userId: 'demo-user-me',
          type: 'role_updated',
          title: 'Peran Tim Diperbarui',
          body: peran == 'ketua'
              ? 'Kamu diangkat menjadi Ketua di ${team?.nama ?? 'tim'}'
              : 'Peranmu di ${team?.nama ?? 'tim'} menjadi Anggota',
          teamId: teamId,
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }
  }

  static void removeDemoMember(String teamId, String userId) {
    if (_demoRemovedMembers.add('${teamId}_$userId')) {
      _demoCountOffsets[teamId] = (_demoCountOffsets[teamId] ?? 0) - 1;
    }
  }

  static TeamDashboardStats getTeamDashboardStats(String teamId) {
    final team = demoTeams.cast<Team?>().firstWhere(
      (t) => t?.id == teamId,
      orElse: () => null,
    );
    final joined = _demoJoinedIds.contains(teamId);
    final count = team?.memberCount ?? getTeamRoster(teamId).length;
    final canView = joined || team?.dibuatOleh == 'demo-user-me';
    final canManage =
        team?.dibuatOleh == 'demo-user-me' ||
        (_demoMemberRoleOverrides['${teamId}_demo-user-me'] == 'ketua');
    return TeamDashboardStats(
      memberCount: count,
      activeMembersWeek: count == 0 ? 0 : (count * 0.65).round().clamp(1, count),
      totalWeekSessions: count * 2,
      totalWeekKm: double.parse((count * 5.8).toStringAsFixed(1)),
      totalAllKm: double.parse((count * 24.5).toStringAsFixed(1)),
      isMember: joined,
      canViewCode: canView,
      canManageCode: canManage,
    );
  }

  /// 6 challenges covering all sports and units
  static final List<Challenge> challenges = [
    Challenge(
      id: 'chal-001',
      jenis: 'lari',
      targetNilai: 5000,
      targetSatuan: 'jarak_m',
      diumumkan: true,
      waktuMulai: _now.subtract(const Duration(days: 3)),
      waktuSelesai: _now.add(const Duration(days: 4)),
    ),
    Challenge(
      id: 'chal-002',
      jenis: 'lari',
      targetNilai: 10000,
      targetSatuan: 'jarak_m',
      diumumkan: true,
      waktuMulai: _now.subtract(const Duration(days: 1)),
      waktuSelesai: _now.add(const Duration(days: 6)),
    ),
    Challenge(
      id: 'chal-003',
      jenis: 'bersepeda',
      targetNilai: 50000,
      targetSatuan: 'jarak_m',
      diumumkan: true,
      waktuMulai: _now.subtract(const Duration(days: 2)),
      waktuSelesai: _now.add(const Duration(days: 5)),
    ),
    Challenge(
      id: 'chal-004',
      jenis: 'berjalan',
      targetNilai: 7000,
      targetSatuan: 'jarak_m',
      diumumkan: true,
      waktuMulai: _now.subtract(const Duration(days: 4)),
      waktuSelesai: _now.add(const Duration(days: 3)),
    ),
    Challenge(
      id: 'chal-005',
      jenis: 'joging',
      targetNilai: 1800, // 30 mins
      targetSatuan: 'waktu_s',
      diumumkan: true,
      waktuMulai: _now.subtract(const Duration(days: 5)),
      waktuSelesai: _now.add(const Duration(days: 2)),
    ),
    Challenge(
      id: 'chal-006',
      jenis: 'lari',
      targetNilai: 21097, // Half marathon
      targetSatuan: 'jarak_m',
      diumumkan: true,
      waktuMulai: _now.subtract(const Duration(days: 7)),
      waktuSelesai: _now.add(const Duration(days: 14)),
    ),
  ];

  /// Coach-assigned team challenges (kept separate so [challenges] stays 6 items).
  static final List<Challenge> teamChallenges = [
    Challenge(
      id: 'chal-team-001',
      dibuatOleh: 'demo-coach',
      teamId: '11111111-1111-1111-1111-111111111111',
      judul: 'Target Lari Mingguan Tim',
      jenis: 'lari',
      targetNilai: 5000,
      targetSatuan: 'jarak_m',
      diumumkan: true,
      waktuMulai: _now.subtract(const Duration(days: 3)),
      waktuSelesai: _now.add(const Duration(days: 4)),
      createdAt: _now.subtract(const Duration(days: 3)),
    ),
    Challenge(
      id: 'chal-team-002',
      dibuatOleh: 'demo-coach',
      teamId: '11111111-1111-1111-1111-111111111111',
      judul: 'Challenge Endurance 10K',
      jenis: 'lari',
      targetNilai: 10000,
      targetSatuan: 'jarak_m',
      diumumkan: true,
      waktuMulai: _now.subtract(const Duration(days: 1)),
      waktuSelesai: _now.add(const Duration(days: 6)),
      createdAt: _now.subtract(const Duration(days: 1)),
    ),
    Challenge(
      id: 'chal-team-003',
      dibuatOleh: 'demo-coach',
      teamId: '22222222-2222-2222-2222-222222222222',
      judul: 'Joging Skuad Kelas XI IPA 1',
      jenis: 'joging',
      targetNilai: 1800,
      targetSatuan: 'waktu_s',
      diumumkan: true,
      waktuMulai: _now.subtract(const Duration(days: 2)),
      waktuSelesai: _now.add(const Duration(days: 5)),
      createdAt: _now.subtract(const Duration(days: 2)),
    ),
  ];

  static List<Challenge> get demoChallenges => [
    ..._customDemoChallenges,
    ...teamChallenges,
    ...challenges,
  ];

  static Map<String, PartisipasiChallenge> _ensureDemoParticipations() {
    return _demoParticipationsState ??= {
      'chal-team-001': PartisipasiChallenge(
        id: 'demo-part-team-1',
        challengeId: 'chal-team-001',
        userId: 'demo-user-me',
        progressNilai: 2500,
        berhasil: false,
        isActive: true,
        createdAt: _now.subtract(const Duration(days: 3)),
      ),
      'chal-team-002': PartisipasiChallenge(
        id: 'demo-part-team-2',
        challengeId: 'chal-team-002',
        userId: 'demo-user-me',
        progressNilai: 0,
        berhasil: false,
        isActive: false,
        createdAt: _now.subtract(const Duration(days: 1)),
      ),
      'chal-team-003': PartisipasiChallenge(
        id: 'demo-part-team-3',
        challengeId: 'chal-team-003',
        userId: 'demo-user-me',
        progressNilai: 600,
        berhasil: false,
        isActive: false,
        createdAt: _now.subtract(const Duration(days: 2)),
      ),
      'chal-001': PartisipasiChallenge(
        id: 'demo-part-solo-1',
        challengeId: 'chal-001',
        userId: 'demo-user-me',
        progressNilai: 3100,
        berhasil: false,
        isActive: true,
        createdAt: _now.subtract(const Duration(days: 3)),
      ),
      'chal-005': PartisipasiChallenge(
        id: 'demo-part-solo-2',
        challengeId: 'chal-005',
        userId: 'demo-user-me',
        progressNilai: 600,
        berhasil: false,
        isActive: false,
        createdAt: _now.subtract(const Duration(days: 2)),
      ),
    };
  }

  static List<PartisipasiChallenge> getDemoParticipations() {
    final map = _ensureDemoParticipations();
    return map.values.toList()
      ..sort(
        (a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );
  }

  static void _enforceDemoActiveSlot(String challengeId) {
    final map = _ensureDemoParticipations();
    final target = map[challengeId];
    if (target == null || target.berhasil) return;
    final chalMap = {for (final c in demoChallenges) c.id: c};
    final targetIsTeam = chalMap[challengeId]?.isTeamChallenge ?? false;
    for (final entry in map.entries.toList()) {
      final p = entry.value;
      if (p.challengeId == challengeId) {
        map[entry.key] = PartisipasiChallenge(
          id: p.id,
          challengeId: p.challengeId,
          userId: p.userId,
          progressNilai: p.progressNilai,
          berhasil: false,
          isActive: true,
          createdAt: p.createdAt,
        );
      } else if (!p.berhasil &&
          (chalMap[p.challengeId]?.isTeamChallenge ?? false) == targetIsTeam &&
          p.isActive) {
        map[entry.key] = PartisipasiChallenge(
          id: p.id,
          challengeId: p.challengeId,
          userId: p.userId,
          progressNilai: p.progressNilai,
          berhasil: false,
          isActive: false,
          createdAt: p.createdAt,
        );
      }
    }
  }

  static List<PartisipasiChallenge> activateDemoChallenge(String challengeId) {
    final map = _ensureDemoParticipations();
    if (!map.containsKey(challengeId)) {
      joinDemoChallenge(challengeId);
      return getDemoParticipations();
    }
    _enforceDemoActiveSlot(challengeId);
    return getDemoParticipations();
  }

  static PartisipasiChallenge joinDemoChallenge(String challengeId) {
    final map = _ensureDemoParticipations();
    final p = PartisipasiChallenge(
      id: 'demo-part-${DateTime.now().microsecondsSinceEpoch}',
      challengeId: challengeId,
      userId: 'demo-user-me',
      isActive: true,
      createdAt: DateTime.now().toUtc(),
    );
    map[challengeId] = p;
    _enforceDemoActiveSlot(challengeId);
    return map[challengeId]!;
  }

  static void leaveDemoChallenge(String challengeId) {
    _ensureDemoParticipations().remove(challengeId);
  }

  static Challenge createDemoChallenge({
    required String jenis,
    required double targetNilai,
    required String targetSatuan,
    String? teamId,
    String? judul,
    DateTime? waktuMulai,
    DateTime? waktuSelesai,
  }) {
    final cleanTeamId = teamId != null && teamId.isNotEmpty ? teamId : null;
    final cleanJudul = judul != null && judul.trim().isNotEmpty
        ? judul.trim()
        : null;
    final created = Challenge(
      id: 'demo-chal-${DateTime.now().microsecondsSinceEpoch}',
      dibuatOleh: 'demo-user-me',
      teamId: cleanTeamId,
      judul: cleanJudul,
      jenis: jenis,
      targetNilai: targetNilai,
      targetSatuan: targetSatuan,
      waktuMulai: waktuMulai ?? DateTime.now().toUtc(),
      waktuSelesai: waktuSelesai,
      diumumkan: true,
      createdAt: DateTime.now().toUtc(),
    );
    _customDemoChallenges.insert(0, created);
    final map = _ensureDemoParticipations();
    final hasActiveSameSlot = map.values.any((p) {
      if (p.berhasil || !p.isActive) return false;
      final c = demoChallenges.cast<Challenge?>().firstWhere(
        (x) => x?.id == p.challengeId,
        orElse: () => null,
      );
      return (c?.isTeamChallenge ?? false) == (cleanTeamId != null);
    });
    map[created.id] = PartisipasiChallenge(
      id: 'demo-part-${DateTime.now().microsecondsSinceEpoch}',
      challengeId: created.id,
      userId: 'demo-user-me',
      progressNilai: 0,
      berhasil: false,
      isActive: !hasActiveSameSlot,
      createdAt: DateTime.now().toUtc(),
    );
    if (cleanTeamId != null) {
      final team = demoTeams.cast<Team?>().firstWhere(
        (t) => t?.id == cleanTeamId,
        orElse: () => null,
      );
      final targetText = targetSatuan == 'waktu_s'
          ? '${(targetNilai / 60).round()} menit'
          : '${(targetNilai / 1000).toStringAsFixed(targetNilai % 1000 == 0 ? 0 : 1)} km';
      _ensureDemoNotifications().insert(
        0,
        AppNotification(
          id: 'demo-notif-${DateTime.now().microsecondsSinceEpoch}',
          userId: 'demo-user-me',
          type: 'team_challenge_assigned',
          title: 'Challenge Tim · ${team?.nama ?? 'Tim'}',
          body: cleanJudul != null ? '$cleanJudul ($targetText)' : targetText,
          challengeId: created.id,
          teamId: cleanTeamId,
          isRead: false,
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }
    return created;
  }

  static void recordDemoActivityProgress(Activity activity) {
    final map = _ensureDemoParticipations();
    final chalMap = {for (final c in demoChallenges) c.id: c};
    for (final entry in map.entries.toList()) {
      final before = entry.value;
      final chal = chalMap[entry.key];
      if (chal == null) continue;
      final updated = applyActivityDeltaToBaseline(
        baseline: before,
        challenge: chal,
        activity: activity,
        sign: 1,
      );
      map[entry.key] = updated;
      if (!before.berhasil && updated.berhasil) {
        _ensureDemoNotifications().insert(
          0,
          AppNotification(
            id: 'demo-notif-done-${DateTime.now().microsecondsSinceEpoch}',
            userId: 'demo-user-me',
            type: 'challenge_completed',
            title: 'Challenge Selesai!',
            body: chal.judul ?? '${chal.jenis} selesai 100%',
            challengeId: chal.id,
            teamId: chal.teamId,
            isRead: false,
            createdAt: DateTime.now().toUtc(),
          ),
        );
      }
    }
  }

  static List<AppNotification> _ensureDemoNotifications() {
    return _demoNotificationsState ??= [
      AppNotification(
        id: 'demo-notif-1',
        userId: 'demo-user-me',
        type: 'team_challenge_assigned',
        title: 'Challenge Tim · GBK Runners Elite',
        body: 'Target Lari Mingguan Tim (Aktif untuk aktivitas berikutnya)',
        challengeId: 'chal-team-001',
        teamId: '11111111-1111-1111-1111-111111111111',
        isRead: false,
        createdAt: _now.subtract(const Duration(minutes: 25)),
      ),
      AppNotification(
        id: 'demo-notif-2',
        userId: 'demo-user-me',
        type: 'team_challenge_assigned',
        title: 'Challenge Tim · GBK Runners Elite',
        body: 'Challenge Endurance 10K (Menunggu — ketuk untuk pilih aktif)',
        challengeId: 'chal-team-002',
        teamId: '11111111-1111-1111-1111-111111111111',
        isRead: false,
        createdAt: _now.subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: 'demo-notif-3',
        userId: 'demo-user-me',
        type: 'role_updated',
        title: 'Peran Tim Diperbarui',
        body: 'coach_hendra menyambutmu di GBK Runners Elite',
        teamId: '11111111-1111-1111-1111-111111111111',
        isRead: true,
        createdAt: _now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  static List<AppNotification> getDemoNotifications() =>
      List<AppNotification>.of(_ensureDemoNotifications());

  static void markDemoNotificationRead(String notificationId) {
    final list = _ensureDemoNotifications();
    for (var i = 0; i < list.length; i++) {
      if (list[i].id == notificationId) {
        list[i] = list[i].copyWith(isRead: true);
      }
    }
  }

  static void markAllDemoNotificationsRead() {
    final list = _ensureDemoNotifications();
    for (var i = 0; i < list.length; i++) {
      list[i] = list[i].copyWith(isRead: true);
    }
  }

  /// Realistic leaderboard rankings across metrics and periods
  static ({
    String boardNama,
    List<({Peringkat entry, String nama})> rows,
    String? uid,
  })
  getLeaderboardData({
    String metric = 'semua',
    String period = 'semua',
    String scope = 'global',
    String? uid,
  }) {
    final effectiveUid = uid ?? 'demo-user-me';

    final names = [
      'budi_santoso',
      'siti_rahma',
      'andi_wijaya',
      'dewi_lestari',
      'rizky_pratama',
      'farhan_ramadhan',
      'maya_putri',
      'eko_prasetyo',
      'nia_kurnia',
      'coach_hendra',
    ];

    List<double> rawValues;
    String boardTitle;

    if (metric == 'kalori') {
      boardTitle = period == 'bulanan'
          ? 'Kalori Terbakar (Bulanan)'
          : 'Kalori Terbakar (Mingguan)';
      rawValues = [3450, 3120, 2890, 2540, 2210, 1980, 1750, 1520, 1310, 1150];
    } else if (metric == 'durasi') {
      boardTitle = period == 'bulanan'
          ? 'Total Durasi (Bulanan - Menit)'
          : 'Total Durasi (Mingguan - Menit)';
      rawValues = [420, 385, 350, 310, 280, 245, 210, 185, 160, 130];
    } else {
      // 'jarak' or 'semua'
      boardTitle = period == 'bulanan'
          ? 'Peringkat Jarak (Bulanan - Km)'
          : 'Peringkat Jarak (Mingguan - Km)';
      rawValues = [54.2, 48.6, 45.1, 39.8, 36.4, 32.1, 28.5, 24.2, 21.0, 18.5];
    }

    // Demo scopes: my team = first 5, region = first 7, global = all 10.
    final count = switch (scope) {
      'team' => 5,
      'region' => 7,
      _ => 10,
    };
    final rows = <({Peringkat entry, String nama})>[];
    for (var i = 0; i < count; i++) {
      final isMine = i == 2; // andi_wijaya or current demo user
      final userId = isMine ? effectiveUid : 'demo-user-$i';
      rows.add((
        entry: Peringkat(
          id: 'rank-$i',
          leaderboardId: 'demo-board-id',
          userId: userId,
          nilai: rawValues[i],
          posisi: i + 1,
        ),
        nama: isMine ? '${names[i]} (Kamu)' : names[i],
      ));
    }

    return (boardNama: boardTitle, rows: rows, uid: effectiveUid);
  }

  /// Active team chat messages
  static final List<ChatMessage> chatMessages = [
    ChatMessage(
      id: 'msg-001',
      teamId: '11111111-1111-1111-1111-111111111111',
      userId: 'user-001',
      userNama: 'coach_hendra',
      body: 'Halo semuanya! Besok pagi kumpul lari bareng di GBK Gate 5 jam 06:00 WIB ya! 🏃‍♂️',
      createdAt: _now.subtract(const Duration(hours: 3)),
    ),
    ChatMessage(
      id: 'msg-002',
      teamId: '11111111-1111-1111-1111-111111111111',
      userId: 'user-002',
      userNama: 'siti_rahma',
      body: 'Siap coach! Seragam jersey pacer warna lime kan?',
      createdAt: _now.subtract(const Duration(hours: 2, minutes: 45)),
    ),
    ChatMessage(
      id: 'msg-003',
      teamId: '11111111-1111-1111-1111-111111111111',
      userId: 'user-003',
      userNama: 'budi_santoso',
      body: 'Betul, jangan lupa bawa tumbler air sendiri teman-teman!',
      createdAt: _now.subtract(const Duration(hours: 2, minutes: 30)),
    ),
    ChatMessage(
      id: 'msg-004',
      teamId: '11111111-1111-1111-1111-111111111111',
      userId: 'user-004',
      userNama: 'dewi_lestari',
      body: 'Aku target ikut rute 5K santai yaa 👟',
      createdAt: _now.subtract(const Duration(hours: 1, minutes: 50)),
    ),
    ChatMessage(
      id: 'msg-005',
      teamId: '11111111-1111-1111-1111-111111111111',
      userId: 'user-005',
      userNama: 'farhan_ramadhan',
      body: 'Keren! Tim kita sekarang ada di posisi 2 leaderboard mingguan!',
      createdAt: _now.subtract(const Duration(hours: 1, minutes: 15)),
    ),
    ChatMessage(
      id: 'msg-006',
      teamId: '11111111-1111-1111-1111-111111111111',
      userId: 'demo-user-me',
      userNama: 'andi_wijaya',
      body: 'Mantap, besok aku pasti datang on time! Semangat semuanya 🔥',
      createdAt: _now.subtract(const Duration(minutes: 20)),
    ),
  ];

  /// Stats summary for statistic screen
  static const ({double km, int seconds}) statistics = (
    km: 45.2,
    seconds: 14760, // 4j 06m
  );

  /// Dummy coach student PE evaluation rows
  static const List<
    ({
      String nama,
      int sessions,
      double weekKm,
      int streak,
      double? progress,
      bool? berhasil,
    })
  >
  coachDummyRows = [
    (
      nama: 'budi_santoso',
      sessions: 4,
      weekKm: 20.6,
      streak: 5,
      progress: 100.0,
      berhasil: true,
    ),
    (
      nama: 'siti_rahma',
      sessions: 3,
      weekKm: 12.7,
      streak: 3,
      progress: 100.0,
      berhasil: true,
    ),
    (
      nama: 'andi_wijaya',
      sessions: 2,
      weekKm: 7.6,
      streak: 7,
      progress: 76.0,
      berhasil: false,
    ),
    (
      nama: 'dewi_lestari',
      sessions: 2,
      weekKm: 8.4,
      streak: 2,
      progress: 84.0,
      berhasil: false,
    ),
    (
      nama: 'rizky_pratama',
      sessions: 5,
      weekKm: 62.5,
      streak: 12,
      progress: 100.0,
      berhasil: true,
    ),
    (
      nama: 'farhan_ramadhan',
      sessions: 1,
      weekKm: 4.5,
      streak: 4,
      progress: 45.0,
      berhasil: false,
    ),
  ];

  /// Seeds a complete, ephemeral Demo Account into [store] under [demoUserId]
  /// across every real local table (profiles, activities, routes, stats,
  /// streaks, teams, rosters, challenges, participations, notifications,
  /// leaderboards, and chat) without touching sync_outbox or remote Supabase.
  static Future<void> seedIntoStore(
    LocalStore store, {
    String language = 'id',
  }) async {
    await store.wipeUserData(demoUserId);
    resetDemoTeams();

    final now = DateTime.now();
    final nowUtc = now.toUtc();
    final profile = UserProfile(
      id: demoUserId,
      nama: 'andi_wijaya',
      peran: 'user',
      lahir: DateTime.utc(2002, 5, 14),
      jenisKelamin: 'Laki-laki',
      tinggiCm: 172,
      beratKg: 64,
      region: 'DKI Jakarta',
    );
    await store.upsertProfile(
      profile,
      language: language,
      email: 'demo@pacer.local',
    );

    await store.mergeRemoteActivities(demoUserId, activities);
    for (final act in activities.take(4)) {
      await store.saveRoutePoints(act.id, [
        RutePoint(
          aktivitasId: act.id,
          urutan: 0,
          lat: -6.2185,
          lng: 106.8025,
          elevasiM: 8,
          kecepatanMs: 3.1,
          direkamAt: act.mulaiAt,
        ),
        RutePoint(
          aktivitasId: act.id,
          urutan: 1,
          lat: -6.2176,
          lng: 106.8038,
          elevasiM: 9,
          kecepatanMs: 3.3,
          direkamAt: act.mulaiAt?.add(const Duration(minutes: 4)),
        ),
        RutePoint(
          aktivitasId: act.id,
          urutan: 2,
          lat: -6.2192,
          lng: 106.8044,
          elevasiM: 8,
          kecepatanMs: 3.2,
          direkamAt: act.mulaiAt?.add(const Duration(minutes: 8)),
        ),
      ]);
      await store.setSyncTimestamp('route_${act.id}', nowUtc);
    }

    final weekKey = periodeKey(now);
    await store.saveStatistikBaseline(
      demoUserId,
      weekKey,
      statistics.km * 1000.0,
      statistics.seconds,
    );
    await store.saveStreakBaseline(demoUserId, 5, now);

    await store.saveTeams(demoUserId, teams, isMine: false, replaceAll: true);
    await store.saveTeams(demoUserId, demoMyTeams, isMine: true);
    for (final t in teams) {
      await store.saveTeamRoster(demoUserId, t.id, getTeamRoster(t.id));
      await store.setSyncTimestamp('team_${demoUserId}_${t.id}', nowUtc);
      await store.setSyncTimestamp('team_roster_${demoUserId}_${t.id}', nowUtc);
    }

    await store.saveChallenges(demoUserId, demoChallenges);
    await store.saveParticipations(demoUserId, getDemoParticipations());
    await store.saveNotifications(demoUserId, getDemoNotifications());

    final boards = [
      Leaderboard(
        id: 'demo-lb-jarak-week',
        nama: 'Peringkat Jarak (Mingguan - Km)',
        periode: 'mingguan',
        kriteria: 'jarak',
        createdAt: nowUtc,
      ),
      Leaderboard(
        id: 'demo-lb-jarak-month',
        nama: 'Peringkat Jarak (Bulanan - Km)',
        periode: 'bulanan',
        kriteria: 'jarak',
        createdAt: nowUtc.subtract(const Duration(minutes: 1)),
      ),
      Leaderboard(
        id: 'demo-lb-kalori-week',
        nama: 'Kalori Terbakar (Mingguan)',
        periode: 'mingguan',
        kriteria: 'kalori',
        createdAt: nowUtc.subtract(const Duration(minutes: 2)),
      ),
      Leaderboard(
        id: 'demo-lb-durasi-week',
        nama: 'Total Durasi (Mingguan - Menit)',
        periode: 'mingguan',
        kriteria: 'durasi',
        createdAt: nowUtc.subtract(const Duration(minutes: 3)),
      ),
    ];
    await store.saveLeaderboards(demoUserId, boards);

    for (final b in boards) {
      final data = getLeaderboardData(
        metric: b.kriteria,
        period: b.periode,
        scope: 'global',
        uid: demoUserId,
      );
      final cleaned = [
        for (final r in data.rows)
          (
            entry: Peringkat(
              id: '${b.id}_${r.entry.userId}',
              leaderboardId: b.id,
              userId: r.entry.userId,
              nilai: r.entry.nilai,
              posisi: r.entry.posisi,
              updatedAt: nowUtc,
            ),
            nama: r.entry.userId == demoUserId ? 'andi_wijaya' : r.nama,
          ),
      ];
      await store.saveLeaderboardEntries(demoUserId, b.id, cleaned);
      await store.setSyncTimestamp('lb_entries_${demoUserId}_${b.id}', nowUtc);
    }
    await store.saveLeaderboardScope(demoUserId, 'team', {
      demoUserId,
      'demo-user-0',
      'demo-user-1',
      'demo-user-3',
      'demo-user-4',
    });
    await store.saveLeaderboardScope(demoUserId, 'region', {
      demoUserId,
      'demo-user-0',
      'demo-user-1',
      'demo-user-3',
      'demo-user-4',
      'demo-user-5',
      'demo-user-6',
    });

    await store.mergeChatMessages(
      demoUserId,
      '11111111-1111-1111-1111-111111111111',
      chatMessages,
    );

    await store.setSyncTimestamp('profile_$demoUserId', nowUtc);
    await store.setSyncTimestamp('language_$demoUserId', nowUtc);
    await store.setSyncTimestamp('activities_${demoUserId}_15', nowUtc);
    await store.setSyncTimestamp('activities_${demoUserId}_20', nowUtc);
    await store.setSyncTimestamp('activities_${demoUserId}_50', nowUtc);
    await store.setSyncTimestamp('streak_$demoUserId', nowUtc);
    await store.setSyncTimestamp('stats_${demoUserId}_$weekKey', nowUtc);
    await store.setSyncTimestamp('challenges_$demoUserId', nowUtc);
    await store.setSyncTimestamp('challenge_parts_$demoUserId', nowUtc);
    await store.setSyncTimestamp('notifications_$demoUserId', nowUtc);
    await store.setSyncTimestamp('teams_list_$demoUserId', nowUtc);
    await store.setSyncTimestamp('teams_my_$demoUserId', nowUtc);
    await store.setSyncTimestamp('lb_boards_$demoUserId', nowUtc);
    await store.setSyncTimestamp('lb_scope_${demoUserId}_team', nowUtc);
    await store.setSyncTimestamp('lb_scope_${demoUserId}_region', nowUtc);

    await store.setLastUserId(demoUserId);
  }
}
