/// User profile mirroring public.users (migration 20261009120000).
class UserProfile {
  final String id;
  final String? nama;
  final String peran;

  const UserProfile({required this.id, this.nama, this.peran = 'user'});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawRole = json['peran'] as String?;
    return UserProfile(
      id: json['id'] as String,
      nama: json['nama'] as String?,
      peran: parsePeran(rawRole),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'nama': nama, 'peran': peran};
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
