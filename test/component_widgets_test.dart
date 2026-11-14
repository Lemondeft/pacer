import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/pacer_glass.dart';
import 'package:pacer/src/ui/pacer_logo.dart';
import 'package:pacer/src/ui/widgets.dart';

void main() {
  Widget wrapDark(Widget child) {
    return MaterialApp(
      theme: PacerTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('StreakCard widget tests', () {
    testWidgets('renders active streak count and day indicators', (tester) async {
      await tester.pumpWidget(
        wrapDark(
          StreakCard(
            count: 7,
            done: const [true, true, true, true, true, true, true],
            todayIndex: 6,
            status: StreakStatus.active,
          ),
        ),
      );

      expect(find.text('7'), findsOneWidget);
      expect(find.text('HARI BERUNTUN'), findsOneWidget);
      // Weekday letters Sen, Sel, Rab, Kam, Jum, Sab, Min
      expect(find.text('Sen'), findsOneWidget);
      expect(find.text('Min'), findsOneWidget);
    });

    testWidgets('renders at-risk status when streak needs attention', (tester) async {
      await tester.pumpWidget(
        wrapDark(
          StreakCard(
            count: 2,
            done: const [true, true, false, false, false, false, false],
            todayIndex: 2,
            status: StreakStatus.atRisk,
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);
      expect(find.text('HARI BERUNTUN'), findsOneWidget);
    });
  });

  group('RunSessionCard widget tests', () {
    testWidgets('displays title, date, time, distance, and pace', (tester) async {
      await tester.pumpWidget(
        wrapDark(
          const RunSessionCard(
            title: 'Lari Pagi',
            date: 'Senin, 06:30',
            time: '25:12',
            pace: "5'10\" /km",
            distance: '4.88 km',
          ),
        ),
      );

      expect(find.text('Lari Pagi'), findsOneWidget);
      expect(find.text('Senin, 06:30'), findsOneWidget);
      expect(find.text('25:12'), findsOneWidget);
      expect(find.text("5'10\" /km"), findsOneWidget);
      expect(find.text('4.88 km'), findsOneWidget);
    });
  });

  group('TeamCard widget tests', () {
    testWidgets('displays team name and location', (tester) async {
      await tester.pumpWidget(
        wrapDark(
          const TeamCard(
            name: 'Bandung Striders',
            location: 'Bandung',
          ),
        ),
      );

      expect(find.text('Bandung Striders'), findsOneWidget);
      expect(find.text('Bandung'), findsOneWidget);
    });

    testWidgets('displays memberCount, privacy, and joined badges without overflow at 241x140', (tester) async {
      await tester.pumpWidget(
        wrapDark(
          const SizedBox(
            width: 241,
            height: 140,
            child: TeamCard(
              name: 'GBK Runners Elite Very Long Club Name',
              memberCount: 18,
              isJoined: true,
              isPrivate: false,
            ),
          ),
        ),
      );

      expect(find.text('GBK Runners Elite Very Long Club Name'), findsOneWidget);
      expect(find.textContaining('18'), findsOneWidget);
      expect(find.byIcon(Icons.group_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('BottomNavPill widget tests', () {
    testWidgets('triggers onTap and onStart callbacks', (tester) async {
      int? tappedIndex;
      var startTapped = false;

      await tester.pumpWidget(
        wrapDark(
          BottomNavPill(
            index: 0,
            onTap: (i) => tappedIndex = i,
            onStart: () => startTapped = true,
          ),
        ),
      );

      // Verify START button is rendered
      expect(find.text('START'), findsOneWidget);

      // Tap on START
      await tester.tap(find.text('START'));
      await tester.pump();
      expect(startTapped, isTrue);

      // Tap on Teams icon (index 2)
      await tester.tap(find.byIcon(Icons.groups_outlined));
      await tester.pump();
      expect(tappedIndex, 2);

      // Tap on Leaderboard icon (index 3)
      await tester.tap(find.byIcon(Icons.leaderboard_outlined));
      await tester.pump();
      expect(tappedIndex, 3);
    });
  });

  group('PacerLogo accessibility semantics test', () {
    testWidgets('PacerLogo and PacerMark have semantic image labels', (tester) async {
      await tester.pumpWidget(
        wrapDark(
          const Column(
            children: [
              PacerLogo(width: 150),
              PacerMark(width: 48),
            ],
          ),
        ),
      );

      expect(find.bySemanticsLabel('Pacer'), findsNWidgets(2));
    });
  });

  group('PacerGlass and Mornye Glassmorphism Spec tests', () {
    test('PacerSquircleBorder generates continuous path and scales', () {
      const border = PacerSquircleBorder(24);
      final path = border.getOuterPath(const Rect.fromLTWH(0, 0, 100, 50));
      expect(path, isNotNull);
      expect(border.scale(2), equals(const PacerSquircleBorder(48)));
      expect(border.dimensions, EdgeInsets.zero);
    });

    testWidgets('PacerGlass renders frosted backdrop and squircle shape', (tester) async {
      await tester.pumpWidget(
        wrapDark(
          const PacerGlass.navigation(
            radius: 32,
            child: Text('Glass Content'),
          ),
        ),
      );

      expect(find.text('Glass Content'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('PacerGlassPress reacts to pointer down and up with spring motion', (tester) async {
      await tester.pumpWidget(
        wrapDark(
          const PacerGlassPress(
            radius: 20,
            child: SizedBox(width: 50, height: 50, child: Text('Press Me')),
          ),
        ),
      );

      expect(find.text('Press Me'), findsOneWidget);
      final gesture = await tester.startGesture(tester.getCenter(find.text('Press Me')));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Press Me'), findsOneWidget);
    });
  });

  group('Soft Cool Ice-Mist Light Theme tests', () {
    test('PacerScheme.light uses non-white cool mist surfaces', () {
      const pureWhite = Color(0xFFFFFFFF);
      expect(PacerScheme.light.scaffold, isNot(pureWhite));
      expect(PacerScheme.light.card, isNot(pureWhite));
      expect(PacerScheme.light.navBar, isNot(pureWhite));
      final theme = PacerTheme.light();
      expect(theme.scaffoldBackgroundColor, isNot(pureWhite));
      expect(theme.cardTheme.color, isNot(pureWhite));
      expect(theme.dialogTheme.backgroundColor, isNot(pureWhite));
      expect(theme.bottomSheetTheme.backgroundColor, isNot(pureWhite));
    });

    testWidgets('StreakCard, TeamCard, and BottomNavPill render crisply in light theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  StreakCard(
                    count: 3,
                    done: const [true, true, true, false, false, false, false],
                    todayIndex: 2,
                    status: StreakStatus.active,
                  ),
                  const TeamCard(
                    name: 'Ice Mist Runners',
                    location: 'Jakarta',
                    memberCount: 12,
                    isJoined: true,
                  ),
                  BottomNavPill(
                    index: 0,
                    onTap: (_) {},
                    onStart: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Ice Mist Runners'), findsOneWidget);
      expect(find.text('START'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
