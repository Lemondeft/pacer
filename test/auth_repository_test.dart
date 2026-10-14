import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/auth/user_model.dart';

void main() {
  group('parsePeran', () {
    test('accepts known roles', () {
      expect(parsePeran('user'), 'user');
      expect(parsePeran('coach'), 'coach');
      expect(parsePeran('admin'), 'admin');
    });

    test('falls back to user on null/unknown', () {
      expect(parsePeran(null), 'user');
      expect(parsePeran(''), 'user');
      expect(parsePeran('superadmin'), 'user');
    });
  });

  group('UserProfile', () {
    test('round-trips through JSON', () {
      const profile = UserProfile(id: 'u1', nama: 'Guru', peran: 'coach');
      final restored = UserProfile.fromJson(profile.toJson());
      expect(restored.id, 'u1');
      expect(restored.nama, 'Guru');
      expect(restored.peran, 'coach');
    });

    test('round-trips physical stats', () {
      final profile = UserProfile(
        id: 'u4',
        nama: 'Atlet',
        lahir: DateTime.utc(1996, 5, 14),
        jenisKelamin: 'Perempuan',
        tinggiCm: 170,
        beratKg: 40.5,
      );
      final restored = UserProfile.fromJson(profile.toJson());
      expect(restored.lahir, DateTime.utc(1996, 5, 14));
      expect(restored.jenisKelamin, 'Perempuan');
      expect(restored.tinggiCm, 170.0);
      expect(restored.beratKg, 40.5);
    });

    test('fromJson tolerates missing stats', () {
      final profile = UserProfile.fromJson({'id': 'u5', 'nama': 'Baru'});
      expect(profile.lahir, isNull);
      expect(profile.jenisKelamin, isNull);
      expect(profile.tinggiCm, isNull);
      expect(profile.beratKg, isNull);
    });

    test('fromJson defaults missing role to user', () {
      final profile = UserProfile.fromJson({'id': 'u2', 'nama': 'Atlet'});
      expect(profile.peran, 'user');
      expect(profile.nama, 'Atlet');
    });
  });

  group('buildUserRow', () {
    test('matches RLS users_insert_own contract', () {
      final row = buildUserRow(id: 'u3', nama: 'Peserta');
      expect(row, {'id': 'u3', 'nama': 'Peserta', 'peran': 'user'});
    });
  });
}
