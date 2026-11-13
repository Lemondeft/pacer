import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/auth/user_model.dart';
import 'package:pacer/src/challenge/challenge_model.dart';
import 'package:pacer/src/local/local_models.dart';
import 'package:pacer/src/local/sqlite_local_store.dart';
import 'package:pacer/src/local/store_factory_io.dart';
import 'package:pacer/src/teams/team_model.dart';

void main() {
  late SqliteLocalStore store;

  setUp(() async {
    store = await openInMemorySqliteStore();
  });

  tearDown(() async {
    await store.close();
  });

  group('SqliteLocalStore Offline Persistence Tests', () {
    test('saveDraftStart + checkpointDraft + loadActiveDraft preserves crash recovery state and discardDraft cleans up', () async {
      final start = DateTime.utc(2026, 11, 13, 6, 30);
      await store.saveDraftStart(
        id: 'draft-run-1',
        userId: 'user-a',
        jenis: 'lari',
        mulaiAt: start,
      );

      final p1 = RutePoint(
        aktivitasId: 'draft-run-1',
        urutan: 0,
        lat: -6.2000,
        lng: 106.8166,
        elevasiM: 12,
        kecepatanMs: 3.1,
        direkamAt: start,
      );
      final p2 = RutePoint(
        aktivitasId: 'draft-run-1',
        urutan: 1,
        lat: -6.2010,
        lng: 106.8170,
        elevasiM: 13,
        kecepatanMs: 3.3,
        direkamAt: start.add(const Duration(seconds: 10)),
      );

      await store.checkpointDraft(
        id: 'draft-run-1',
        elapsedS: 10,
        distanceM: 120.5,
        newPoints: [p1, p2],
      );

      final p3 = RutePoint(
        aktivitasId: 'draft-run-1',
        urutan: 2,
        lat: -6.2020,
        lng: 106.8174,
        elevasiM: 14,
        kecepatanMs: 3.4,
        direkamAt: start.add(const Duration(seconds: 25)),
      );
      await store.checkpointDraft(
        id: 'draft-run-1',
        elapsedS: 25,
        distanceM: 255.0,
        newPoints: [p2, p3],
      );

      final recovered = await store.loadActiveDraft('user-a');
      expect(recovered, isNotNull);
      expect(recovered!.id, 'draft-run-1');
      expect(recovered.jenis, 'lari');
      expect(recovered.elapsedS, 25);
      expect(recovered.distanceM, closeTo(255.0, 0.01));
      expect(recovered.points.length, 3);
      expect(recovered.points.map((p) => p.urutan).toList(), [0, 1, 2]);
      expect(await store.loadActiveDraft('user-b'), isNull);

      await store.discardDraft('draft-run-1');
      expect(await store.loadActiveDraft('user-a'), isNull);
      expect(await store.getRoutePoints('draft-run-1'), isEmpty);
      expect(await store.getPendingOutboxCount('user-a'), 0);
    });

    test('finalizeRunAtomic commits activity, points, clears draft, and creates sync_activity outbox', () async {
      final start = DateTime.utc(2026, 11, 13, 7, 0);
      await store.saveDraftStart(
        id: 'run-atomic-1',
        userId: 'user-a',
        jenis: 'joging',
        mulaiAt: start,
      );

      final pts = [
        RutePoint(
          aktivitasId: 'run-atomic-1',
          urutan: 0,
          lat: -6.2,
          lng: 106.8,
          direkamAt: start,
        ),
        RutePoint(
          aktivitasId: 'run-atomic-1',
          urutan: 1,
          lat: -6.205,
          lng: 106.805,
          direkamAt: start.add(const Duration(minutes: 15)),
        ),
      ];

      final saved = await store.finalizeRunAtomic(
        id: 'run-atomic-1',
        userId: 'user-a',
        jenis: 'joging',
        mulaiAt: start,
        selesaiAt: start.add(const Duration(minutes: 15)),
        durasiS: 900,
        jarakM: 2800.0,
        allPoints: pts,
      );

      expect(saved.id, 'run-atomic-1');
      expect(saved.jarakM, 2800.0);
      expect(saved.durasiS, 900);
      expect(await store.loadActiveDraft('user-a'), isNull);

      final list = await store.listActivities('user-a');
      expect(list.length, 1);
      expect(list.first.status, RunStatus.finished);
      expect(list.first.syncState, SyncState.pending);
      expect(list.first.statistikApplied, isFalse);

      final storedPts = await store.getRoutePoints('run-atomic-1');
      expect(storedPts.length, 2);

      final outbox = await store.getAllOutboxItems('user-a');
      expect(outbox.length, 1);
      expect(outbox.first.opType, OutboxOp.syncActivity);
      expect(outbox.first.entityId, 'run-atomic-1');
      expect(outbox.first.status, SyncState.pending);
    });

    test('statistik and streak include pending unsynced deltas without double counting after sync', () async {
      final monday = DateTime(2026, 11, 9, 7, 0);
      final tuesday = DateTime(2026, 11, 10, 7, 0);
      final bounds = isoWeekBounds(monday);

      await store.saveStatistikBaseline('user-a', bounds.periode, 5000.0, 1500);
      await store.saveStreakBaseline('user-a', 2, DateTime(2026, 11, 9));

      await store.finalizeRunAtomic(
        id: 'run-1',
        userId: 'user-a',
        jenis: 'lari',
        mulaiAt: tuesday.toUtc(),
        selesaiAt: tuesday.add(const Duration(minutes: 20)).toUtc(),
        durasiS: 1200,
        jarakM: 3500.0,
        allPoints: const [],
      );

      final effStats = await store.getStatistikEffective('user-a', bounds.periode);
      expect(effStats, isNotNull);
      expect(effStats!.jarakM, closeTo(8500.0, 0.01));
      expect(effStats.waktuS, 2700);

      final effStreak = await store.getStreakEffective('user-a');
      expect(effStreak, isNotNull);
      expect(effStreak!.berjalan, 3);

      final outbox = await store.getAllOutboxItems('user-a');
      expect(outbox.length, 1);

      await store.markOutboxSynced(
        outbox.first.id,
        syncedActivityId: 'run-1',
        periode: bounds.periode,
        baselineJarakM: 8500.0,
        baselineWaktuS: 2700,
        baselineStreak: 3,
        baselineStreakLast: DateTime(2026, 11, 10),
      );

      final afterSyncStats = await store.getStatistikEffective('user-a', bounds.periode);
      expect(afterSyncStats!.jarakM, closeTo(8500.0, 0.01));
      expect(afterSyncStats.waktuS, 2700);

      final afterSyncStreak = await store.getStreakEffective('user-a');
      expect(afterSyncStreak!.berjalan, 3);
      expect(await store.getPendingOutboxCount('user-a'), 0);
    });

    test('multi-user data isolation separates activities, profiles, teams, challenges, and chat', () async {
      await store.upsertProfile(
        const UserProfile(id: 'user-a', nama: 'Alice', peran: 'user'),
        language: 'en',
        email: 'alice@pacer.id',
      );
      await store.upsertProfile(
        const UserProfile(id: 'user-b', nama: 'Budi', peran: 'coach'),
        language: 'id',
        email: 'budi@pacer.id',
      );

      await store.saveTeams(
        'user-a',
        const [Team(id: 't1', nama: 'Alice Club')],
        isMine: true,
      );
      await store.saveChallenges(
        'user-a',
        const [
          Challenge(
            id: 'c1',
            jenis: 'lari',
            targetNilai: 10000,
            targetSatuan: 'jarak_m',
          ),
        ],
      );
      await store.queueChatMessage(
        id: 'm1',
        teamId: 't1',
        userId: 'user-a',
        userNama: 'Alice',
        body: 'Hai offline',
      );
      await store.finalizeRunAtomic(
        id: 'run-a',
        userId: 'user-a',
        jenis: 'lari',
        mulaiAt: DateTime.utc(2026, 11, 13, 8),
        selesaiAt: DateTime.utc(2026, 11, 13, 8, 10),
        durasiS: 600,
        jarakM: 2000,
        allPoints: const [],
      );

      expect((await store.listActivities('user-a')).length, 1);
      expect(await store.listActivities('user-b'), isEmpty);
      expect((await store.getProfile('user-a'))?.nama, 'Alice');
      expect((await store.getProfile('user-b'))?.nama, 'Budi');
      expect((await store.getTeams('user-a', mineOnly: true)).length, 1);
      expect(await store.getTeams('user-b', mineOnly: true), isEmpty);
      expect((await store.getChatMessages('user-a', 't1')).length, 1);
      expect(await store.getChatMessages('user-b', 't1'), isEmpty);
    });
  });
}
