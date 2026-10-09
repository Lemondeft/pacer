// Domain models + pure helpers for DFD process 3.0 CHALLENGE.
// Mirrors public.challenge / public.partisipasi_challenge (migration 20261009120000).

import 'package:pacer/src/aktivitas/activity_model.dart' show jsonToDouble;

/// Allowed values for challenge.target_satuan (matches the DB check constraint).
const List<String> targetSatuanOpsi = <String>['jarak_m', 'waktu_s'];

/// One coach-created challenge row (public.challenge).
class Challenge {
  final String id;
  final String? dibuatOleh;
  final String jenis;
  final double targetNilai;
  final String targetSatuan;
  final DateTime? waktuMulai;
  final DateTime? waktuSelesai;
  final bool diumumkan;
  final DateTime? createdAt;

  const Challenge({
    required this.id,
    this.dibuatOleh,
    required this.jenis,
    required this.targetNilai,
    required this.targetSatuan,
    this.waktuMulai,
    this.waktuSelesai,
    this.diumumkan = false,
    this.createdAt,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
    id: json['id'] as String,
    dibuatOleh: json['dibuat_oleh'] as String?,
    jenis: json['jenis'] as String,
    targetNilai: jsonToDouble(json['target_nilai']) ?? 0,
    targetSatuan: json['target_satuan'] as String,
    waktuMulai: _parseDate(json['waktu_mulai']),
    waktuSelesai: _parseDate(json['waktu_selesai']),
    diumumkan: json['diumumkan'] as bool? ?? false,
    createdAt: _parseDate(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'dibuat_oleh': dibuatOleh,
    'jenis': jenis,
    'target_nilai': targetNilai,
    'target_satuan': targetSatuan,
    'waktu_mulai': _iso(waktuMulai),
    'waktu_selesai': _iso(waktuSelesai),
    'diumumkan': diumumkan,
    'created_at': _iso(createdAt),
  };
}

/// One athlete's participation row (public.partisipasi_challenge).
class PartisipasiChallenge {
  final String id;
  final String challengeId;
  final String userId;
  final double progressNilai;
  final bool berhasil;
  final DateTime? createdAt;

  const PartisipasiChallenge({
    required this.id,
    required this.challengeId,
    required this.userId,
    this.progressNilai = 0,
    this.berhasil = false,
    this.createdAt,
  });

  factory PartisipasiChallenge.fromJson(Map<String, dynamic> json) =>
      PartisipasiChallenge(
        id: json['id'] as String,
        challengeId: json['challenge_id'] as String,
        userId: json['user_id'] as String,
        progressNilai: jsonToDouble(json['progress_nilai']) ?? 0,
        berhasil: json['berhasil'] as bool? ?? false,
        createdAt: _parseDate(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'challenge_id': challengeId,
    'user_id': userId,
    'progress_nilai': progressNilai,
    'berhasil': berhasil,
    'created_at': _iso(createdAt),
  };
}

/// True when [now] is inside [waktuMulai, waktuSelesai) (null bounds = open-ended).
bool isChallengeActive(Challenge c, DateTime now) {
  final started = c.waktuMulai == null || !now.isBefore(c.waktuMulai!);
  final notEnded = c.waktuSelesai == null || now.isBefore(c.waktuSelesai!);
  return started && notEnded;
}

/// Progress toward the target as 0..100 percent, clamped; 0 when target <= 0.
double progressPercent(double progressNilai, double targetNilai) {
  if (targetNilai <= 0) return 0;
  final pct = progressNilai / targetNilai * 100;
  return pct.clamp(0.0, 100.0).toDouble();
}

DateTime? _parseDate(dynamic value) =>
    value == null ? null : DateTime.parse(value as String);

String? _iso(DateTime? value) => value?.toUtc().toIso8601String();
