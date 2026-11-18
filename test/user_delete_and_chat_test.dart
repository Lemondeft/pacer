import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/challenge/challenge_model.dart';
import 'package:pacer/src/chat/chat_model.dart';
import 'package:pacer/src/demo/pacer_dummy_data.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/memory_local_store.dart';
import 'package:pacer/src/local/sqlite_local_store.dart';
import 'package:pacer/src/local/store_factory_io.dart';
import 'package:pacer/src/notifications/notification_model.dart';
import 'package:pacer/src/notifications/notification_repository.dart';
import 'package:pacer/src/sync/connectivity_service.dart';
import 'package:pacer/src/sync/sync_engine.dart';
import 'package:pacer/src/ui/app_strings.dart';
import 'package:pacer/src/ui/more_screens.dart';

class _TestSyncGateway implements RemoteSyncGateway {
  @override
  String? currentUserId = 'user-del-1';

  final List<String> deletedActivityIds = [];
  final List<String> deletedChatIds = [];

  @override
  Future<bool> ensureValidSession() async => true;

  @override
  Future<void> upsertActivity(Activity activity) async {}

  @override
  Future<void> upsertRoutePoints(String id, List<RutePoint> points) async {}

  @override
  Future<
    ({double jarakM, int waktuS, int streakBerjalan, DateTime? streakLast})?
  >
  recomputeStatsRpc({
    required String periode,
    required DateTime weekStartUtc,
    required DateTime weekEndUtc,
    required String activityDay,
  }) async => null;

  @override
  Future<void> fallbackApplyStatistikAndStreak({
    required String periode,
    required double jarakM,
    required int waktuS,
    required DateTime activityLocalDate,
    bool applyStats = true,
    bool applyStreak = true,
  }) async {}

  @override
  Future<void> updateProfile(String userId, Map<String, dynamic> patch) async {}

  @override
  Future<void> updateLanguage(String userId, String langCode) async {}

  @override
  Future<void> joinChallenge(
    String userId,
    String challengeId, {
    String? id,
    DateTime? createdAt,
  }) async {}

  @override
  Future<List<PartisipasiChallenge>?> recomputeChallengeProgressRpc() async =>
      null;

  @override
  Future<List<PartisipasiChallenge>> fallbackSyncChallengeProgress(
    String userId,
  ) async => const [];

  @override
  Future<List<PartisipasiChallenge>?> activateChallengeRpc(
    String challengeId,
  ) async => null;

  @override
  Future<void> leaveChallenge(String userId, String challengeId) async {}

  @override
  Future<({String? validationStatus, String? suggestedSport})?>
  validateActivityFunction(String aktivitasId) async => null;

  @override
  Future<ChatMessage> sendChatMessage({
    required String id,
    required String teamId,
    required String userId,
    required String body,
  }) async => ChatMessage(
    id: id,
    teamId: teamId,
    userId: userId,
    body: body,
    createdAt: DateTime.now().toUtc(),
  );

  @override
  Future<void> deleteActivity(String userId, String aktivitasId) async {
    deletedActivityIds.add(aktivitasId);
  }

