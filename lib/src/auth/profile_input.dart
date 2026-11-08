/// Pure input helpers for the profile editor (AboutMe), unit-testable.
library;

/// Indonesian provinces: the fixed set behind users.region, so the
/// leaderboard "Wilayah" scope matches exactly (no "Jakarta" vs "DKI" split).
const List<String> indonesianRegions = <String>[
  'Aceh',
  'Sumatera Utara',
  'Sumatera Barat',
  'Riau',
  'Kepulauan Riau',
  'Jambi',
  'Sumatera Selatan',
  'Bangka Belitung',
  'Bengkulu',
  'Lampung',
  'DKI Jakarta',
  'Banten',
  'Jawa Barat',
  'Jawa Tengah',
  'DI Yogyakarta',
  'Jawa Timur',
  'Bali',
  'Nusa Tenggara Barat',
  'Nusa Tenggara Timur',
  'Kalimantan Barat',
  'Kalimantan Tengah',
  'Kalimantan Selatan',
  'Kalimantan Timur',
  'Kalimantan Utara',
  'Sulawesi Utara',
  'Gorontalo',
  'Sulawesi Tengah',
  'Sulawesi Barat',
  'Sulawesi Selatan',
  'Sulawesi Tenggara',
  'Maluku',
  'Maluku Utara',
  'Papua',
  'Papua Barat',
  'Papua Selatan',
  'Papua Tengah',
  'Papua Pegunungan',
  'Papua Barat Daya',
];

/// Parses "170", "170.5" and the Indonesian "170,5". Null when empty/invalid.
double? parseDecimal(String raw) {
  final t = raw.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// Strict yyyy-mm-dd → date (rejects 2024-02-31 style rollovers).
DateTime? parseIsoDate(String raw) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw.trim());
  if (m == null) return null;
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  final dt = DateTime.utc(y, mo, d);
  return (dt.year == y && dt.month == mo && dt.day == d) ? dt : null;
}

/// DB check: 0 < height < 300 (cm). True when [v] is acceptable.
bool validHeightCm(double v) => v > 0 && v < 300;

/// DB check: 0 < weight < 1000 (kg).
bool validWeightKg(double v) => v > 0 && v < 1000;
