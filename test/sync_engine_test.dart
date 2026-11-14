import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/challenge/challenge_model.dart';
import 'package:pacer/src/chat/chat_model.dart';
import 'package:pacer/src/local/local_models.dart';
import 'package:pacer/src/local/sqlite_local_store.dart';
import 'package:pacer/src/local/store_factory_io.dart';
import 'package:pacer/src/sync/connectivity_service.dart';
import 'package:pacer/src/sync/sync_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeGateway implements RemoteSyncGateway {
  @override
  String? currentUserId = 'user-sync-1';

  bool validSession = true;
  final List<String> ops = [];
  final List<String> upsertedActivities = [];
  final List<String> fallbackCalls = [];
  final List<({String userId, String challengeId, String? id, DateTime? createdAt})>
      joinedCalls = [];
  final List<String> challengeFallbackCalls = [];
  int rpcCalls = 0;
  int challengeRpcCalls = 0;

  Object? throwOnActivity;
  Object? throwOnProfile;
  Object? throwOnLanguage;
  bool returnNullFromRpc = false;
  bool returnNullFromChallengeRpc = false;
  List<PartisipasiChallenge>? challengeRpcResult;
  List<PartisipasiChallenge> challengeFallbackResult = const [];
  int rpcFailuresBeforeSuccess = 0;

  @override
  Future<bool> ensureValidSession() async => validSession;

  @override
  Future<void> upsertActivity(Activity activity) async {
    ops.add('activity:${activity.id}');
    if (throwOnActivity != null) throw throwOnActivity!;
    upsertedActivities.add(activity.id);
  }

  @override
  Future<void> upsertRoutePoints(
    String aktivitasId,
    List<RutePoint> points,
  ) async {
    ops.add('points:$aktivitasId:${points.length}');
  }

  @override
  Future<
    ({
      double jarakM,
      int waktuS,
      int streakBerjalan,
      DateTime? streakLast,
    })?
  >
  recomputeStatsRpc({
    required String periode,
    required DateTime weekStartUtc,
    required DateTime weekEndUtc,
    required String activityDay,
  }) async {
    rpcCalls++;
    if (rpcFailuresBeforeSuccess > 0) {
      rpcFailuresBeforeSuccess--;
      throw const SocketException('Temporary RPC drop');
    }
    if (returnNullFromRpc) return null;
    ops.add('rpc:$periode');
    return (
      jarakM: 4200.0,
      waktuS: 1320,
      streakBerjalan: 1,
      streakLast: DateTime.parse(activityDay),
    );
  }

  @override
  Future<void> fallbackApplyStatistikAndStreak({
    required String periode,
    required double jarakM,
    required int waktuS,
    required DateTime activityLocalDate,
  }) async {
    fallbackCalls.add('$periode:$jarakM:$waktuS');
    ops.add('fallback:$periode');
  }

  @override
  Future<void> updateProfile(String userId, Map<String, dynamic> patch) async {
    if (throwOnProfile != null) throw throwOnProfile!;
    ops.add('profile:${patch['nama']}');
  }

  @override
  Future<void> updateLanguage(String userId, String langCode) async {
    if (throwOnLanguage != null) throw throwOnLanguage!;
    ops.add('lang:$langCode');
  }

  @override
  Future<void> joinChallenge(
    String userId,
    String challengeId, {
    String? id,
    DateTime? createdAt,
  }) async {
    ops.add('join:$challengeId');
    joinedCalls.add((
      userId: userId,
      challengeId: challengeId,
      id: id,
      createdAt: createdAt,
    ));
  }

  @override
  Future<void> leaveChallenge(String userId, String challengeId) async {
    ops.add('leave:$challengeId');
  }

  @override
  Future<List<PartisipasiChallenge>?> recomputeChallengeProgressRpc() async {
    challengeRpcCalls++;
    if (returnNullFromChallengeRpc) return null;
    return challengeRpcResult ?? const [];
  }

  @override
  Future<List<PartisipasiChallenge>> fallbackSyncChallengeProgress(
    String userId,
  ) async {
    challengeFallbackCalls.add(userId);
    return challengeFallbackResult;
  }

  @override
  Future<ChatMessage> sendChatMessage({
    required String id,
    required String teamId,
    required String userId,
    required String body,
  }) async {
    ops.add('chat:$id');
    return ChatMessage(
      id: id,
      teamId: teamId,
      userId: userId,
      userNama: 'Tester',
      body: body,
      createdAt: DateTime.utc(2026, 11, 13, 9),
    );
  }
}

