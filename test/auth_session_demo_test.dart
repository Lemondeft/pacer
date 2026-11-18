import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/auth/auth_repository.dart';
import 'package:pacer/src/auth/user_model.dart';
import 'package:pacer/src/cache/pacer_cache.dart';
import 'package:pacer/src/demo/pacer_dummy_data.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/memory_local_store.dart';
import 'package:pacer/src/local/store_factory_io.dart';
import 'package:pacer/src/local/swr_helper.dart';
import 'package:pacer/src/notifications/notification_repository.dart';
import 'package:pacer/src/sync/connectivity_service.dart';
import 'package:pacer/src/sync/sync_engine.dart';
import 'package:pacer/src/tracking/recorder.dart';
import 'package:pacer/src/ui/app_strings.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/more_screens.dart';
import 'package:pacer/src/ui/screens.dart';

void main() {
  late MemoryLocalStore memStore;

  setUp(() async {
    memStore = MemoryLocalStore();
    LocalStore.instance = memStore;
    PacerCache.instance.clear();
    PacerDummyData.resetDemoTeams();
    NotificationRepository.resetSession();
    SyncEngine.instance.resetSession();
    ConnectivityService.instance.reportReachable(false);
    langNotifier.value = Lang.en;
  });

  tearDown(() async {
    LocalStore.instance = MemoryLocalStore();
    PacerCache.instance.clear();
    PacerDummyData.resetDemoTeams();
    NotificationRepository.resetSession();
    SyncEngine.instance.resetSession();
    ConnectivityService.instance.reportReachable(true);
    langNotifier.value = Lang.id;
  });

  group('Logout session refresh & auth flow navigation', () {
    test('AuthRepository.signOut clears cache, notifications, sync state, lastUserId, and increments epochs', () async {
      await memStore.setLastUserId('user-123');
      await memStore.upsertProfile(
        const UserProfile(id: 'user-123', nama: 'Runner A', peran: 'admin'),
      );
      PacerCache.instance.set('auth_profile_user-123', 'stale');
      NotificationRepository.unreadCountNotifier.value = 4;
      PacerDummyData.recordDemoActivity(
        Activity(
          id: 'custom-demo-1',
          userId: PacerDummyData.demoUserId,
          jenis: 'lari',
          durasiS: 600,
          jarakM: 1800,
        ),
      );

      final beforeSession = AuthRepository.sessionEpoch.value;
      final beforeSignOut = AuthRepository.signOutEpoch.value;

      await AuthRepository(store: memStore).signOut();

      expect(await memStore.getLastUserId(), isNull);
      expect(PacerCache.instance.get<String>('auth_profile_user-123'), isNull);
      expect(NotificationRepository.unreadCountNotifier.value, 0);
      expect(SyncEngine.instance.status.pendingCount, 0);
      expect(SyncEngine.instance.status.needsReauth, isFalse);
      expect(
        PacerDummyData.demoActivities.any((a) => a.id == 'custom-demo-1'),
        isFalse,
      );
      expect(AuthRepository.sessionEpoch.value, beforeSession + 1);
      expect(AuthRepository.signOutEpoch.value, beforeSignOut + 1);
    });

    testWidgets('Standalone AccountScreen Sign Out navigates to interactive GetStartedScreen -> LoginScreen without dead BuildContext crash', (tester) async {
      tester.view.physicalSize = const Size(720, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await memStore.setLastUserId('user-1');
      await memStore.upsertProfile(
        const UserProfile(id: 'user-1', nama: 'Siti', peran: 'user'),
      );

      await tester.pumpWidget(
        MaterialApp(theme: PacerTheme.light(), home: const AccountScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Siti'), findsOneWidget);

      final signOutBefore = AuthRepository.signOutEpoch.value;
      await tester.tap(find.text(S.out));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(AuthRepository.signOutEpoch.value, signOutBefore + 1);
      expect(find.byType(AccountScreen), findsNothing);
      expect(find.byType(MainShell), findsNothing);
      expect(find.byType(GetStartedScreen), findsOneWidget);
      expect(find.text(S.tryDemoAccount), findsOneWidget);

      // Previously threw Null check operator on unmounted _AccountScreenState context
      // and skipped LoginScreen altogether.
      await tester.tap(find.text(S.logIn));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(S.tryDemoAccount), findsOneWidget);
    });

    testWidgets('PacerAuthFlow supports Try Demo Account offline from GetStartedScreen & LoginScreen, then clean Sign Out -> Log In', (tester) async {
      tester.view.physicalSize = const Size(720, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: const PacerAuthFlow(startWithSplash: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GetStartedScreen), findsOneWidget);
      await tester.tap(find.text(S.tryDemoAccount));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MainShell), findsOneWidget);

      // Open Account from Home (initials AW for seeded andi_wijaya) and sign out.
      await tester.tap(find.text('AW'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountScreen), findsOneWidget);
      expect(find.text('andi_wijaya'), findsOneWidget);
      expect(find.text(S.demoModeSubtitle), findsOneWidget);
      expect(await memStore.getLastUserId(), demoSandboxUserId);

      final signOutBefore = AuthRepository.signOutEpoch.value;
      await tester.tap(find.text(S.out));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(AuthRepository.signOutEpoch.value, signOutBefore + 1);
      expect(await memStore.getLastUserId(), isNull);
      expect(await memStore.getProfile(demoSandboxUserId), isNull);
      expect(await memStore.listActivities(demoSandboxUserId), isEmpty);
      expect(await memStore.getTeams(demoSandboxUserId), isEmpty);
      expect(await memStore.getNotifications(demoSandboxUserId), isEmpty);
      expect(find.byType(AccountScreen), findsNothing);
      expect(find.byType(MainShell), findsNothing);
      expect(find.byType(GetStartedScreen), findsOneWidget);

      // Enter Demo Mode via LoginScreen's Demo Account button as well.
      await tester.tap(find.text(S.logIn));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      await tester.tap(find.text(S.tryDemoAccount));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MainShell), findsOneWidget);
      expect(await memStore.getProfile(demoSandboxUserId), isNotNull);
    });
  });

  group('SQLite Demo Sandbox isolation vs Offline Mode', () {
    test('Demo Account persists local SQLite edits without outbox, wipes on signOut, and preserves Offline Mode data', () async {
      final sqlStore = await openInMemorySqliteStore();
      addTearDown(sqlStore.close);

      // Seed real Offline Mode data for an actual user.
      const realUid = 'real-user-1';
      await sqlStore.upsertProfile(
        const UserProfile(id: realUid, nama: 'real_runner', peran: 'user'),
      );
      await sqlStore.finalizeRunAtomic(
        id: 'real-act-1',
        userId: realUid,
        jenis: 'lari',
        mulaiAt: DateTime.now().toUtc().subtract(const Duration(minutes: 15)),
        selesaiAt: DateTime.now().toUtc(),
        durasiS: 900,
        jarakM: 3200,
        allPoints: const [],
      );

      await AuthRepository.prepareDemoSession(store: sqlStore, language: 'en');
      expect(await sqlStore.getLastUserId(), demoSandboxUserId);
      final demoProfile = await sqlStore.getProfile(demoSandboxUserId);
      expect(demoProfile?.nama, 'andi_wijaya');
      expect(await sqlStore.listActivities(demoSandboxUserId), isNotEmpty);
      expect(await sqlStore.getTeams(demoSandboxUserId), isNotEmpty);
      expect(await sqlStore.getChallenges(demoSandboxUserId), isNotEmpty);
      expect(await sqlStore.getPendingOutboxCount(demoSandboxUserId), 0);

      // Simulate an in-demo run recorded directly to SQLite.
      final recorder = RunRecorder(store: sqlStore);
      addTearDown(recorder.dispose);
      await recorder.simulate('lari');
      final summary = await recorder.finish();
      expect(summary, isNotNull);
      expect(await sqlStore.getPendingOutboxCount(demoSandboxUserId), 0);
      expect(
        (await sqlStore.listActivities(demoSandboxUserId)).any(
          (a) => a.activity.id == summary!.aktivitasId,
        ),
        isTrue,
      );

      // Logout wipes ALL demo sandbox data but keeps Offline Mode user intact.
      await AuthRepository(store: sqlStore).signOut();
      expect(await sqlStore.getLastUserId(), isNull);
      expect(await sqlStore.getProfile(demoSandboxUserId), isNull);
      expect(await sqlStore.listActivities(demoSandboxUserId), isEmpty);
      expect(await sqlStore.getTeams(demoSandboxUserId), isEmpty);
      expect(await sqlStore.getChallenges(demoSandboxUserId), isEmpty);
      expect(await sqlStore.getNotifications(demoSandboxUserId), isEmpty);

      final retainedRealProfile = await sqlStore.getProfile(realUid);
      final retainedRealActs = await sqlStore.listActivities(realUid);
      expect(retainedRealProfile?.nama, 'real_runner');
      expect(retainedRealActs.single.activity.id, 'real-act-1');
      expect(await sqlStore.getPendingOutboxCount(realUid), 1);
    });
  });

  group('Sign-up username validation', () {
    testWidgets('CreateAccountScreen requires non-empty username with no spaces', (tester) async {
      tester.view.physicalSize = const Size(720, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var submitted = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: CreateAccountScreen(
            onBack: () {},
            onSubmitted: () => submitted = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), 'user@example.com');
      await tester.enterText(find.byType(TextField).at(2), 'secret123');
      await tester.enterText(find.byType(TextField).at(3), 'secret123');

      await tester.tap(find.text(S.signIn));
      await tester.pumpAndSettle();
      expect(submitted, isFalse);
      expect(find.text(S.errUsernameRequired), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'andi wijaya');
      await tester.tap(find.text(S.signIn));
      await tester.pumpAndSettle();
      expect(submitted, isFalse);
      expect(find.text(S.errUsernameNoSpaces), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'ab');
      await tester.tap(find.text(S.signIn));
      await tester.pumpAndSettle();
      expect(submitted, isFalse);
      expect(find.text(S.errUsernameTooShort), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'andi_wijaya');
      await tester.tap(find.text(S.signIn));
      await tester.pumpAndSettle();
      expect(submitted, isTrue);
    });

    test('AuthRepository.signUp rejects empty or spaced usernames', () async {
      final auth = AuthRepository(store: memStore);
      await expectLater(
        () => auth.signUp(
          email: 'a@b.com',
          password: 'password123',
          nama: '   ',
        ),
        throwsArgumentError,
      );
      await expectLater(
        () => auth.signUp(
          email: 'a@b.com',
          password: 'password123',
          nama: 'andi wijaya',
        ),
        throwsArgumentError,
      );
    });
  });

  group('Demo Account offline workout recording', () {
    test('RunRecorder.simulate + finish works offline in Demo Mode without outbox side effects', () async {
      final recorder = RunRecorder(store: memStore);
      addTearDown(recorder.dispose);

      await recorder.simulate('lari');
      final summary = await recorder.finish();

      expect(summary, isNotNull);
      expect(summary!.jenis, 'lari');
      expect(
        await memStore.getPendingOutboxCount(PacerDummyData.demoUserId),
        0,
      );
      expect(
        await memStore.loadActiveDraft(PacerDummyData.demoUserId),
        isNull,
      );

      final demoAct = Activity(
        id: summary.aktivitasId,
        userId: PacerDummyData.demoUserId,
        jenis: summary.jenis,
        durasiS: summary.durasiS,
        jarakM: summary.jarakM,
      );
      PacerDummyData.recordDemoActivity(demoAct);
      expect(PacerDummyData.demoActivities.first.id, summary.aktivitasId);
    });
  });
}
