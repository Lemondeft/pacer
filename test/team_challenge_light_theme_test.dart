import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/demo/pacer_dummy_data.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/memory_local_store.dart';
import 'package:pacer/src/local/store_factory_io.dart';
import 'package:pacer/src/notifications/notification_model.dart';
import 'package:pacer/src/notifications/notification_repository.dart';
import 'package:pacer/src/ui/app_strings.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/coach_board.dart';
import 'package:pacer/src/ui/more_screens.dart';
import 'package:pacer/src/ui/screens.dart';
import 'package:pacer/src/ui/widgets.dart';

void main() {
  setUp(() {
    PacerDummyData.resetDemoTeams();
    NotificationRepository.resetBannerDismissals();
    NotificationRepository.syncDemoUnread();
  });

  tearDown(() {
    langNotifier.value = Lang.id;
    PacerDummyData.resetDemoTeams();
    NotificationRepository.resetBannerDismissals();
    NotificationRepository.syncDemoUnread();
  });

  group('Independent Activity Auto-Selection & Opt-In', () {
    testWidgets(
      'RunSetupScreen auto-selects matching Team and Solo challenges and honors opt-out toggles',
      (tester) async {
        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        String? capturedSport;
        List<String>? capturedChallengeIds;

        await tester.pumpWidget(
          MaterialApp(
            theme: PacerTheme.light(),
            home: Scaffold(
              body: RunSetupScreen(
                onStartWithChallenges: (sport, _, challengeIds) {
                  capturedSport = sport;
                  capturedChallengeIds = challengeIds;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(S.activeChallengesForSport), findsOneWidget);
        expect(find.text('Target Lari Mingguan Tim'), findsOneWidget);
        expect(find.byType(Switch), findsNWidgets(2));

        // Turn off the second active challenge (solo), keeping team challenge ON.
        await tester.tap(find.byType(Switch).last);
        await tester.pumpAndSettle();

        await tester.tap(find.text(S.startRun));
        await tester.pumpAndSettle();

        expect(capturedSport, 'lari');
        expect(capturedChallengeIds, isNotNull);
        expect(capturedChallengeIds, ['chal-team-001']);
      },
    );
  });

  group('Team Challenges, Slot Activation & Filters UI', () {
    testWidgets(
      'TeamDashboardScreen shows Team Challenges and switches active waiting slot',
      (tester) async {
        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // Promote demo user to ketua on team-1 so create CTA also appears.
        PacerDummyData.setDemoMemberRole(
          '11111111-1111-1111-1111-111111111111',
          'demo-user-me',
          'ketua',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: PacerTheme.light(),
            home: const TeamDashboardScreen(
              teamId: '11111111-1111-1111-1111-111111111111',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(S.teamChallengesHeading), findsOneWidget);
        expect(find.text(S.createTeamChallenge), findsOneWidget);
        expect(find.text('Target Lari Mingguan Tim'), findsOneWidget);
        expect(find.text('Challenge Endurance 10K'), findsOneWidget);
        expect(find.text(S.chooseActiveChallenge), findsOneWidget);

        // Activate waiting Coach challenge chal-team-002.
        await tester.ensureVisible(find.text(S.chooseActiveChallenge));
        await tester.tap(find.text(S.chooseActiveChallenge));
        await tester.pumpAndSettle();

        final parts = {
          for (final p in PacerDummyData.getDemoParticipations())
            p.challengeId: p,
        };
        expect(parts['chal-team-002']!.isActive, isTrue);
        expect(parts['chal-team-001']!.isActive, isFalse);
        expect(parts['chal-001']!.isActive, isTrue); // Solo remains active.
      },
    );

    testWidgets(
      'ChallengeListScreen filters between Semua, Tim Coach, and Mandiri',
      (tester) async {
        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: PacerTheme.light(),
            home: const ChallengeListScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.widgetWithText(GoalChip, S.filterAll), findsOneWidget);
        expect(find.widgetWithText(GoalChip, S.filterTeam), findsOneWidget);
        expect(find.widgetWithText(GoalChip, S.filterSolo), findsOneWidget);
        expect(find.text('Target Lari Mingguan Tim'), findsOneWidget);

        await tester.tap(find.widgetWithText(GoalChip, S.filterSolo));
        await tester.pumpAndSettle();
        expect(find.text('Target Lari Mingguan Tim'), findsNothing);

        await tester.tap(find.widgetWithText(GoalChip, S.filterTeam));
        await tester.pumpAndSettle();
        expect(find.text('Target Lari Mingguan Tim'), findsOneWidget);
        expect(find.text('Challenge Endurance 10K'), findsOneWidget);
      },
    );

    testWidgets(
      'CreateChallengeScreen creates Team Challenge in demo mode with custom title',
      (tester) async {
        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: PacerTheme.light(),
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => const CreateChallengeScreen(
                  initialTeamId: '11111111-1111-1111-1111-111111111111',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(S.challengeScopeLabel), findsOneWidget);
        expect(find.text(S.createTeamChallenge), findsWidgets);

        await tester.enterText(
          find.byType(TextField),
          'Sprint Akhir Pekan',
        );
        await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, S.createTeamChallenge),
        );
        await tester.tap(
          find.widgetWithText(ElevatedButton, S.createTeamChallenge),
        );
        await tester.pumpAndSettle();

        expect(
          PacerDummyData.demoChallenges.any(
            (c) =>
                c.judul == 'Sprint Akhir Pekan' &&
                c.teamId == '11111111-1111-1111-1111-111111111111',
          ),
          isTrue,
        );
      },
    );
  });

  group('Notifications Inbox & HomeScreen Banner', () {
    testWidgets(
      'HomeScreen in light theme displays unread bell badge and dismissible assigned challenge banner',
      (tester) async {
        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: PacerTheme.light(),
            home: const Scaffold(body: HomeScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final bannerFinder = find.byKey(const ValueKey('assigned_challenge_banner'));
        expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
        expect(find.text('2'), findsWidgets);
        expect(bannerFinder, findsOneWidget);
        expect(
          find.descendant(
            of: bannerFinder,
            matching: find.text('Challenge Tim · GBK Runners Elite'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: bannerFinder,
            matching: find.textContaining('Target Lari Mingguan Tim'),
          ),
          findsOneWidget,
        );

        // Dismiss first assigned challenge banner -> reveals second unread banner.
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: bannerFinder,
            matching: find.textContaining('Target Lari Mingguan Tim'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: bannerFinder,
            matching: find.textContaining('Challenge Endurance 10K'),
          ),
          findsOneWidget,
        );

        // Dismiss second unread banner -> banner hides completely.
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(bannerFinder, findsNothing);
      },
    );

    test('NotificationRepository offline store updates unread counts and read status', () async {
      final sqlite = await openInMemorySqliteStore();
      LocalStore.instance = sqlite;
      try {
        await sqlite.saveNotifications('u-notif', [
          const AppNotification(
            id: 'n1',
            userId: 'u-notif',
            type: 'team_challenge_assigned',
            title: 'Tantangan 5K Tim',
            body: 'Coach menetapkan tantangan tim baru',
            challengeId: 'c1',
            teamId: 't1',
            isRead: false,
          ),
          const AppNotification(
            id: 'n2',
            userId: 'u-notif',
            type: 'team_role_changed',
            title: 'Peran Diperbarui',
            body: 'Kamu diangkat menjadi Ketua',
            teamId: 't1',
            isRead: true,
          ),
        ]);

        await sqlite.markNotificationReadLocal('u-notif', 'n1');
        final after = await sqlite.getNotifications('u-notif');
        expect(after.every((n) => n.isRead), isTrue);
      } finally {
        LocalStore.instance = MemoryLocalStore();
        await sqlite.close();
      }
    });
  });

  group('Challenge Creation Custom Duration, Team Scoping & Language Consistency', () {
    testWidgets(
      'CreateChallengeScreen unifies distance target, supports custom duration (days), and excludes non-joined teams',
      (tester) async {
        langNotifier.value = Lang.en;
        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: PacerTheme.dark(),
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => const CreateChallengeScreen(
                  initialTeamId: '11111111-1111-1111-1111-111111111111',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Unified Distance Target in English (no leftover Indonesian 'JARAK').
        expect(find.text('JARAK'), findsNothing);
        expect(find.text('DISTANCE TARGET'), findsOneWidget);
        expect(find.text('TARGET'), findsNothing);

        // Team dropdown only lists teams the user belongs to, not unjoined clubs.
        expect(find.text('GBK Runners Elite'), findsOneWidget);
        expect(find.text('Monas Morning Joggers'), findsNothing);

        // Pick Custom Duration -> enter 14 days.
        final customChips = find.text(S.custom);
        expect(customChips, findsNWidgets(2));
        await tester.ensureVisible(customChips.last);
        await tester.tap(customChips.last);
        await tester.pumpAndSettle();

        expect(find.text(S.customDurationTitle), findsOneWidget);
        await tester.enterText(find.byType(TextField).last, '14');
        await tester.tap(find.text(S.saveLabel));
        await tester.pumpAndSettle();

        expect(find.text('Custom (14 Days)'), findsOneWidget);

        await tester.enterText(
          find.byType(TextField).first,
          'Sprint 14 Hari Kustom',
        );
        await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, S.createTeamChallenge),
        );
        await tester.tap(
          find.widgetWithText(ElevatedButton, S.createTeamChallenge),
        );
        await tester.pumpAndSettle();

        final created = PacerDummyData.demoChallenges.firstWhere(
          (c) => c.judul == 'Sprint 14 Hari Kustom',
        );
        final diffDays =
            created.waktuSelesai!.difference(created.waktuMulai!).inDays;
        expect(diffDays, 14);
      },
    );

    testWidgets(
      'English and Indonesian localization stay consistent on SearchField, CoachBoardScreen, and target units',
      (tester) async {
        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        langNotifier.value = Lang.en;
        expect(S.challengeTargetSummary(1800, 'waktu_s'), '30 MIN');

        await tester.pumpWidget(
          MaterialApp(
            key: const ValueKey('search-en'),
            theme: PacerTheme.light(),
            home: const Scaffold(body: SearchField()),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Search clubs, cities, or friends...'),
          findsOneWidget,
        );
        expect(find.text('Cari klub, kota, atau teman...'), findsNothing);

        await tester.pumpWidget(
          MaterialApp(
            key: const ValueKey('coach-en'),
            theme: PacerTheme.light(),
            home: const CoachBoardScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Target Achieved'), findsWidgets);
        expect(find.text('Target Tercapai'), findsNothing);

        langNotifier.value = Lang.id;
        expect(S.challengeTargetSummary(1800, 'waktu_s'), '30 MNT');

        await tester.pumpWidget(
          MaterialApp(
            key: const ValueKey('search-id'),
            theme: PacerTheme.light(),
            home: const Scaffold(body: SearchField()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cari klub, kota, atau teman...'), findsOneWidget);

        await tester.pumpWidget(
          MaterialApp(
            key: const ValueKey('coach-id'),
            theme: PacerTheme.light(),
            home: const CoachBoardScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Target Tercapai'), findsWidgets);
      },
    );
  });
}