void main() {
  late SqliteLocalStore store;
  late ConnectivityService connectivity;
  late _FakeGateway gateway;
  late DateTime now;
  late SyncEngine engine;

  setUp(() async {
    store = await openInMemorySqliteStore();
    await store.setLastUserId('user-sync-1');
    connectivity = ConnectivityService()..setTestOverride(true);
    gateway = _FakeGateway();
    now = DateTime.utc(2026, 11, 13, 9, 0);
    engine = SyncEngine(
      storeProvider: () => store,
      connectivity: connectivity,
      gateway: gateway,
      clock: () => now,
    );
  });

  tearDown(() async {
    engine.dispose();
    connectivity.dispose();
    await store.close();
  });

  group('SyncEngine Outbox Tests', () {
    test('drains queued run, profile, language, challenge, and chat in FIFO order', () async {
      await store.finalizeRunAtomic(
        id: 'run-fifo-1',
        userId: 'user-sync-1',
        jenis: 'lari',
        mulaiAt: DateTime.utc(2026, 11, 13, 7),
        selesaiAt: DateTime.utc(2026, 11, 13, 7, 22),
        durasiS: 1320,
        jarakM: 4200.0,
        allPoints: [
          RutePoint(aktivitasId: 'run-fifo-1', urutan: 0, lat: -6.2, lng: 106.8),
        ],
      );
      await store.queueProfileUpdate('user-sync-1', {'nama': 'Updated Runner'});
      await store.queueLanguageUpdate('user-sync-1', 'en');
      await store.queueJoinChallenge('user-sync-1', 'challenge-99');
      await store.queueChatMessage(
        id: 'chat-fifo-1',
        teamId: 'team-1',
        userId: 'user-sync-1',
        userNama: 'Runner',
        body: 'Morning run done!',
      );

      await engine.syncNow(userId: 'user-sync-1');

      expect(engine.status.pendingCount, 0);
      expect(engine.status.failedCount, 0);
      expect(engine.status.needsReauth, isFalse);

      expect(gateway.ops, [
        'activity:run-fifo-1',
        'points:run-fifo-1:1',
        'rpc:${isoWeekBounds(DateTime.utc(2026, 11, 13, 7)).periode}',
        'profile:Updated Runner',
        'lang:en',
        'join:challenge-99',
        'chat:chat-fifo-1',
      ]);

      final acts = await store.listActivities('user-sync-1');
      expect(acts.first.syncState, SyncState.synced);
      final chat = await store.getChatMessages('user-sync-1', 'team-1');
      expect(chat.first.syncState, SyncState.synced);
    });

    test('retries transient RPC failure with exponential backoff without double-counting', () async {
      await store.finalizeRunAtomic(
        id: 'run-retry-1',
        userId: 'user-sync-1',
        jenis: 'lari',
        mulaiAt: DateTime.utc(2026, 11, 13, 8),
        selesaiAt: DateTime.utc(2026, 11, 13, 8, 20),
        durasiS: 1200,
        jarakM: 3500.0,
        allPoints: const [],
      );

      gateway.rpcFailuresBeforeSuccess = 1;
      await engine.syncNow(userId: 'user-sync-1');

      expect(engine.status.pendingCount, 1);
      expect(engine.status.isOnline, isFalse);

      // Before backoff expires (attempt 0 -> 5s), item is not due yet.
      connectivity.setTestOverride(true);
      await engine.syncNow(userId: 'user-sync-1');
      expect(gateway.rpcCalls, 1);
      expect(engine.status.pendingCount, 1);

      // Advance clock past 5s backoff and sync succeeds.
      now = now.add(SyncEngine.backoffForAttempt(0));
      await engine.syncNow(userId: 'user-sync-1');

      expect(gateway.rpcCalls, 2);
      expect(engine.status.pendingCount, 0);
      final acts = await store.listActivities('user-sync-1');
      expect(acts.single.syncState, SyncState.synced);
      expect(acts.single.statistikApplied, isTrue);
    });

    test('fallback non-RPC path computes baseline and marks synced without duplicates', () async {
      gateway.returnNullFromRpc = true;
      await store.finalizeRunAtomic(
        id: 'run-fallback-1',
        userId: 'user-sync-1',
        jenis: 'lari',
        mulaiAt: DateTime.utc(2026, 11, 13, 6),
        selesaiAt: DateTime.utc(2026, 11, 13, 6, 15),
        durasiS: 900,
        jarakM: 2500.0,
        allPoints: const [],
      );

      await engine.syncNow(userId: 'user-sync-1');
      await engine.syncNow(userId: 'user-sync-1');

      expect(gateway.fallbackCalls.length, 1);
      expect(engine.status.pendingCount, 0);
      final bounds = isoWeekBounds(DateTime.utc(2026, 11, 13, 6));
      final stats = await store.getStatistikEffective('user-sync-1', bounds.periode);
      expect(stats!.jarakM, closeTo(2500.0, 0.01));
      expect(stats.waktuS, 900);
    });

    test('AuthException pauses queue with needsReauth and never loses pending runs', () async {
      await store.finalizeRunAtomic(
        id: 'run-auth-1',
        userId: 'user-sync-1',
        jenis: 'lari',
        mulaiAt: DateTime.utc(2026, 11, 13, 6),
        selesaiAt: DateTime.utc(2026, 11, 13, 6, 10),
        durasiS: 600,
        jarakM: 1800.0,
        allPoints: const [],
      );

      gateway.validSession = false;
      await engine.syncNow(userId: 'user-sync-1');

      expect(engine.status.needsReauth, isTrue);
      expect(engine.status.pendingCount, 1);
      expect(gateway.upsertedActivities, isEmpty);

      // Auth restored mid-flight vs gateway throwing AuthException cleanly:
      gateway.validSession = true;
      gateway.throwOnActivity = const AuthException('JWT expired');
      await engine.syncNow(userId: 'user-sync-1');
      expect(engine.status.needsReauth, isTrue);
      expect(engine.status.pendingCount, 1);

      // Re-authenticated -> sync drains cleanly.
      gateway.throwOnActivity = null;
      await engine.syncNow(userId: 'user-sync-1');
      expect(engine.status.needsReauth, isFalse);
      expect(engine.status.pendingCount, 0);
      expect(gateway.upsertedActivities, ['run-auth-1']);
    });

    test('permanent RLS error marks failing item failed while healthy items still sync', () async {
      await store.queueProfileUpdate('user-sync-1', {'nama': 'Blocked'});
      await store.queueLanguageUpdate('user-sync-1', 'en');
      gateway.throwOnProfile = const PostgrestException(
        message: 'permission denied',
        code: '42501',
      );

      await engine.syncNow(userId: 'user-sync-1');

      expect(engine.status.failedCount, 1);
      expect(engine.status.pendingCount, 0);
      expect(gateway.ops, ['lang:en']);

      // Fixing permission and calling retryFailed re-drains the failed item.
      gateway.throwOnProfile = null;
      await engine.syncNow(userId: 'user-sync-1', retryFailed: true);
      expect(engine.status.failedCount, 0);
      expect(gateway.ops, contains('profile:Blocked'));
    });

    test('offline join + offline workout syncs join createdAt and recomputes challenge progress without double-counting', () async {
      final challenge = Challenge(
        id: 'chal-sync-1',
        jenis: 'lari',
        targetNilai: 5000,
        targetSatuan: 'jarak_m',
        diumumkan: true,
        waktuMulai: DateTime.utc(2026, 11, 1),
        waktuSelesai: DateTime.utc(2026, 11, 30),
      );
      await store.saveChallenges('user-sync-1', [challenge]);
      final localJoin = await store.queueJoinChallenge(
        'user-sync-1',
        'chal-sync-1',
      );
      expect(localJoin.createdAt, isNotNull);

      final runStart = localJoin.createdAt!.toUtc().add(const Duration(minutes: 1));
      final runEnd = runStart.add(const Duration(minutes: 15));
      await store.finalizeRunAtomic(
        id: 'run-chal-sync-1',
        userId: 'user-sync-1',
        jenis: 'lari',
        mulaiAt: runStart,
        selesaiAt: runEnd,
        durasiS: 900,
        jarakM: 3200.0,
        allPoints: const [],
      );

      // Before sync: effective progress reflects pending offline run immediately.
      final beforeSync = await store.getParticipations('user-sync-1');
      expect(beforeSync.length, 1);
      expect(beforeSync.first.progressNilai, closeTo(3200.0, 0.01));
      expect(beforeSync.first.berhasil, isFalse);

      // RPC path returns authoritative server row.
      gateway.challengeRpcResult = [
        PartisipasiChallenge(
          id: localJoin.id,
          challengeId: 'chal-sync-1',
          userId: 'user-sync-1',
          progressNilai: 3200.0,
          berhasil: false,
          createdAt: localJoin.createdAt,
        ),
      ];

      await engine.syncNow(userId: 'user-sync-1');

      expect(engine.status.pendingCount, 0);
      expect(gateway.joinedCalls.length, 1);
      expect(gateway.joinedCalls.first.challengeId, 'chal-sync-1');
      expect(gateway.joinedCalls.first.id, localJoin.id);
      expect(gateway.joinedCalls.first.createdAt, isNotNull);
      expect(gateway.challengeRpcCalls, 1);

      // After sync: no double counting!
      final afterRpc = await store.getParticipations('user-sync-1');
      expect(afterRpc.length, 1);
      expect(afterRpc.first.progressNilai, closeTo(3200.0, 0.01));

      // Fallback path when backend RPC is missing.
      final run2Start = runEnd.add(const Duration(minutes: 5));
      final run2End = run2Start.add(const Duration(minutes: 10));
      await store.finalizeRunAtomic(
        id: 'run-chal-sync-2',
        userId: 'user-sync-1',
        jenis: 'lari',
        mulaiAt: run2Start,
        selesaiAt: run2End,
        durasiS: 600,
        jarakM: 2000.0,
        allPoints: const [],
      );
      gateway.returnNullFromChallengeRpc = true;
      gateway.challengeFallbackResult = [
        PartisipasiChallenge(
          id: localJoin.id,
          challengeId: 'chal-sync-1',
          userId: 'user-sync-1',
          progressNilai: 5200.0,
          berhasil: true,
          createdAt: localJoin.createdAt,
        ),
      ];

      await engine.syncNow(userId: 'user-sync-1');
      expect(gateway.challengeFallbackCalls, ['user-sync-1']);
      final afterFallback = await store.getParticipations('user-sync-1');
      expect(afterFallback.single.progressNilai, closeTo(5200.0, 0.01));
      expect(afterFallback.single.berhasil, isTrue);
    });
  });
}
