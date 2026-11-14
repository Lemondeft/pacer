/// Domain models for DFD process 5.0 PACER TEAM.
/// Mirrors public.teams / public.team_members (migration 20261009120000).
library;

import 'package:pacer/src/aktivitas/activity_model.dart' show jsonToDouble;

/// One team row (public.teams).
class Team {
  final String id;
  final String nama;
  final double? targetNilai;
  final String? dibuatOleh;

  /// Private teams are hidden from the directory and join by secret code.
  final bool isPrivate;

  /// Join code. NOT part of the teams row anymore (it lives in
  /// team_secrets; managers fetch it via TeamRepository.getInviteCode).
  /// Only used for local/demo data.
  final String? inviteCode;
  final DateTime? createdAt;
  final int? memberCount;

  const Team({
    required this.id,
    required this.nama,
    this.targetNilai,
    this.dibuatOleh,
    this.isPrivate = true,
    this.inviteCode,
    this.createdAt,
    this.memberCount,
  });

  Team copyWith({
    String? id,
    String? nama,
    double? targetNilai,
    String? dibuatOleh,
    bool? isPrivate,
    String? inviteCode,
    DateTime? createdAt,
    int? memberCount,
  }) => Team(
    id: id ?? this.id,
    nama: nama ?? this.nama,
    targetNilai: targetNilai ?? this.targetNilai,
    dibuatOleh: dibuatOleh ?? this.dibuatOleh,
    isPrivate: isPrivate ?? this.isPrivate,
    inviteCode: inviteCode ?? this.inviteCode,
    createdAt: createdAt ?? this.createdAt,
    memberCount: memberCount ?? this.memberCount,
  );

  factory Team.fromJson(Map<String, dynamic> json) => Team(
    id: json['id'] as String,
    nama: json['nama'] as String,
    targetNilai: jsonToDouble(json['target_nilai']),
    dibuatOleh: json['dibuat_oleh'] as String?,
    isPrivate: json['is_private'] as bool? ?? true,
    inviteCode: json['invite_code'] as String?,
    createdAt: _parseDate(json['created_at']),
    memberCount: _jsonToInt(json['member_count']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
    'target_nilai': targetNilai,
    'dibuat_oleh': dibuatOleh,
    'is_private': isPrivate,
    'invite_code': inviteCode,
    'created_at': createdAt?.toIso8601String(),
    if (memberCount != null) 'member_count': memberCount,
  };
}

/// Detailed team roster entry returned by `get_team_roster` / cache.
class TeamRosterMember {
  final String userId;
  final String nama;
  final String peran;
  final String appPeran;
  final DateTime? joinedAt;

  const TeamRosterMember({
    required this.userId,
    required this.nama,
    required this.peran,
    required this.appPeran,
    this.joinedAt,
  });

  factory TeamRosterMember.fromJson(Map<String, dynamic> json) =>
      TeamRosterMember(
        userId: json['user_id'] as String,
        nama: (json['nama'] as String? ?? '').trim(),
        peran: json['peran'] as String? ?? 'anggota',
        appPeran: json['app_peran'] as String? ?? 'user',
        joinedAt: _parseDate(json['joined_at']),
      );
}

/// Aggregate team activity summary for the Teams Dashboard.
class TeamDashboardStats {
  final int memberCount;
  final int activeMembersWeek;
  final int totalWeekSessions;
  final double totalWeekKm;
  final double totalAllKm;
  final bool isMember;
  final bool canViewCode;
  final bool canManageCode;

  const TeamDashboardStats({
    required this.memberCount,
    required this.activeMembersWeek,
    required this.totalWeekSessions,
    required this.totalWeekKm,
    required this.totalAllKm,
    required this.isMember,
    this.canViewCode = false,
    required this.canManageCode,
  });

  factory TeamDashboardStats.fromJson(Map<String, dynamic> json) =>
      TeamDashboardStats(
        memberCount: _jsonToInt(json['member_count']) ?? 0,
        activeMembersWeek: _jsonToInt(json['active_members_week']) ?? 0,
        totalWeekSessions: _jsonToInt(json['total_week_sessions']) ?? 0,
        totalWeekKm: jsonToDouble(json['total_week_km']) ?? 0,
        totalAllKm: jsonToDouble(json['total_all_km']) ?? 0,
        isMember: json['is_member'] as bool? ?? false,
        canViewCode: json['can_view_code'] as bool? ?? false,
        canManageCode: json['can_manage_code'] as bool? ?? false,
      );
}

/// One membership row (public.team_members), unique (team_id, user_id).
/// DB defaults peran to 'anggota'; the model keeps it nullable so partial
/// rows from RLS-filtered reads still map.
class TeamMember {
  final String id;
  final String teamId;
  final String userId;
  final String? peran;
  final DateTime? createdAt;

  const TeamMember({
    required this.id,
    required this.teamId,
    required this.userId,
    this.peran,
    this.createdAt,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
    id: json['id'] as String,
    teamId: json['team_id'] as String,
    userId: json['user_id'] as String,
    peran: json['peran'] as String?,
    createdAt: _parseDate(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'team_id': teamId,
    'user_id': userId,
    'peran': peran,
    'created_at': createdAt?.toIso8601String(),
  };
}

DateTime? _parseDate(dynamic value) =>
    value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

int? _jsonToInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
