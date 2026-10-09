import 'package:flutter_test/flutter_test.dart';

import 'package:pacer/src/aktivitas/activity_model.dart' show jsonToDouble;
import 'package:pacer/src/teams/team_model.dart';

void main() {
  group('Team JSON round-trip', () {
    test('preserves all fields', () {
      final createdAt = DateTime(2026, 10, 9, 6, 30);
      final team = Team(
        id: 't1',
        nama: 'Tim A',
        targetNilai: 5000.0,
        dibuatOleh: 'u-coach',
        createdAt: createdAt,
      );
      final restored = Team.fromJson(team.toJson());
      expect(restored.id, 't1');
      expect(restored.nama, 'Tim A');
      expect(restored.targetNilai, 5000.0);
      expect(restored.dibuatOleh, 'u-coach');
      expect(restored.createdAt, createdAt);
    });

    test('keeps targetNilai null when not provided', () {
      final team = Team(
        id: 't2',
        nama: 'Tim B',
        targetNilai: null,
        dibuatOleh: null,
        createdAt: DateTime(2026, 10, 9),
      );
      final restored = Team.fromJson(team.toJson());
      expect(restored.targetNilai, isNull);
      expect(restored.dibuatOleh, isNull);
    });

    test('fromJson reads a realistic PostgREST row', () {
      final team = Team.fromJson({
        'id': 't3',
        'nama': 'Tim C',
        'target_nilai': '5500', // numeric may arrive as string
        'dibuat_oleh': 'u-coach',
        'created_at': '2026-10-09T06:30:00+00:00',
      });
      expect(team.nama, 'Tim C');
      expect(team.targetNilai, 5500.0);
      expect(team.dibuatOleh, 'u-coach');
      expect(team.createdAt, isNotNull);
    });
  });

  group('TeamMember JSON round-trip', () {
    test('preserves all fields with default peran', () {
      final createdAt = DateTime(2026, 10, 9, 7, 0);
      final member = TeamMember(
        id: 'm1',
        teamId: 't1',
        userId: 'u1',
        peran: 'anggota',
        createdAt: createdAt,
      );
      final restored = TeamMember.fromJson(member.toJson());
      expect(restored.id, 'm1');
      expect(restored.teamId, 't1');
      expect(restored.userId, 'u1');
      expect(restored.peran, 'anggota');
      expect(restored.createdAt, createdAt);
    });

    test('fromJson reads a realistic PostgREST row with peran default', () {
      final member = TeamMember.fromJson({
        'id': 'm2',
        'team_id': 't1',
        'user_id': 'u1',
        'peran': 'anggota',
        'created_at': '2026-10-09T07:00:00+00:00',
      });
      expect(member.teamId, 't1');
      expect(member.userId, 'u1');
      expect(member.peran, 'anggota');
      expect(member.createdAt, isNotNull);
    });

    test('fromJson tolerates nullable fields', () {
      final member = TeamMember.fromJson({
        'id': 'm3',
        'team_id': 't1',
        'user_id': 'u1',
        'peran': null,
        'created_at': null,
      });
      expect(member.peran, isNull);
      expect(member.createdAt, isNull);
    });
  });

  group('jsonToDouble', () {
    test('coerces num, string, null, garbage', () {
      expect(jsonToDouble(3), 3.0);
      expect(jsonToDouble('12.5'), 12.5);
      expect(jsonToDouble(null), isNull);
      expect(jsonToDouble('nope'), isNull);
    });
  });
}
