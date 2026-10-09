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
