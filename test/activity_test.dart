import 'package:flutter_test/flutter_test.dart';

import 'package:pacer/src/aktivitas/activity_model.dart';

void main() {
  group('Activity JSON round-trip', () {
    test('preserves all fields', () {
      final mulai = DateTime(2026, 10, 9, 6, 30);
      final selesai = DateTime(2026, 10, 9, 7, 15);
      final activity = Activity(
        id: 'a1',
        userId: 'u1',
        jenis: 'lari',
        mulaiAt: mulai,
        selesaiAt: selesai,
        durasiS: 2700,
        jarakM: 5421.5,
      );
      final restored = Activity.fromJson(activity.toJson());
      expect(restored.id, 'a1');
      expect(restored.userId, 'u1');
      expect(restored.jenis, 'lari');
      expect(restored.mulaiAt!.isAtSameMomentAs(mulai), isTrue);
      expect(restored.selesaiAt!.isAtSameMomentAs(selesai), isTrue);
      expect(restored.durasiS, 2700);
      expect(restored.jarakM, 5421.5);
    });

    test('keeps nullable fields null for an ongoing activity', () {
      final activity = Activity(
        id: 'a2',
        userId: 'u1',
        jenis: 'berjalan',
        mulaiAt: DateTime(2026, 10, 9),
      );
      final restored = Activity.fromJson(activity.toJson());
      expect(restored.selesaiAt, isNull);
      expect(restored.durasiS, isNull);
      expect(restored.jarakM, isNull);
    });

    test('fromJson reads a realistic PostgREST row', () {
      final activity = Activity.fromJson({
        'id': 'a3',
        'user_id': 'u1',
        'jenis': 'bersepeda',
        'mulai_at': '2026-10-09T03:00:00+00:00',
        'selesai_at': '2026-10-09T04:02:30+00:00',
        'durasi_s': 3750,
        'jarak_m': '15250.75', // numeric may arrive as string
      });
      expect(activity.jenis, 'bersepeda');
      expect(activity.durasiS, 3750);
      expect(activity.jarakM, 15250.75);
    });
  });

  group('RutePoint JSON round-trip', () {
    test('preserves all fields', () {
      final direkam = DateTime(2026, 10, 9, 6, 30, 5);
      final point = RutePoint(
        aktivitasId: 'a1',
        urutan: 7,
        lat: -6.2088,
        lng: 106.8456,
        elevasiM: 25.5,
        kecepatanMs: 3.2,
        direkamAt: direkam,
      );
      final restored = RutePoint.fromJson(point.toJson());
      expect(restored.aktivitasId, 'a1');
      expect(restored.urutan, 7);
      expect(restored.lat, -6.2088);
      expect(restored.lng, 106.8456);
      expect(restored.elevasiM, 25.5);
      expect(restored.kecepatanMs, 3.2);
      expect(restored.direkamAt!.isAtSameMomentAs(direkam), isTrue);
    });

    test('fromJson tolerates nullable columns and int-shaped doubles', () {
      final point = RutePoint.fromJson({
        'aktivitas_id': 'a1',
        'urutan': 0,
        'lat': -6, // float8 may serialize without a decimal point
        'lng': 106.8456,
        'elevasi_m': null,
        'kecepatan_ms': null,
        'direkam_at': null,
      });
      expect(point.lat, -6.0);
      expect(point.elevasiM, isNull);
      expect(point.kecepatanMs, isNull);
      expect(point.direkamAt, isNull);
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

  group('computeDurasiS', () {
    test('whole hour', () {
      expect(
        computeDurasiS(DateTime(2026, 10, 9, 6), DateTime(2026, 10, 9, 7)),
        3600,
      );
    });

    test('zero for identical instants', () {
      final t = DateTime(2026, 10, 9, 6);
      expect(computeDurasiS(t, t), 0);
    });

    test('clamps negative to 0', () {
      expect(
        computeDurasiS(DateTime(2026, 10, 9, 7), DateTime(2026, 10, 9, 6)),
        0,
      );
    });

    test('truncates sub-second remainders', () {
      final mulai = DateTime(2026, 10, 9, 6);
      final selesai = mulai.add(const Duration(milliseconds: 1500));
      expect(computeDurasiS(mulai, selesai), 1);
    });
  });

  group('isValidLatLng', () {
    test('accepts in-range and boundary values', () {
      expect(isValidLatLng(0, 0), isTrue);
      expect(isValidLatLng(90, 180), isTrue);
      expect(isValidLatLng(-90, -180), isTrue);
      expect(isValidLatLng(-6.2088, 106.8456), isTrue);
    });

    test('rejects out-of-range and non-finite values', () {
      expect(isValidLatLng(90.000001, 0), isFalse);
      expect(isValidLatLng(-90.000001, 0), isFalse);
      expect(isValidLatLng(0, 180.000001), isFalse);
      expect(isValidLatLng(0, -180.000001), isFalse);
      expect(isValidLatLng(double.nan, 0), isFalse);
      expect(isValidLatLng(double.infinity, 0), isFalse);
    });
  });

  group('periodeKey', () {
    test('matches ISO week for known dates', () {
      expect(periodeKey(DateTime(2026, 10, 9)), '2026-W41');
      expect(periodeKey(DateTime(2026, 1, 1)), '2026-W01');
      expect(periodeKey(DateTime(2026, 12, 28)), '2026-W53');
      expect(periodeKey(DateTime(2025, 1, 1)), '2025-W01');
      expect(periodeKey(DateTime(2024, 12, 30)), '2025-W01');
      expect(periodeKey(DateTime(2027, 1, 1)), '2026-W53');
    });

    test('always emits YYYY-Www and ignores time of day', () {
      final key = periodeKey(DateTime(2026, 6, 15, 23, 59));
      expect(RegExp(r'^\d{4}-W\d{2}$').hasMatch(key), isTrue);
      expect(key, periodeKey(DateTime(2026, 6, 15)));
    });
  });

  group('streakNext', () {
    final today = DateTime(2026, 10, 9);

    test('first ever starts at 1', () {
      expect(streakNext(terakhirTgl: null, today: today, current: 0), 1);
    });

    test('same day keeps current (no change)', () {
      expect(
        streakNext(
          terakhirTgl: DateTime(2026, 10, 9, 7, 30),
          today: today,
          current: 4,
        ),
        4,
      );
    });

    test('yesterday increments', () {
      expect(
        streakNext(
          terakhirTgl: DateTime(2026, 10, 8),
          today: today,
          current: 4,
        ),
        5,
      );
    });

    test('yesterday from zero starts at 1', () {
      expect(
        streakNext(
          terakhirTgl: DateTime(2026, 10, 8),
          today: today,
          current: 0,
        ),
        1,
      );
    });

    test('gap resets to 1', () {
      expect(
        streakNext(
          terakhirTgl: DateTime(2026, 10, 5),
          today: today,
          current: 7,
        ),
        1,
      );
    });

    test('month boundary counts as consecutive', () {
      expect(
        streakNext(
          terakhirTgl: DateTime(2026, 9, 30),
          today: DateTime(2026, 10, 1),
          current: 2,
        ),
        3,
      );
    });

    test('year boundary counts as consecutive', () {
      expect(
        streakNext(
          terakhirTgl: DateTime(2026, 12, 31),
          today: DateTime(2027, 1, 1),
          current: 9,
        ),
        10,
      );
    });
  });
}
