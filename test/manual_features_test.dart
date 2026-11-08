import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/more_screens.dart';

void main() {
  group('Sport Selection & Setup Tests (Manual Flowchart Process 1.0/2.0)', () {
    testWidgets('RunSetupScreen displays 4 sports grid and can select', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      String? selectedSport;
      String? selectedGoal;

      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: Scaffold(
            body: RunSetupScreen(
              onStartWithConfig: (sport, goal) {
                selectedSport = sport;
                selectedGoal = goal;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check all 4 sports from manual are visible
      expect(find.text('Lari'), findsOneWidget);
      expect(find.text('Joging'), findsOneWidget);
      expect(find.text('Bersepeda'), findsOneWidget);
      expect(find.text('Berjalan'), findsOneWidget);

      // Select 'Bersepeda' (cycling)
      await tester.tap(find.text('Bersepeda'));
      await tester.pumpAndSettle();

      // Tap start activity button
      final btnFinder = find.widgetWithText(ElevatedButton, 'Mulai Olahraga');
      expect(btnFinder, findsOneWidget);
      await tester.ensureVisible(btnFinder);
      await tester.pumpAndSettle();
      await tester.tap(btnFinder);
      await tester.pumpAndSettle();

      expect(selectedSport, 'bersepeda');
      expect(selectedGoal, 'Bebas');
    });
  });

  group('Leaderboard Filters (Manual DFD 2.4 & PDM)', () {
    testWidgets('LeaderboardScreen renders metric and period filter chips', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: const Scaffold(
            body: LeaderboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify category filter chips from manual
      expect(find.text('Semua'), findsWidgets);
      expect(find.text('Jarak'), findsOneWidget);
      expect(find.text('Kalori'), findsOneWidget);
      expect(find.text('Durasi'), findsOneWidget);
      expect(find.text('Mingguan'), findsOneWidget);
      expect(find.text('Bulanan'), findsOneWidget);

      // Tap filter
      await tester.tap(find.text('Jarak'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Notification Screen (Context Diagram)', () {
    testWidgets('NotificationMockScreen displays reminders and challenge updates', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: const Scaffold(
            body: NotificationMockScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifikasi'), findsOneWidget);
      expect(find.text('Pengingat Aktivitas'), findsOneWidget);
      expect(find.text('Challenge Update'), findsOneWidget);
    });
  });
}
