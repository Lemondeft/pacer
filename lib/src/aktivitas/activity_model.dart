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

/// Display state of a streak relative to [now].
/// - [active]: worked out today.
/// - [atRisk]: last workout was yesterday — run today to keep it.
/// - [inactive]: no workout yesterday or today (streak is broken / none).
enum StreakStatus { active, atRisk, inactive }

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Status of a stored streak row. The DB count is only recomputed on the
/// next workout, so a gap must be detected client-side.
StreakStatus streakStatusOf({
  required int count,
  required DateTime? last,
  required DateTime now,
}) {
  if (count <= 0 || last == null) return StreakStatus.inactive;
  final gap = _day(now).difference(_day(last)).inDays;
  if (gap <= 0) return StreakStatus.active;
  if (gap == 1) return StreakStatus.atRisk;
  return StreakStatus.inactive;
}

/// Streak count to display: the stored count while still alive, 0 once
/// a full day has been missed.
int effectiveStreak({
  required int count,
  required DateTime? last,
  required DateTime now,
}) =>
    streakStatusOf(count: count, last: last, now: now) == StreakStatus.inactive
    ? 0
    : count;

/// Mon..Sun done flags for the week containing [now]: the trailing [count]
/// days ending at [last]. Pass the effective count so broken streaks
/// don't paint stale days.
List<bool> streakWeek({
  required int count,
  required DateTime? last,
  required DateTime now,
}) {
  final monday = _day(now).subtract(Duration(days: now.weekday - 1));
  return [
    for (var i = 0; i < 7; i++)
      last != null &&
          count > 0 &&
          () {
            final back = _day(last)
                .difference(DateTime(monday.year, monday.month, monday.day + i))
                .inDays;
            return back >= 0 && back < count;
          }(),
  ];
}

DateTime? _parseDate(dynamic value) =>
    value == null ? null : DateTime.parse(value as String);

String? _iso(DateTime? value) => value?.toUtc().toIso8601String();

/// Derived post-workout metrics computed from activity totals & GPS points.
class RunMetrics {
  final int caloriesKcal;
  final double elevationGainM;
  final double? stepLengthCm;
  final int? cadenceSpm;

  const RunMetrics({
    required this.caloriesKcal,
    required this.elevationGainM,
    this.stepLengthCm,
    this.cadenceSpm,
  });
}

/// Sums positive GPS elevation deltas while filtering small altitude jitter.
double computeElevationGainM(List<RutePoint> points) {
  double? anchorAlt;
  var gainM = 0.0;
  for (final pt in points) {
    final alt = pt.elevasiM;
    if (alt == null || !alt.isFinite) continue;
    if (anchorAlt == null) {
      anchorAlt = alt;
      continue;
    }
    final diff = alt - anchorAlt;
    if (diff > 1.5) {
      gainM += diff;
      anchorAlt = alt;
    } else if (diff < -1.5) {
      anchorAlt = alt;
    }
  }
  return gainM;
}

/// ACSM MET-based calorie estimation from sport type, duration, distance, and weight.
int estimateCaloriesKcal({
  required String jenis,
  required int durasiS,
  required double jarakM,
  double weightKg = 65,
}) {
  if (durasiS <= 0 || weightKg <= 0) return 0;
  final hours = durasiS / 3600.0;
  final speedKmh = (jarakM > 0 && hours > 0) ? (jarakM / 1000.0) / hours : 0.0;
  final double met;
  switch (jenis.toLowerCase()) {
    case 'berjalan':
      if (speedKmh <= 0) {
        met = 3.2;
      } else if (speedKmh < 4.0) {
        met = 3.0;
      } else if (speedKmh < 6.0) {
        met = 4.3;
      } else {
        met = 5.0;
      }
      break;
    case 'joging':
      met = speedKmh > 9.0 ? 8.5 : 7.0;
      break;
    case 'bersepeda':
      if (speedKmh < 16.0) {
        met = 6.0;
      } else if (speedKmh < 22.0) {
        met = 8.0;
      } else {
        met = 10.0;
      }
      break;
    case 'lari':
    default:
      if (speedKmh < 8.5) {
        met = 8.3;
      } else if (speedKmh < 10.5) {
        met = 9.8;
      } else {
        met = 11.5;
      }
      break;
  }
  final kcal = (met * 3.5 * weightKg / 200.0) * (durasiS / 60.0);
  return kcal.round();
}

/// Computes derived finish metrics (calories, elevation gain, stride, cadence).
RunMetrics computeRunMetrics({
  required String jenis,
  required int durasiS,
  required double jarakM,
  List<RutePoint> points = const [],
  double? weightKg,
  double? heightCm,
}) {
  final weight = (weightKg != null && weightKg > 0) ? weightKg : 65.0;
  final height = (heightCm != null && heightCm > 0) ? heightCm : 170.0;
  final calories = estimateCaloriesKcal(
    jenis: jenis,
    durasiS: durasiS,
    jarakM: jarakM,
    weightKg: weight,
  );
  final elevation = computeElevationGainM(points);

  if (jenis.toLowerCase() == 'bersepeda') {
    return RunMetrics(caloriesKcal: calories, elevationGainM: elevation);
  }
  if (jarakM <= 0 || durasiS <= 0) {
    return RunMetrics(
      caloriesKcal: calories,
      elevationGainM: elevation,
      stepLengthCm: 0,
      cadenceSpm: 0,
    );
  }

  final speedMs = jarakM / durasiS;
  final factor = switch (jenis.toLowerCase()) {
    'berjalan' => (0.41 + (speedMs - 1.2) * 0.04).clamp(0.38, 0.48),
    'joging' => (0.52 + (speedMs - 2.2) * 0.05).clamp(0.45, 0.68),
    _ => (0.58 + (speedMs - 2.8) * 0.06).clamp(0.45, 0.80),
  };
  final stepCm = (height * factor).clamp(50.0, 145.0);
  final totalSteps = jarakM / (stepCm / 100.0);
  final cadence = (totalSteps / (durasiS / 60.0)).round().clamp(40, 220);

  return RunMetrics(
    caloriesKcal: calories,
    elevationGainM: elevation,
    stepLengthCm: stepCm,
    cadenceSpm: cadence,
  );
}