  @override
  Future<void> deleteChatMessage(String userId, String messageId) async {
    deletedChatIds.add(messageId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline-first deletion + outbox + resurrection guards', () {
    late SqliteLocalStore sqlite;

    setUp(() async {
      sqlite = await openInMemorySqliteStore();
      await sqlite.setLastUserId('user-del-1');
    });

    tearDown(() async {
      await sqlite.close();
    });

    test(
      'queueDeleteActivityLocal prevents mergeRemoteActivities resurrection and drains outbox',
      () async {
        const uid = 'user-del-1';
        final remoteRun = Activity(
          id: 'act-remote-1',
          userId: uid,
          jenis: 'lari',
          mulaiAt: DateTime.utc(2026, 11, 18, 6, 0),
          selesaiAt: DateTime.utc(2026, 11, 18, 6, 30),
          durasiS: 1800,
          jarakM: 5000,
        );
        await sqlite.mergeRemoteActivities(uid, [remoteRun]);
        await sqlite.queueDeleteActivityLocal(uid, 'act-remote-1');

        expect(await sqlite.listActivities(uid), isEmpty);

        // Remote SWR refresh while delete is pending must not resurrect it.
        await sqlite.mergeRemoteActivities(uid, [remoteRun]);
        expect(await sqlite.listActivities(uid), isEmpty);

        final gw = _TestSyncGateway();
        final conn = ConnectivityService()..setTestOverride(true);
        final engine = SyncEngine(
          storeProvider: () => sqlite,
          connectivity: conn,
          gateway: gw,
        );
        await engine.triggerSync(userId: uid);
        engine.dispose();

        expect(gw.deletedActivityIds, ['act-remote-1']);
        expect(await sqlite.getPendingOutboxCount(uid), 0);
      },
    );

    test(
      'MemoryLocalStore chat delete cancels pending send or queues delete_chat',
      () async {
        final mem = MemoryLocalStore();
        const uid = 'user-del-1';
        await mem.setLastUserId(uid);
        await mem.queueChatMessage(
          id: 'unsynced-1',
          teamId: 'team-1',
          userId: uid,
          userNama: 'Ahmad',
          body: 'draft msg',
        );
        await mem.deleteChatMessageLocal(uid, 'unsynced-1');
        expect(await mem.getChatMessages(uid, 'team-1'), isEmpty);
        expect(await mem.getPendingOutboxCount(uid), 0);

        final syncedMsg = ChatMessage(
          id: 'synced-1',
          teamId: 'team-1',
          userId: uid,
          userNama: 'Ahmad',
          body: 'hello team',
          createdAt: DateTime.utc(2026, 11, 18, 10),
        );
        await mem.mergeChatMessages(uid, 'team-1', [syncedMsg]);
        await mem.deleteChatMessageLocal(uid, 'synced-1');
        expect(await mem.getChatMessages(uid, 'team-1'), isEmpty);

        // Protected against stale remote fetch while delete is pending.
        await mem.mergeChatMessages(uid, 'team-1', [syncedMsg]);
        expect(await mem.getChatMessages(uid, 'team-1'), isEmpty);

        final gw = _TestSyncGateway();
        final conn = ConnectivityService()..setTestOverride(true);
        final engine = SyncEngine(
          storeProvider: () => mem,
          connectivity: conn,
          gateway: gw,
        );
        await engine.triggerSync(userId: uid);
        engine.dispose();

        expect(gw.deletedChatIds, ['synced-1']);
      },
    );

    test('Notification delete and clearAll work on SqliteLocalStore', () async {
      const uid = 'user-del-1';
      await sqlite.saveNotifications(uid, [
        AppNotification(
          id: 'n1',
          userId: uid,
          type: 'team_challenge',
          title: 'Challenge 1',
          body: 'Body 1',
          isRead: false,
          createdAt: DateTime.utc(2026, 11, 18, 8),
        ),
        AppNotification(
          id: 'n2',
          userId: uid,
          type: 'team_role',
          title: 'Role',
          body: 'Body 2',
          isRead: true,
          createdAt: DateTime.utc(2026, 11, 18, 9),
        ),
      ]);
      await sqlite.deleteNotificationLocal(uid, 'n1');
      final remaining = await sqlite.getNotifications(uid);
      expect(remaining.map((e) => e.id).toList(), ['n2']);

      await sqlite.clearNotificationsLocal(uid);
      expect(await sqlite.getNotifications(uid), isEmpty);
    });
  });

  group('ChatScreen sender visibility & own message delete UI', () {
    testWidgets(
      'shows incoming sender name & avatar and supports deleting own message',
      (tester) async {
        langNotifier.value = Lang.en;
        final mem = MemoryLocalStore();
        LocalStore.instance = mem;
        await PacerDummyData.seedIntoStore(mem);
        NotificationRepository.resetSession();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const ChatScreen(teamName: 'Morning Run'),
          ),
        );
        await tester.pumpAndSettle();

        // Incoming dummy sender visible near bottom of list.
        expect(find.text('farhan_ramadhan'), findsWidgets);

        // Send own message.
        await tester.enterText(
          find.byType(TextField),
          'Checking bubble visibility',
        );
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        expect(find.text('Checking bubble visibility'), findsOneWidget);
        expect(find.text(S.youLabel), findsWidgets);

        // Long press own message -> delete dialog -> delete.
        await tester.longPress(find.text('Checking bubble visibility'));
        await tester.pumpAndSettle();
        expect(find.text(S.deleteMessageTitle), findsOneWidget);

        await tester.tap(find.text(S.deleteAction));
        await tester.pumpAndSettle();
        expect(find.text('Checking bubble visibility'), findsNothing);

        LocalStore.instance = MemoryLocalStore();
        langNotifier.value = Lang.id;
      },
    );
  });
}
