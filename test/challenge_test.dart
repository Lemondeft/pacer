import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/challenge/challenge_model.dart';
import 'package:pacer/src/local/local_models.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/memory_local_store.dart';
import 'package:pacer/src/local/store_factory_io.dart';
import 'package:pacer/src/ui/app_strings.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/more_screens.dart';

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

  group('challengeActivityDelta & evaluateChallengeProgress', () {
    final challenge = Challenge(
      id: 'c-eval-1',
      jenis: 'lari',
      targetNilai: 5000,
      targetSatuan: 'jarak_m',
      diumumkan: true,
      waktuMulai: DateTime.utc(2026, 11, 1, 0, 0),
      waktuSelesai: DateTime.utc(2026, 11, 10, 0, 0),
    );
    final participation = PartisipasiChallenge(
      id: 'p-eval-1',
      challengeId: 'c-eval-1',
      userId: 'u1',
      createdAt: DateTime.utc(2026, 11, 3, 8, 0),
    );

    Activity makeRun({
      required String id,
      String jenis = 'lari',
      required DateTime mulai,
      DateTime? selesai,
      double? jarakM,
      int? durasiS,
    }) {
      return Activity(
        id: id,
        userId: 'u1',
        jenis: jenis,
        mulaiAt: mulai,
        selesaiAt: selesai,
        jarakM: jarakM,
        durasiS: durasiS,
      );
    }

    test('counts only finished same-sport workouts inside [mulai, selesai) and finished at/after joining', () {
      final joinedAt = participation.createdAt!;
      final valid = makeRun(
        id: 'a-valid',
        mulai: joinedAt.add(const Duration(hours: 1)),
        selesai: joinedAt.add(const Duration(hours: 1, minutes: 20)),
        jarakM: 3000,
        durasiS: 1200,
      );
      final startedBeforeJoinFinishedAtJoin = makeRun(
        id: 'a-boundary',
        mulai: joinedAt.subtract(const Duration(minutes: 15)),
        selesai: joinedAt,
        jarakM: 1200,
        durasiS: 900,
      );
      final unfinished = makeRun(
        id: 'a-draft',
        mulai: joinedAt.add(const Duration(hours: 2)),
        selesai: null,
        jarakM: 4000,
        durasiS: 1000,
      );
      final wrongSport = makeRun(
        id: 'a-bike',
        jenis: 'bersepeda',
        mulai: joinedAt.add(const Duration(hours: 3)),
        selesai: joinedAt.add(const Duration(hours: 3, minutes: 30)),
        jarakM: 8000,
        durasiS: 1800,
      );
      final finishedBeforeJoin = makeRun(
        id: 'a-before-join',
        mulai: DateTime.utc(2026, 11, 2, 7),
        selesai: DateTime.utc(2026, 11, 2, 7, 30),
        jarakM: 5000,
        durasiS: 1800,
      );
      final startedBeforeWindow = makeRun(
        id: 'a-before-window',
        mulai: DateTime.utc(2026, 10, 31, 23, 59),
        selesai: joinedAt.add(const Duration(hours: 4)),
        jarakM: 2500,
        durasiS: 900,
      );
      final startedAtEndExclusive = makeRun(
        id: 'a-after-window',
        mulai: DateTime.utc(2026, 11, 10, 0, 0),
        selesai: DateTime.utc(2026, 11, 10, 0, 20),
        jarakM: 2500,
        durasiS: 1200,
      );

      expect(
        challengeActivityDelta(
          challenge: challenge,
          participation: participation,
          activity: valid,
        ),
        3000,
      );
      expect(
        challengeActivityDelta(
          challenge: challenge,
          participation: participation,
          activity: startedBeforeJoinFinishedAtJoin,
        ),
        1200,
      );
      expect(
        challengeActivityDelta(
          challenge: challenge,
          participation: participation,
          activity: unfinished,
        ),
        0,
      );
      expect(
        challengeActivityDelta(
          challenge: challenge,
          participation: participation,
          activity: wrongSport,
        ),
        0,
      );
      expect(
        challengeActivityDelta(
          challenge: challenge,
          participation: participation,
          activity: finishedBeforeJoin,
        ),
        0,
      );
      expect(
        challengeActivityDelta(
          challenge: challenge,
          participation: participation,
          activity: startedBeforeWindow,
        ),
        0,
      );
      expect(
        challengeActivityDelta(
          challenge: challenge,
          participation: participation,
          activity: startedAtEndExclusive,
        ),
        0,
      );

      final result = evaluateChallengeProgress(
        challenge: challenge,
        participation: participation,
        activities: [
          valid,
          startedBeforeJoinFinishedAtJoin,
          unfinished,
          wrongSport,
          finishedBeforeJoin,
          startedBeforeWindow,
          startedAtEndExclusive,
        ],
      );
      expect(result.progressNilai, closeTo(4200, 0.01));
      expect(result.berhasil, isFalse);

      final extraRun = makeRun(
        id: 'a-finish-target',
        mulai: joinedAt.add(const Duration(days: 1)),
        selesai: joinedAt.add(const Duration(days: 1, minutes: 10)),
        jarakM: 800,
        durasiS: 600,
      );
      final completed = evaluateChallengeProgress(
        challenge: challenge,
        participation: participation,
        activities: [valid, startedBeforeJoinFinishedAtJoin, extraRun],
      );
      expect(completed.progressNilai, closeTo(5000, 0.01));
      expect(completed.berhasil, isTrue);
    });

    test('supports waktu_s duration targets cleanly', () {
      const timed = Challenge(
        id: 'c-time-1',
        jenis: 'joging',
        targetNilai: 1800,
        targetSatuan: 'waktu_s',
        diumumkan: true,
      );
      final part = PartisipasiChallenge(
        id: 'p-time-1',
        challengeId: 'c-time-1',
        userId: 'u1',
        createdAt: DateTime.utc(2026, 11, 1),
      );
      final j1 = makeRun(
        id: 'j1',
        jenis: 'joging',
        mulai: DateTime.utc(2026, 11, 2, 7),
        selesai: DateTime.utc(2026, 11, 2, 7, 20),
        jarakM: 2500,
        durasiS: 1200,
      );
      final j2 = makeRun(
        id: 'j2',
        jenis: 'joging',
        mulai: DateTime.utc(2026, 11, 3, 7),
        selesai: DateTime.utc(2026, 11, 3, 7, 15),
        jarakM: 1800,
        durasiS: 900,
      );
      final res = evaluateChallengeProgress(
        challenge: timed,
        participation: part,
        activities: [j1, j2],
      );
      expect(res.progressNilai, closeTo(2100, 0.01));
      expect(res.berhasil, isTrue);
    });
  });

  group('LocalStore Challenge Offline Accumulation & Delete', () {
    final factories = <({String name, Future<LocalStore> Function() create})>[
      (name: 'SqliteLocalStore', create: openInMemorySqliteStore),
      (name: 'MemoryLocalStore', create: () async => MemoryLocalStore()),
    ];

    for (final factory in factories) {
      test('${factory.name} accumulates pending runs, applies sync delta idempotently, and decrements on delete', () async {
        final store = await factory.create();
        addTearDown(() => store.close());

        final challenge = Challenge(
          id: 'c-store-1',
          jenis: 'lari',
          targetNilai: 5000,
          targetSatuan: 'jarak_m',
          diumumkan: true,
          waktuMulai: DateTime.utc(2026, 11, 1),
          waktuSelesai: DateTime.utc(2026, 11, 30),
        );
        await store.saveChallenges('u-store', [challenge]);
        final joined = await store.queueJoinChallenge('u-store', 'c-store-1');
        final t0 = joined.createdAt!.toUtc().add(const Duration(minutes: 1));

        await store.finalizeRunAtomic(
          id: 'r-store-1',
          userId: 'u-store',
          jenis: 'lari',
          mulaiAt: t0,
          selesaiAt: t0.add(const Duration(minutes: 15)),
          durasiS: 900,
          jarakM: 3000,
          allPoints: const [],
        );

        final p1 = (await store.getParticipations('u-store')).single;
        expect(p1.progressNilai, closeTo(3000, 0.01));
        expect(p1.berhasil, isFalse);

        await store.finalizeRunAtomic(
          id: 'r-store-2',
          userId: 'u-store',
          jenis: 'lari',
          mulaiAt: t0.add(const Duration(hours: 2)),
          selesaiAt: t0.add(const Duration(hours: 2, minutes: 12)),
          durasiS: 720,
          jarakM: 2500,
          allPoints: const [],
        );

        final p2 = (await store.getParticipations('u-store')).single;
        expect(p2.progressNilai, closeTo(5500, 0.01));
        expect(p2.berhasil, isTrue);

        // Delete unsynced run -> effective drops immediately.
        await store.deleteActivityLocal('r-store-2');
        final pAfterUnsyncedDel =
            (await store.getParticipations('u-store')).single;
        expect(pAfterUnsyncedDel.progressNilai, closeTo(3000, 0.01));
        expect(pAfterUnsyncedDel.berhasil, isFalse);

        // Mark first run synced via fallback delta -> no double counting!
        final bounds = isoWeekBounds(t0);
        final outbox = await store.getAllOutboxItems('u-store');
        final runOutbox = outbox.firstWhere((o) => o.entityId == 'r-store-1');
        await store.markOutboxSynced(
          runOutbox.id,
          syncedActivityId: 'r-store-1',
          periode: bounds.periode,
          baselineJarakM: 3000,
          baselineWaktuS: 900,
          baselineStreak: 1,
          baselineStreakLast: t0.toLocal(),
        );
        final syncedAct = (await store.listActivities('u-store')).single.activity;
        await store.applySyncedActivityChallengeDelta('u-store', syncedAct);

        final pSynced = (await store.getParticipations('u-store')).single;
        expect(pSynced.progressNilai, closeTo(3000, 0.01));

        // Delete already-synced run -> baseline decrements cleanly.
        await store.deleteActivityLocal('r-store-1');
        final pAfterSyncedDel =
            (await store.getParticipations('u-store')).single;
        expect(pAfterSyncedDel.progressNilai, closeTo(0, 0.01));
        expect(pAfterSyncedDel.berhasil, isFalse);
      });
    }
  });

  group('Challenge UI Widgets', () {
    testWidgets('ChallengeDetailSheet shows dynamic progress and blocks joining ended challenges', (tester) async {
      final active = Challenge(
        id: 'c-ui-1',
        jenis: 'bersepeda',
        targetNilai: 20000,
        targetSatuan: 'jarak_m',
        diumumkan: true,
        waktuMulai: DateTime.utc(2026, 11, 1),
        waktuSelesai: DateTime.now().toUtc().add(const Duration(days: 5)),
      );
      final part = PartisipasiChallenge(
        id: 'p-ui-1',
        challengeId: 'c-ui-1',
        userId: 'u-ui',
        progressNilai: 10000,
        berhasil: false,
        createdAt: DateTime.utc(2026, 11, 2),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: Scaffold(
            body: ChallengeDetailSheet(
              challengeId: active.id,
              challenge: active,
              participation: part,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('20'), findsOneWidget);
      expect(find.text('KM'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text(S.sportName('bersepeda')), findsOneWidget);
      expect(find.textContaining('29-10-2009'), findsNothing);
      expect(find.textContaining('1,30 Jam'), findsNothing);

      final ended = Challenge(
        id: 'c-ui-ended',
        jenis: 'lari',
        targetNilai: 5000,
        targetSatuan: 'jarak_m',
        diumumkan: true,
        waktuMulai: DateTime.utc(2025, 1, 1),
        waktuSelesai: DateTime.utc(2025, 1, 7),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.light(),
          home: Scaffold(
            body: ChallengeDetailSheet(
              challengeId: ended.id,
              challenge: ended,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(S.challengeEnded), findsWidgets);
    });

    testWidgets('CreateChallengeScreen displays sport selector chips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: const CreateChallengeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(S.challengeSportLabel), findsOneWidget);
      for (final j in aktivitasJenis) {
        expect(find.text(S.sportName(j)), findsOneWidget);
      }
    });
  });

  group('Team Challenges, Solo Challenges & Active Slots', () {
    test('Challenge and PartisipasiChallenge round-trip teamId, judul, and isActive', () {
      final teamChal = Challenge.fromJson({
        'id': 'c-team-1',
        'dibuat_oleh': 'u-coach',
        'team_id': 't-1',
        'judul': 'Squad 10K Sprint',
        'jenis': 'lari',
        'target_nilai': 10000,
        'target_satuan': 'jarak_m',
        'diumumkan': true,
      });
      expect(teamChal.isTeamChallenge, isTrue);
      expect(teamChal.judul, 'Squad 10K Sprint');
      final restoredChal = Challenge.fromJson(teamChal.toJson());
      expect(restoredChal.teamId, 't-1');
      expect(restoredChal.judul, 'Squad 10K Sprint');

      final part = PartisipasiChallenge.fromJson({
        'id': 'p-slot-1',
        'challenge_id': 'c-team-1',
        'user_id': 'u1',
        'progress_nilai': 2500,
        'berhasil': false,
        'is_active': false,
      });
      expect(part.isActive, isFalse);
      final restoredPart = PartisipasiChallenge.fromJson(part.toJson());
      expect(restoredPart.isActive, isFalse);
    });

    test('challengeActivityDelta respects nullable activity.challengeIds opt-in/opt-out', () {
      final joined = DateTime.utc(2026, 11, 10, 6);
      final teamChal = Challenge(
        id: 'c-team-run',
        teamId: 't-1',
        judul: 'Tim 5K',
        jenis: 'lari',
        targetNilai: 5000,
        targetSatuan: 'jarak_m',
        diumumkan: true,
        waktuMulai: DateTime.utc(2026, 11, 1),
        waktuSelesai: DateTime.utc(2026, 11, 30),
      );
      final soloChal = Challenge(
        id: 'c-solo-run',
        jenis: 'lari',
        targetNilai: 3000,
        targetSatuan: 'jarak_m',
        diumumkan: true,
        waktuMulai: DateTime.utc(2026, 11, 1),
        waktuSelesai: DateTime.utc(2026, 11, 30),
      );
      final teamPart = PartisipasiChallenge(
        id: 'p-team',
        challengeId: teamChal.id,
        userId: 'u1',
        createdAt: joined,
      );
      final soloPart = PartisipasiChallenge(
        id: 'p-solo',
        challengeId: soloChal.id,
        userId: 'u1',
        createdAt: joined,
      );

      final dualActivity = Activity(
        id: 'act-both',
        userId: 'u1',
        jenis: 'lari',
        mulaiAt: joined.add(const Duration(minutes: 5)),
        selesaiAt: joined.add(const Duration(minutes: 25)),
        jarakM: 2200,
        challengeIds: const ['c-team-run', 'c-solo-run'],
      );
      expect(
        challengeActivityDelta(
          challenge: teamChal,
          participation: teamPart,
          activity: dualActivity,
        ),
        2200,
      );
      expect(
        challengeActivityDelta(
          challenge: soloChal,
          participation: soloPart,
          activity: dualActivity,
        ),
        2200,
      );

      final teamOnlyActivity = Activity(
        id: 'act-team-only',
        userId: 'u1',
        jenis: 'lari',
        mulaiAt: joined.add(const Duration(hours: 1)),
        selesaiAt: joined.add(const Duration(hours: 1, minutes: 20)),
        jarakM: 2000,
        challengeIds: const ['c-team-run'],
      );
      expect(
        challengeActivityDelta(
          challenge: teamChal,
          participation: teamPart,
          activity: teamOnlyActivity,
        ),
        2000,
      );
      expect(
        challengeActivityDelta(
          challenge: soloChal,
          participation: soloPart,
          activity: teamOnlyActivity,
        ),
        0,
      );

      final optOutAll = Activity(
        id: 'act-optout',
        userId: 'u1',
        jenis: 'lari',
        mulaiAt: joined.add(const Duration(hours: 2)),
        selesaiAt: joined.add(const Duration(hours: 2, minutes: 15)),
        jarakM: 1500,
        challengeIds: const [],
      );
      expect(
        challengeActivityDelta(
          challenge: teamChal,
          participation: teamPart,
          activity: optOutAll,
        ),
        0,
      );
      expect(
        challengeActivityDelta(
          challenge: soloChal,
          participation: soloPart,
          activity: optOutAll,
        ),
        0,
      );
    });

    for (final entry in <String, Future<LocalStore> Function()>{
      'MemoryLocalStore': () async => MemoryLocalStore(),
      'SqliteLocalStore': () async => openInMemorySqliteStore(),
    }.entries) {
      test('${entry.key} enforces 1 active Team + 1 active Solo slot and switches cleanly', () async {
        final store = await entry.value();
        try {
          final teamA = Challenge(
            id: 'slot-team-a',
            teamId: 't1',
            judul: 'Tim A',
            jenis: 'lari',
            targetNilai: 10000,
            targetSatuan: 'jarak_m',
            diumumkan: true,
            waktuMulai: DateTime.utc(2026, 11, 1),
            waktuSelesai: DateTime.utc(2026, 11, 30),
          );
          final teamB = Challenge(
            id: 'slot-team-b',
            teamId: 't1',
            judul: 'Tim B',
            jenis: 'lari',
            targetNilai: 15000,
            targetSatuan: 'jarak_m',
            diumumkan: true,
            waktuMulai: DateTime.utc(2026, 11, 1),
            waktuSelesai: DateTime.utc(2026, 11, 30),
          );
          final solo1 = Challenge(
            id: 'slot-solo-1',
            judul: 'Solo 5K',
            jenis: 'lari',
            targetNilai: 5000,
            targetSatuan: 'jarak_m',
            diumumkan: true,
            waktuMulai: DateTime.utc(2026, 11, 1),
            waktuSelesai: DateTime.utc(2026, 11, 30),
          );
          await store.saveChallenges('u-slot', [teamA, teamB, solo1]);
          await store.queueJoinChallenge('u-slot', teamA.id);
          await store.queueJoinChallenge('u-slot', teamB.id);
          await store.queueJoinChallenge('u-slot', solo1.id);

          final switched = await store.queueActivateChallenge(
            'u-slot',
            teamB.id,
          );
          final byId = {for (final p in switched) p.challengeId: p};
          expect(byId[teamA.id]!.isActive, isFalse);
          expect(byId[teamB.id]!.isActive, isTrue);
          expect(byId[solo1.id]!.isActive, isTrue);

          final runStart = DateTime.now().toUtc().add(const Duration(seconds: 2));
          await store.finalizeRunAtomic(
            id: 'run-slot-1',
            userId: 'u-slot',
            jenis: 'lari',
            mulaiAt: runStart,
            selesaiAt: runStart.add(const Duration(minutes: 20)),
            durasiS: 1200,
            jarakM: 3000,
            challengeIds: [teamB.id, solo1.id],
            allPoints: const [],
          );

          final afterRun = {
            for (final p in await store.getParticipations('u-slot'))
              p.challengeId: p,
          };
          expect(afterRun[teamA.id]!.progressNilai, closeTo(0, 0.01));
          expect(afterRun[teamB.id]!.progressNilai, closeTo(3000, 0.01));
          expect(afterRun[solo1.id]!.progressNilai, closeTo(3000, 0.01));
        } finally {
          await store.close();
        }
      });
    }
  });
}
