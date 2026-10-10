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

  /// Shareable join code (invite_code, 8-char). Null on rows read before
  /// the invite-code migration.
  final String? inviteCode;
  final DateTime? createdAt;

  const Team({
    required this.id,
    required this.nama,
    this.targetNilai,
    this.dibuatOleh,
    this.inviteCode,
    this.createdAt,
  });

  factory Team.fromJson(Map<String, dynamic> json) => Team(
    id: json['id'] as String,
    nama: json['nama'] as String,
    targetNilai: jsonToDouble(json['target_nilai']),
    dibuatOleh: json['dibuat_oleh'] as String?,
    inviteCode: json['invite_code'] as String?,
    createdAt: _parseDate(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
    'target_nilai': targetNilai,
    'dibuat_oleh': dibuatOleh,
    'invite_code': inviteCode,
    'created_at': createdAt?.toIso8601String(),
  };
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
    value == null ? null : DateTime.parse(value as String);
