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
        inviteCode: 'A1B2C3D4',
        createdAt: createdAt,
      );
      final restored = Team.fromJson(team.toJson());
      expect(restored.id, 't1');
      expect(restored.nama, 'Tim A');
      expect(restored.targetNilai, 5000.0);
      expect(restored.dibuatOleh, 'u-coach');
      expect(restored.inviteCode, 'A1B2C3D4');
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
      expect(restored.inviteCode, isNull);
    });

    test('fromJson reads a realistic PostgREST row', () {
      final team = Team.fromJson({
        'id': 't3',
        'nama': 'Tim C',
        'target_nilai': '5500', // numeric may arrive as string
        'dibuat_oleh': 'u-coach',
        'invite_code': 'E5F6A7B8',
        'member_count': '14',
        'created_at': '2026-10-09T06:30:00+00:00',
      });
      expect(team.nama, 'Tim C');
      expect(team.targetNilai, 5500.0);
      expect(team.dibuatOleh, 'u-coach');
      expect(team.inviteCode, 'E5F6A7B8');
      expect(team.memberCount, 14);
      expect(team.createdAt, isNotNull);
    });

    test('preserves and updates memberCount via toJson and copyWith', () {
      const team = Team(
        id: 't4',
        nama: 'Tim D',
        isPrivate: false,
        memberCount: 9,
      );
      final restored = Team.fromJson(team.toJson());
      expect(restored.memberCount, 9);
      expect(restored.isPrivate, isFalse);

      final updated = restored.copyWith(memberCount: 10);
      expect(updated.memberCount, 10);
      expect(updated.nama, 'Tim D');
    });
  });

  group('TeamRosterMember & TeamDashboardStats', () {
    test('TeamRosterMember.fromJson parses role, app_peran, and joined_at', () {
      final member = TeamRosterMember.fromJson({
        'user_id': 'u-1',
        'nama': ' Siti Rahma ',
        'peran': 'ketua',
        'app_peran': 'coach',
        'joined_at': '2026-11-01T08:15:00+00:00',
      });
      expect(member.userId, 'u-1');
      expect(member.nama, 'Siti Rahma');
      expect(member.peran, 'ketua');
      expect(member.appPeran, 'coach');
      expect(member.joinedAt, isNotNull);
    });

    test('TeamDashboardStats.fromJson parses counts, totals, and flags', () {
      final stats = TeamDashboardStats.fromJson({
        'member_count': 18,
        'active_members_week': '12',
        'total_week_sessions': 36,
        'total_week_km': '104.5',
        'total_all_km': 441.0,
        'is_member': true,
        'can_view_code': true,
        'can_manage_code': false,
      });
      expect(stats.memberCount, 18);
      expect(stats.activeMembersWeek, 12);
      expect(stats.totalWeekSessions, 36);
      expect(stats.totalWeekKm, 104.5);
      expect(stats.totalAllKm, 441.0);
      expect(stats.isMember, isTrue);
      expect(stats.canViewCode, isTrue);
      expect(stats.canManageCode, isFalse);
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
