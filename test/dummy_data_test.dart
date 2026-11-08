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

    testWidgets('TeamsScreen renders dummy teams and filters with search', (tester) async {
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

      expect(find.text('GBK Runners Elite'), findsOneWidget);
      expect(find.text('Monas Morning Joggers'), findsOneWidget);

      // Search for 'Sudirman'
      await tester.enterText(find.byType(TextField), 'Sudirman');
      await tester.pumpAndSettle();

      expect(find.text('Sudirman Night Cyclists'), findsOneWidget);
      expect(find.text('GBK Runners Elite'), findsNothing);
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
