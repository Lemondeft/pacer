// Domain models + pure helpers for DFD process 4.0 LEADERBOARD & PERINGKAT.
// Mirrors public.leaderboard / public.peringkat (migration 20261009120000).

import 'package:pacer/src/aktivitas/activity_model.dart' show jsonToDouble;

/// One leaderboard board definition (public.leaderboard: nama/periode/kriteria).
class Leaderboard {
  final String id;
  final String nama;
  final String periode;
  final String kriteria;
  final DateTime? createdAt;

  const Leaderboard({
    required this.id,
    required this.nama,
    required this.periode,
    required this.kriteria,
    this.createdAt,
  });

  factory Leaderboard.fromJson(Map<String, dynamic> json) => Leaderboard(
    id: json['id'] as String,
    nama: json['nama'] as String,
    periode: json['periode'] as String,
    kriteria: json['kriteria'] as String,
    createdAt: _parseDate(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
    'periode': periode,
    'kriteria': kriteria,
    'created_at': _iso(createdAt),
  };
}

/// One ranked user entry (public.peringkat) within a leaderboard board.
class Peringkat {
  final String id;
  final String leaderboardId;
  final String userId;
  final double nilai;
  final int? posisi;
  final DateTime? updatedAt;

  const Peringkat({
    required this.id,
    required this.leaderboardId,
    required this.userId,
    required this.nilai,
    this.posisi,
    this.updatedAt,
  });

  factory Peringkat.fromJson(Map<String, dynamic> json) => Peringkat(
    id: json['id'] as String,
    leaderboardId: json['leaderboard_id'] as String,
    userId: json['user_id'] as String,
    nilai: jsonToDouble(json['nilai']) ?? 0,
    posisi: (json['posisi'] as num?)?.toInt(),
    updatedAt: _parseDate(json['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'leaderboard_id': leaderboardId,
    'user_id': userId,
    'nilai': nilai,
    'posisi': posisi,
    'updated_at': _iso(updatedAt),
  };
}

/// 1-based competition rank of [nilai] within [semuaNilai] (ties share a rank).
int posisiFor(double nilai, List<double> semuaNilai) {
  var better = 0;
  for (final other in semuaNilai) {
    if (other > nilai) better++;
  }
  return better + 1;
}

DateTime? _parseDate(dynamic value) =>
    value == null ? null : DateTime.parse(value as String);

String? _iso(DateTime? value) => value?.toUtc().toIso8601String();
