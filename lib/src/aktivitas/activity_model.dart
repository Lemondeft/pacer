/// Domain models + pure helpers for DFD process 2.0 AKTIVITAS & STATISTIK.
/// Mirrors public.aktivitas / public.rute_points (migration 20261009120000).
library;

/// Allowed values for aktivitas.jenis (matches the DB check constraint).
const List<String> aktivitasJenis = <String>[
  'lari',
  'joging',
  'bersepeda',
  'berjalan',
];

/// One tracked workout row (public.aktivitas).
class Activity {
  final String id;
  final String userId;
  final String jenis;
  final DateTime? mulaiAt;
  final DateTime? selesaiAt;
  final int? durasiS;
  final double? jarakM;

  const Activity({
    required this.id,
    required this.userId,
    required this.jenis,
    this.mulaiAt,
    this.selesaiAt,
    this.durasiS,
    this.jarakM,
  });

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    jenis: json['jenis'] as String,
    mulaiAt: _parseDate(json['mulai_at']),
    selesaiAt: _parseDate(json['selesai_at']),
    durasiS: (json['durasi_s'] as num?)?.toInt(),
    jarakM: jsonToDouble(json['jarak_m']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'jenis': jenis,
    'mulai_at': _iso(mulaiAt),
    'selesai_at': _iso(selesaiAt),
    'durasi_s': durasiS,
    'jarak_m': jarakM,
  };
}

/// One GPS track point (public.rute_points), ordered by [urutan] per aktivitas.
class RutePoint {
  final String aktivitasId;
  final int urutan;
  final double lat;
  final double lng;
  final double? elevasiM;
  final double? kecepatanMs;
  final DateTime? direkamAt;

  const RutePoint({
    required this.aktivitasId,
    required this.urutan,
    required this.lat,
    required this.lng,
    this.elevasiM,
    this.kecepatanMs,
    this.direkamAt,
  });

  factory RutePoint.fromJson(Map<String, dynamic> json) => RutePoint(
    aktivitasId: json['aktivitas_id'] as String,
    urutan: json['urutan'] as int,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    elevasiM: jsonToDouble(json['elevasi_m']),
    kecepatanMs: jsonToDouble(json['kecepatan_ms']),
    direkamAt: _parseDate(json['direkam_at']),
  );

  Map<String, dynamic> toJson() => {
    'aktivitas_id': aktivitasId,
    'urutan': urutan,
    'lat': lat,
    'lng': lng,
    'elevasi_m': elevasiM,
    'kecepatan_ms': kecepatanMs,
    'direkam_at': _iso(direkamAt),
  };
}

/// Coerces a PostgREST numeric (num or string) to double; null-safe.
double? jsonToDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

/// Elapsed whole seconds between [mulai] and [selesai], clamped at >= 0.
int computeDurasiS(DateTime mulai, DateTime selesai) {
  final seconds = selesai.difference(mulai).inSeconds;
  return seconds < 0 ? 0 : seconds;
}

/// True when [lat]/[lng] sit inside WGS-84 bounds (lat -90..90, lng -180..180).
bool isValidLatLng(double lat, double lng) =>
    lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

/// ISO week key 'YYYY-Www' (Monday start) matching the manual's weekly tally.
String periodeKey(DateTime d) {
  final date = DateTime.utc(d.year, d.month, d.day);
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final jan4 = DateTime.utc(thursday.year, 1, 4);
  final week1Monday = jan4.subtract(Duration(days: jan4.weekday - 1));
  final week = thursday.difference(week1Monday).inDays ~/ 7 + 1;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

/// Streak transition: same day no change, yesterday +1, gap resets, first ever = 1.
int streakNext({
  DateTime? terakhirTgl,
  required DateTime today,
  required int current,
}) {
  if (terakhirTgl == null) return 1;
  final todayUtc = DateTime.utc(today.year, today.month, today.day);
  final lastUtc = DateTime.utc(
    terakhirTgl.year,
    terakhirTgl.month,
    terakhirTgl.day,
  );
  if (lastUtc == todayUtc) return current;
  if (lastUtc == todayUtc.subtract(const Duration(days: 1))) return current + 1;
  return 1;
}

DateTime? _parseDate(dynamic value) =>
    value == null ? null : DateTime.parse(value as String);

String? _iso(DateTime? value) => value?.toUtc().toIso8601String();
