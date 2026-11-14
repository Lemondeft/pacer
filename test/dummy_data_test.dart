import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/demo/pacer_dummy_data.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/coach_board.dart';
import 'package:pacer/src/ui/more_screens.dart';
import 'package:pacer/src/ui/screens.dart';

void main() {
  group('PacerDummyData Unit Tests', () {
    test('contains comprehensive activity data for all 4 sport types', () {
      expect(PacerDummyData.activities.length, greaterThanOrEqualTo(10));
      final sports = PacerDummyData.activities.map((a) => a.jenis).toSet();
      expect(sports, containsAll(['lari', 'joging', 'bersepeda', 'berjalan']));
    });

    test('contains 6 active clubs with invite codes', () {
      expect(PacerDummyData.teams.length, 6);
      for (final t in PacerDummyData.teams) {
        expect(t.inviteCode, isNotNull);
        expect(t.nama.isNotEmpty, isTrue);
      }
    });

    test('generates leaderboards across metrics and periods', () {
      final distWeekly = PacerDummyData.getLeaderboardData(metric: 'jarak', period: 'mingguan');
      expect(distWeekly.rows.length, 10);
      expect(distWeekly.boardNama, contains('Jarak'));

      final calMonthly = PacerDummyData.getLeaderboardData(metric: 'kalori', period: 'bulanan');
      expect(calMonthly.rows.length, 10);
      expect(calMonthly.boardNama, contains('Kalori'));

      final durWeekly = PacerDummyData.getLeaderboardData(metric: 'durasi', period: 'mingguan');
      expect(durWeekly.rows.length, 10);
      expect(durWeekly.boardNama, contains('Durasi'));
    });

    test('leaderboard scopes narrow the rows (team < region < global)', () {
      int n(String sc) =>
          PacerDummyData.getLeaderboardData(scope: sc).rows.length;
      expect(n('team'), lessThan(n('region')));
      expect(n('region'), lessThan(n('global')));
    });

    test('teams mix public and private; private ones are not listed', () {
      expect(PacerDummyData.teams.any((t) => t.isPrivate), isTrue);
      expect(PacerDummyData.teams.any((t) => !t.isPrivate), isTrue);
    });

    test('contains challenges across distance and time units', () {
      expect(PacerDummyData.challenges.length, 6);
      final units = PacerDummyData.challenges.map((c) => c.targetSatuan).toSet();
      expect(units, containsAll(['jarak_m', 'waktu_s']));
    });

    test('contains realistic chat messages', () {
      expect(PacerDummyData.chatMessages.length, greaterThanOrEqualTo(6));
    });

    test('contains coach student PE evaluation rows', () {
      expect(PacerDummyData.coachDummyRows.length, 6);
      expect(PacerDummyData.coachDummyRows.any((r) => r.berhasil == true), isTrue);
    });
  });

  group('Demo Mode UI Integration Tests', () {
    setUp(() {
      PacerDummyData.resetDemoTeams();
    });

    tearDown(() {
      PacerDummyData.resetDemoTeams();
    });
    testWidgets('HomeScreen renders mock streak, activities and teams in demo mode', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: const Scaffold(body: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Should display PACER logo and activity card
      expect(find.text('Lari'), findsWidgets);
      expect(find.text('GBK Runners Elite'), findsOneWidget);
    });

    testWidgets('HistoryScreen renders full activity grid with statistics in demo mode', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: const Scaffold(body: HistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kilometer'), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('Joging'), findsWidgets);
      expect(find.text('Bersepeda'), findsWidgets);
    });

    testWidgets('TeamsScreen renders joined & public teams with counts and filters with search', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: const Scaffold(body: TeamsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Joined Teams section (includes joined private XI IPA 1 - SMAN 1)
      // and Open for Public section (excludes unjoined private JakBar Pacer Community).
      expect(find.text('Tim yang Diikuti'), findsOneWidget);
      expect(find.text('Terbuka untuk Umum'), findsOneWidget);
      expect(find.text('GBK Runners Elite'), findsWidgets);
      expect(find.text('XI IPA 1 - SMAN 1'), findsOneWidget);
      expect(find.text('Monas Morning Joggers'), findsOneWidget);
      expect(find.text('JakBar Pacer Community'), findsNothing);
      expect(find.text('18 anggota'), findsWidgets);

      // Search for 'Sudirman'
      await tester.enterText(find.byType(TextField), 'Sudirman');
      await tester.pumpAndSettle();

      expect(find.text('Sudirman Night Cyclists'), findsOneWidget);
      expect(find.text('GBK Runners Elite'), findsNothing);
    });

    testWidgets('Tapping a public team opens TeamDashboardScreen, shows roster, and updates count on join/leave', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: const Scaffold(body: TeamsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap unjoined public team (Monas Morning Joggers: 11 -> 12 on join)
      await tester.tap(find.text('Monas Morning Joggers'));
      await tester.pumpAndSettle();

      expect(find.text('Monas Morning Joggers'), findsOneWidget);
      expect(find.text('11 anggota'), findsWidgets);
      expect(find.text('Coach Hendra'), findsOneWidget);
      expect(find.text('Gabung'), findsOneWidget);

      // Join team -> member count increments to 12 and Leave button appears
      await tester.tap(find.text('Gabung'));
      await tester.pumpAndSettle();

      expect(find.text('12 anggota'), findsWidgets);
      expect(find.text('Keluar tim'), findsOneWidget);
    });

    testWidgets('Private invite code is hidden from non-members and masked/revealable for joined members', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Unjoined private team (33333333... JakBar Pacer Community):
      // code is null in data layer & hidden in UI.
      expect(
        PacerDummyData.getDemoInviteCode('33333333-3333-3333-3333-333333333333'),
        isNull,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: const TeamDashboardScreen(
            teamId: '33333333-3333-3333-3333-333333333333',
            teamName: 'JakBar Pacer Community',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kode Undangan'), findsNothing);
      expect(find.text('JAKBAR01'), findsNothing);

      // Joined private team (22222222... XI IPA 1 - SMAN 1):
      // code is masked first, then revealed on eye tap.
      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: const TeamDashboardScreen(
            teamId: '22222222-2222-2222-2222-222222222222',
            teamName: 'XI IPA 1 - SMAN 1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kode Undangan'), findsOneWidget);
      expect(find.text('••••••••'), findsOneWidget);
      expect(find.text('IPA1RUNS'), findsNothing);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(find.text('IPA1RUNS'), findsOneWidget);
    });

    testWidgets('LeaderboardScreen renders full podium and rank rows in demo mode', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: const Scaffold(body: LeaderboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('Siti Rahma'), findsOneWidget);
    });

    testWidgets('ChallengeListScreen renders dummy challenges in demo mode', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: const Scaffold(body: ChallengeListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('KM'), findsWidgets);
    });

    testWidgets('CoachBoardScreen renders dummy student PE grading in demo mode', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: const Scaffold(body: CoachBoardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('Target Tercapai'), findsWidgets);
    });
  });
}
