import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/auth/user_model.dart';

/// Platform-wide aggregate KPI snapshot returned by `admin_get_overview_stats`.
class AdminOverviewStats {
  final int totalUsers;
  final int userCount;
  final int coachCount;
  final int adminCount;
  final int totalTeams;
  final int totalActivities;
  final int flaggedActivities;
  final int verifiedActivities;
  final double totalKm;

  const AdminOverviewStats({
    this.totalUsers = 0,
    this.userCount = 0,
    this.coachCount = 0,
    this.adminCount = 0,
    this.totalTeams = 0,
    this.totalActivities = 0,
    this.flaggedActivities = 0,
    this.verifiedActivities = 0,
    this.totalKm = 0,
  });

  factory AdminOverviewStats.fromJson(Map<String, dynamic> json) =>
      AdminOverviewStats(
        totalUsers: (json['total_users'] as num?)?.toInt() ?? 0,
        userCount: (json['user_count'] as num?)?.toInt() ?? 0,
        coachCount: (json['coach_count'] as num?)?.toInt() ?? 0,
        adminCount: (json['admin_count'] as num?)?.toInt() ?? 0,
        totalTeams: (json['total_teams'] as num?)?.toInt() ?? 0,
        totalActivities: (json['total_activities'] as num?)?.toInt() ?? 0,
        flaggedActivities: (json['flagged_activities'] as num?)?.toInt() ?? 0,
        verifiedActivities: (json['verified_activities'] as num?)?.toInt() ?? 0,
        totalKm: jsonToDouble(json['total_km']) ?? 0.0,
      );
}

/// Summary account row for Super Admin user & role management (no sensitive PII).
class AdminUserEntry {
  final String id;
  final String nama;
  final String peran;
  final String? region;
  final DateTime? createdAt;
  final int totalRuns;
  final double totalKm;

  const AdminUserEntry({
    required this.id,
    required this.nama,
    required this.peran,
    this.region,
    this.createdAt,
    this.totalRuns = 0,
    this.totalKm = 0,
  });

  factory AdminUserEntry.fromJson(Map<String, dynamic> json) {
    final rawCreated = json['created_at'] as String?;
    return AdminUserEntry(
      id: json['id'] as String,
      nama: (json['nama'] as String?) ?? '',
      peran: parsePeran(json['peran'] as String?),
      region: json['region'] as String?,
      createdAt: rawCreated == null ? null : DateTime.tryParse(rawCreated),
      totalRuns: (json['total_runs'] as num?)?.toInt() ?? 0,
      totalKm: jsonToDouble(json['total_km']) ?? 0.0,
    );
  }
}

/// Single-use or quota-limited coach promotion invite code.
class CoachInvite {
  final String id;
  final String code;
  final String? note;
  final int maxUses;
  final int usesCount;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final DateTime? createdAt;

  const CoachInvite({
    required this.id,
    required this.code,
    this.note,
    this.maxUses = 1,
    this.usesCount = 0,
    this.expiresAt,
    this.revokedAt,
    this.createdAt,
  });

  bool get isRevoked => revokedAt != null;
  bool get isExhausted => usesCount >= maxUses;
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now().toUtc());
  bool get isUsable => !isRevoked && !isExhausted && !isExpired;

  factory CoachInvite.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) =>
        v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
    return CoachInvite(
      id: json['id'] as String,
      code: json['code'] as String,
      note: json['note'] as String?,
      maxUses: (json['max_uses'] as num?)?.toInt() ?? 1,
      usesCount: (json['uses_count'] as num?)?.toInt() ?? 0,
      expiresAt: parseDt(json['expires_at']),
      revokedAt: parseDt(json['revoked_at']),
      createdAt: parseDt(json['created_at']),
    );
  }
}

/// Flagged workout summary surfaced for moderation (excludes raw GPS points).
class AdminFlaggedActivity {
  final String id;
  final String userId;
  final String userNama;
  final String jenis;
  final DateTime? mulaiAt;
  final int durasiS;
  final double jarakM;
  final int? cadenceSpm;
  final String? suggestedSport;
  final String validationStatus;
  final double? validationScore;
  final List<String> validationReasons;

  const AdminFlaggedActivity({
    required this.id,
    required this.userId,
    required this.userNama,
    required this.jenis,
    this.mulaiAt,
    required this.durasiS,
    required this.jarakM,
    this.cadenceSpm,
    this.suggestedSport,
    required this.validationStatus,
    this.validationScore,
    this.validationReasons = const [],
  });

  factory AdminFlaggedActivity.fromJson(Map<String, dynamic> json) {
    final rawReasons = json['validation_reasons'];
    final reasons = rawReasons is List
        ? [for (final r in rawReasons) r.toString()]
        : const <String>[];
    final rawStart = json['mulai_at'] as String?;
    return AdminFlaggedActivity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userNama: (json['user_nama'] as String?) ?? '',
      jenis: (json['jenis'] as String?) ?? 'lari',
      mulaiAt: rawStart == null ? null : DateTime.tryParse(rawStart),
      durasiS: (json['durasi_s'] as num?)?.toInt() ?? 0,
      jarakM: jsonToDouble(json['jarak_m']) ?? 0.0,
      cadenceSpm: (json['cadence_spm'] as num?)?.toInt(),
      suggestedSport: json['suggested_sport'] as String?,
      validationStatus: (json['validation_status'] as String?) ?? 'unverified',
      validationScore: jsonToDouble(json['validation_score']),
      validationReasons: reasons,
    );
  }
}

/// Immutable admin action audit entry.
class AdminAuditEntry {
  final String id;
  final String actorId;
  final String actorNama;
  final String action;
  final String targetType;
  final String? targetId;
  final String? reason;
  final DateTime createdAt;

  const AdminAuditEntry({
    required this.id,
    required this.actorId,
    required this.actorNama,
    required this.action,
    required this.targetType,
    this.targetId,
    this.reason,
    required this.createdAt,
  });

  factory AdminAuditEntry.fromJson(Map<String, dynamic> json) =>
      AdminAuditEntry(
        id: json['id'] as String,
        actorId: json['actor_id'] as String,
        actorNama: (json['actor_nama'] as String?) ?? '',
        action: json['action'] as String,
        targetType: json['target_type'] as String,
        targetId: json['target_id'] as String?,
        reason: json['reason'] as String?,
        createdAt:
            DateTime.tryParse((json['created_at'] as String?) ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}
