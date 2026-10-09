import 'package:flutter_test/flutter_test.dart';

import 'package:pacer/src/challenge/challenge_model.dart';

void main() {
  group('Challenge JSON round-trip', () {
    test('preserves all fields', () {
      final mulai = DateTime(2026, 10, 1, 8);
      final selesai = DateTime(2026, 10, 31, 22);
      final dibuat = DateTime(2026, 9, 20, 10);
      final challenge = Challenge(
        id: 'c1',
        dibuatOleh: 'u-coach',
        jenis: 'lari',
        targetNilai: 50000,
        targetSatuan: 'jarak_m',
        waktuMulai: mulai,
        waktuSelesai: selesai,
        diumumkan: true,
        createdAt: dibuat,
      );
      final restored = Challenge.fromJson(challenge.toJson());
      expect(restored.id, 'c1');
      expect(restored.dibuatOleh, 'u-coach');
      expect(restored.jenis, 'lari');
      expect(restored.targetNilai, 50000);
      expect(restored.targetSatuan, 'jarak_m');
      expect(restored.waktuMulai!.isAtSameMomentAs(mulai), isTrue);
      expect(restored.waktuSelesai!.isAtSameMomentAs(selesai), isTrue);
      expect(restored.diumumkan, isTrue);
      expect(restored.createdAt!.isAtSameMomentAs(dibuat), isTrue);
    });

    test('keeps nullable fields null for an unannounced open challenge', () {
      final challenge = Challenge(
        id: 'c2',
        jenis: 'bersepeda',
        targetNilai: 100,
        targetSatuan: 'waktu_s',
      );
      final restored = Challenge.fromJson(challenge.toJson());
      expect(restored.dibuatOleh, isNull);
      expect(restored.waktuMulai, isNull);
      expect(restored.waktuSelesai, isNull);
      expect(restored.diumumkan, isFalse);
      expect(restored.createdAt, isNull);
    });

    test('fromJson reads a realistic PostgREST row', () {
      final challenge = Challenge.fromJson({
        'id': 'c3',
        'dibuat_oleh': 'u-coach',
        'jenis': 'joging',
        'target_nilai': '5000', // numeric may arrive as string
        'target_satuan': 'jarak_m',
        'waktu_mulai': '2026-10-01T00:00:00+00:00',
        'waktu_selesai': '2026-10-31T23:59:59+00:00',
        'diumumkan': true,
        'created_at': '2026-09-20T10:00:00+00:00',
      });
      expect(challenge.targetNilai, 5000);
      expect(challenge.targetSatuan, 'jarak_m');
      expect(challenge.diumumkan, isTrue);
      expect(challenge.waktuSelesai, isNotNull);
    });
  });

  group('PartisipasiChallenge JSON round-trip', () {
    test('preserves all fields', () {
      final joined = DateTime(2026, 10, 2, 9);
      final row = PartisipasiChallenge(
        id: 'p1',
        challengeId: 'c1',
        userId: 'u1',
        progressNilai: 12500.5,
        berhasil: true,
        createdAt: joined,
      );
      final restored = PartisipasiChallenge.fromJson(row.toJson());
      expect(restored.id, 'p1');
      expect(restored.challengeId, 'c1');
      expect(restored.userId, 'u1');
      expect(restored.progressNilai, 12500.5);
      expect(restored.berhasil, isTrue);
      expect(restored.createdAt!.isAtSameMomentAs(joined), isTrue);
    });

    test('fromJson defaults progress/berhasil on a fresh join row', () {
      final row = PartisipasiChallenge.fromJson({
        'id': 'p2',
        'challenge_id': 'c1',
        'user_id': 'u1',
        'progress_nilai': 0,
        'berhasil': false,
        'created_at': '2026-10-02T09:00:00+00:00',
      });
      expect(row.progressNilai, 0);
      expect(row.berhasil, isFalse);
    });
  });

  group('isChallengeActive', () {
    final challenge = Challenge(
      id: 'c1',
      jenis: 'lari',
      targetNilai: 5000,
      targetSatuan: 'jarak_m',
      waktuMulai: DateTime.utc(2026, 10, 1),
      waktuSelesai: DateTime.utc(2026, 10, 31),
    );

    test('false before the window opens', () {
      expect(isChallengeActive(challenge, DateTime.utc(2026, 9, 30)), isFalse);
    });

    test('true inside the window (start inclusive, end exclusive)', () {
      expect(isChallengeActive(challenge, DateTime.utc(2026, 10, 1)), isTrue);
      expect(isChallengeActive(challenge, DateTime.utc(2026, 10, 15)), isTrue);
      expect(
        isChallengeActive(challenge, DateTime.utc(2026, 10, 30, 23, 59, 59)),
        isTrue,
      );
    });

    test('false at or after the end instant', () {
      expect(isChallengeActive(challenge, DateTime.utc(2026, 10, 31)), isFalse);
      expect(isChallengeActive(challenge, DateTime.utc(2026, 11, 1)), isFalse);
    });

    test('null bounds are open-ended', () {
      const open = Challenge(
        id: 'c2',
        jenis: 'joging',
        targetNilai: 1,
        targetSatuan: 'waktu_s',
      );
      expect(isChallengeActive(open, DateTime(2020)), isTrue);
      expect(isChallengeActive(open, DateTime(2030)), isTrue);
    });
  });

  group('progressPercent', () {
    test('partial progress', () {
      expect(progressPercent(2500, 5000), 50.0);
    });

    test('clamps above 100', () {
      expect(progressPercent(6000, 5000), 100.0);
    });

    test('clamps below 0', () {
      expect(progressPercent(-5, 5000), 0.0);
    });

    test('zero target yields 0', () {
      expect(progressPercent(10, 0), 0.0);
    });
  });
}
