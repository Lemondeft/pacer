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

        expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
        expect(find.text('2'), findsWidgets);
        expect(find.text('Challenge Tim · GBK Runners Elite'), findsOneWidget);
        expect(
          find.textContaining('Target Lari Mingguan Tim'),
          findsOneWidget,
        );

        // Dismiss first assigned challenge banner -> reveals second unread banner.
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Target Lari Mingguan Tim'),
          findsNothing,
        );
        expect(
          find.textContaining('Challenge Endurance 10K'),
          findsOneWidget,
        );

        // Dismiss second unread banner -> banner hides completely.
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(find.text('Challenge Tim · GBK Runners Elite'), findsNothing);
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
}
