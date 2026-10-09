import 'package:flutter_test/flutter_test.dart';

import 'package:pacer/src/leaderboard/leaderboard_model.dart';

void main() {
  group('Leaderboard JSON round-trip', () {
    test('preserves all fields', () {
      final dibuat = DateTime(2026, 10, 1, 7);
      final board = Leaderboard(
        id: 'lb1',
        nama: 'Bulanan Oktober',
        periode: '2026-10',
        kriteria: 'total_jarak',
        createdAt: dibuat,
      );
      final restored = Leaderboard.fromJson(board.toJson());
      expect(restored.id, 'lb1');
      expect(restored.nama, 'Bulanan Oktober');
      expect(restored.periode, '2026-10');
      expect(restored.kriteria, 'total_jarak');
      expect(restored.createdAt!.isAtSameMomentAs(dibuat), isTrue);
    });

    test('fromJson reads a realistic PostgREST row', () {
      final board = Leaderboard.fromJson({
        'id': 'lb2',
        'nama': 'Mingguan',
        'periode': '2026-W41',
        'kriteria': 'total_jarak_m',
        'created_at': '2026-10-05T00:00:00+00:00',
      });
      expect(board.kriteria, 'total_jarak_m');
      expect(board.createdAt, isNotNull);
    });
  });

  group('Peringkat JSON round-trip', () {
    test('preserves all fields', () {
      final updated = DateTime(2026, 10, 9, 12);
      final entry = Peringkat(
        id: 'pg1',
        leaderboardId: 'lb1',
        userId: 'u1',
        nilai: 15250.75,
        posisi: 2,
        updatedAt: updated,
      );
      final restored = Peringkat.fromJson(entry.toJson());
      expect(restored.id, 'pg1');
      expect(restored.leaderboardId, 'lb1');
      expect(restored.userId, 'u1');
      expect(restored.nilai, 15250.75);
      expect(restored.posisi, 2);
      expect(restored.updatedAt!.isAtSameMomentAs(updated), isTrue);
    });

    test('fromJson tolerates null posisi and string numeric', () {
      final entry = Peringkat.fromJson({
        'id': 'pg2',
        'leaderboard_id': 'lb1',
        'user_id': 'u2',
        'nilai': '9800.5', // numeric may arrive as string
        'posisi': null,
        'updated_at': '2026-10-09T12:00:00+00:00',
      });
      expect(entry.nilai, 9800.5);
      expect(entry.posisi, isNull);
    });
  });

  group('posisiFor', () {
    test('ranks unique values 1-based', () {
      final nilai = <double>[10, 8, 5];
      expect(posisiFor(10, nilai), 1);
      expect(posisiFor(8, nilai), 2);
      expect(posisiFor(5, nilai), 3);
    });

    test('ties share the better rank (competition ranking)', () {
      final nilai = <double>[10, 10, 8];
      expect(posisiFor(10, nilai), 1);
      expect(posisiFor(8, nilai), 3);
    });

    test('empty board ranks first', () {
      expect(posisiFor(0, <double>[]), 1);
    });
  });
}
