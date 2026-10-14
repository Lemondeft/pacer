import 'package:pacer/src/aktivitas/activity_model.dart' show jsonToDouble;

/// User profile mirroring public.users (migration 20261009120000 +
/// 20261014000000 profile stats). Physical stats are nullable = not provided.
class UserProfile {
  final String id;
  final String? nama;
  final String peran;
  final DateTime? lahir;
  final String? jenisKelamin;
  final double? tinggiCm;
  final double? beratKg;

  const UserProfile({
    required this.id,
    this.nama,
    this.peran = 'user',
    this.lahir,
    this.jenisKelamin,
    this.tinggiCm,
    this.beratKg,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawRole = json['peran'] as String?;
    return UserProfile(
      id: json['id'] as String,
      nama: json['nama'] as String?,
      peran: parsePeran(rawRole),
      lahir: _parseDate(json['lahir']),
      jenisKelamin: json['jenis_kelamin'] as String?,
      tinggiCm: jsonToDouble(json['tinggi_cm']),
      beratKg: jsonToDouble(json['berat_kg']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
    'peran': peran,
    'lahir': _isoDate(lahir),
    'jenis_kelamin': jenisKelamin,
    'tinggi_cm': tinggiCm,
    'berat_kg': beratKg,
  };
}

/// Normalizes role values from the DB; unknown/null falls back to 'user'.
String parsePeran(String? raw) {
  switch (raw) {
    case 'coach':
    case 'admin':
      return raw!;
    case 'user':
    default:
      return 'user';
  }
}

/// Row payload for inserting the profile right after sign-up.
/// RLS policy users_insert_own requires id == auth.uid(), peran defaults to user.
Map<String, dynamic> buildUserRow({required String id, required String nama}) =>
    {'id': id, 'nama': nama, 'peran': 'user'};

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final dt = DateTime.tryParse(value.toString());
  if (dt == null) return null;
  // Date-only strings (lahir) parse as local midnight; normalize to UTC so
  // round-trips are timezone-stable. Birthdays are calendar dates anyway.
  if (!value.toString().contains('T')) {
    return DateTime.utc(dt.year, dt.month, dt.day);
  }
  return dt;
}

String? _isoDate(DateTime? value) {
  if (value == null) return null;
  final d = value.toUtc();
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
