import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pacer/src/aktivitas/activity_repository.dart';
import 'package:pacer/src/auth/auth_repository.dart';
import 'package:pacer/src/auth/user_model.dart';
import 'package:pacer/src/cache/pacer_cache.dart';
import 'package:pacer/src/demo/pacer_dummy_data.dart';
import 'package:pacer/src/local/local_models.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/memory_local_store.dart';
import 'package:pacer/src/local/sqlite_local_store.dart';
import 'package:pacer/src/local/store_factory_io.dart';
import 'package:pacer/src/sync/connectivity_service.dart';
import 'package:pacer/src/sync/sync_engine.dart';
import 'package:pacer/src/tracking/recorder.dart';
import 'package:pacer/src/ui/app_strings.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/coach_board.dart';
import 'package:pacer/src/ui/more_screens.dart';
import 'package:pacer/src/ui/screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

Position _pos(double lat, double lng, {double accuracy = 5}) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime.utc(2026, 11, 13, 7),
  accuracy: accuracy,
  altitude: 10,
  altitudeAccuracy: 3,
  heading: 0,
  headingAccuracy: 1,
  speed: 3.0,
  speedAccuracy: 0.5,
);

void main() {
  const uid = 'uid-offline-runner';

  group('Offline RunRecorder + Real SQLite Persistence', () {
    late SqliteLocalStore sqliteStore;

    setUp(() async {
      PacerCache.instance.clear();
      sqliteStore = await openInMemorySqliteStore();
      await sqliteStore.setLastUserId(uid);
      LocalStore.instance = sqliteStore;
      ConnectivityService.instance.setTestOverride(false);
    });

    tearDown(() async {
      ConnectivityService.instance.setTestOverride(null);
      LocalStore.instance = MemoryLocalStore();
      PacerCache.instance.clear();
      await sqliteStore.close();
    });

    test('completes full offline run, checkpoints draft, saves route, and enqueues outbox', () async {
      final recorder = RunRecorder(store: sqliteStore, userIdProvider: () async => uid);

      await recorder.simulate();
      recorder.pause(); // Stop periodic sim timer before deterministic test fixes.
      recorder.recordPositionForTest(_pos(-6.2000, 106.8000));
      recorder.recordPositionForTest(_pos(-6.2010, 106.8000));
      recorder.recordPositionForTest(_pos(-6.2020, 106.8000, accuracy: 45)); // Filtered (> 20m)
      recorder.recordPositionForTest(_pos(-6.2020, 106.8010));
      recorder.recordPositionForTest(_pos(-6.2030, 106.8010));
      recorder.recordPositionForTest(_pos(-6.2040, 106.8020));
      recorder.recordPositionForTest(_pos(-6.2050, 106.8030));

      expect(recorder.pointCount, 6);
      expect(recorder.distanceM, greaterThan(400));

      recorder.pause();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final draft = await sqliteStore.loadActiveDraft(uid);
      expect(draft, isNotNull);
      expect(draft!.points.length, 6);

      final summary = await recorder.finish();
      recorder.dispose();

      expect(summary, isNotNull);
      expect(summary!.pointCount, 6);
      expect(await sqliteStore.loadActiveDraft(uid), isNull);

      final repo = ActivityRepository(store: sqliteStore);
      final localActs = await repo.listLocalActivities();
      expect(localActs.length, 1);
      expect(localActs.single.activity.id, summary.aktivitasId);
      expect(localActs.single.syncState, SyncState.pending);

      final routePts = await repo.getRoute(summary.aktivitasId);
      expect(routePts.length, 6);
      expect(await sqliteStore.getPendingOutboxCount(uid), 1);
    });
  });

  group('Authenticated Offline UI Tests (LocalStore SSOT, No Dummy Fallbacks)', () {
    late MemoryLocalStore memStore;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      langNotifier.value = Lang.en;
      langUserLocked = false;
      PacerCache.instance.clear();
      memStore = MemoryLocalStore();
      await memStore.setLastUserId(uid);
      await memStore.upsertProfile(
        const UserProfile(
          id: uid,
          nama: 'Dewi Sartika',
          peran: 'user',
          region: 'Bandung',
        ),
        language: 'en',
        email: 'dewi@pacer.id',
      );
      LocalStore.instance = memStore;
      ConnectivityService.instance.setTestOverride(false);
      await SyncEngine.instance.refreshCounts(userId: uid);
    });

    tearDown(() async {
      ConnectivityService.instance.setTestOverride(null);
      LocalStore.instance = MemoryLocalStore();
      PacerCache.instance.clear();
    });

    testWidgets('Signed-in empty offline HomeScreen, HistoryScreen, StatisticScreen, StreaksScreen never fall back to dummy data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: PacerTheme.light(), home: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('PD'), findsNothing);
      expect(find.text(PacerDummyData.teams.first.nama), findsNothing);
      expect(find.textContaining('Offline mode'), findsOneWidget);
      expect(find.text(S.noRunsOfflineEmpty), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(theme: PacerTheme.light(), home: const HistoryScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text(S.noRunsOfflineEmpty), findsOneWidget);
      expect(find.text('12/03/2026'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(theme: PacerTheme.light(), home: const StatisticScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('0,00 Km'), findsOneWidget);
      expect(find.text('45.20 Km'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(theme: PacerTheme.light(), home: const StreaksScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('45.20'), findsNothing);
      expect(find.text('0.00'), findsOneWidget);
    });

    testWidgets('Recording an offline run updates HomeScreen, HistoryScreen, StatisticScreen, StreaksScreen, and AboutMeScreen from real local SSOT', (tester) async {
      final now = DateTime.now();
      await memStore.finalizeRunAtomic(
        id: 'offline-ui-run-1',
        userId: uid,
        jenis: 'lari',
        mulaiAt: now.subtract(const Duration(minutes: 25)).toUtc(),
        selesaiAt: now.toUtc(),
        durasiS: 1500,
        jarakM: 4200.0,
        allPoints: const [],
      );
      await SyncEngine.instance.refreshCounts(userId: uid);

      await tester.pumpWidget(
        MaterialApp(theme: PacerTheme.light(), home: const HomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('DS'), findsOneWidget);
      expect(find.text('4.20 Km'), findsOneWidget);
      expect(find.text(S.syncChipLocal), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(theme: PacerTheme.light(), home: const HistoryScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('4.20 Km'), findsWidgets);
      expect(find.text(S.syncChipLocal), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(theme: PacerTheme.light(), home: const StatisticScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('4.20'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(theme: PacerTheme.light(), home: const AboutMeScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dewi Sartika'), findsOneWidget);
      expect(find.text('Pacer Demo'), findsNothing);
    });

    testWidgets('LanguageSettingsScreen queues language offline without failure snackbar and AccountScreen warns before signing out with pending sync', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.light(),
          home: const LanguageSettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bahasa Indonesia'));
      await tester.pumpAndSettle();

      expect(langNotifier.value, Lang.id);
      expect(find.text(S.langSaveFailed), findsNothing);
      expect(await AuthRepository(store: memStore).getLanguage(), 'id');
      expect(await memStore.getPendingOutboxCount(uid), 1);

      await SyncEngine.instance.refreshCounts(userId: uid);
      await tester.pumpWidget(
        MaterialApp(theme: PacerTheme.light(), home: const AccountScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dewi Sartika'), findsOneWidget);

      await tester.tap(find.text(S.out));
      await tester.pumpAndSettle();

      expect(find.text(S.unsyncedSignOutTitle), findsOneWidget);
      expect(find.text(S.signOutAnyway), findsOneWidget);
    });

    testWidgets('Non-coach signed-in offline CoachBoardScreen stays denied rather than leaking demo coach rows', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: PacerTheme.light(), home: const CoachBoardScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text(PacerDummyData.coachDummyRows.first.nama), findsNothing);
    });
  });
}
