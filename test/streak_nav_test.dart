// Streak state logic + StreakCard / BottomNavPill widget tests.
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/ui/app_strings.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/widgets.dart';

void main() {
  final now = DateTime(2026, 11, 6, 15); // a Friday
  final today = DateTime(2026, 11, 6);
  final yesterday = DateTime(2026, 11, 5);
  final longAgo = DateTime(2026, 11, 1);

  group('streakStatusOf', () {
    test('worked out today is active', () {
      expect(
        streakStatusOf(count: 3, last: today, now: now),
        StreakStatus.active,
      );
    });
    test('worked out yesterday is at risk', () {
      expect(
        streakStatusOf(count: 3, last: yesterday, now: now),
        StreakStatus.atRisk,
      );
    });
    test('missed a day is inactive', () {
      expect(
        streakStatusOf(count: 9, last: longAgo, now: now),
        StreakStatus.inactive,
      );
    });
    test('zero count or null last is inactive', () {
      expect(
        streakStatusOf(count: 0, last: today, now: now),
        StreakStatus.inactive,
      );
      expect(
        streakStatusOf(count: 4, last: null, now: now),
        StreakStatus.inactive,
      );
    });
  });

  group('effectiveStreak', () {
    test('keeps count while alive, zero once broken', () {
      expect(effectiveStreak(count: 5, last: today, now: now), 5);
      expect(effectiveStreak(count: 5, last: yesterday, now: now), 5);
      expect(effectiveStreak(count: 5, last: longAgo, now: now), 0);
    });
  });

  group('streakWeek', () {
    test('marks trailing days ending at last workout (Mon..Sun)', () {
      // Fri 6th, 3-day streak -> Wed, Thu, Fri.
      expect(streakWeek(count: 3, last: today, now: now), [
        false,
        false,
        true,
        true,
        true,
        false,
        false,
      ]);
    });
    test('empty when count is zero', () {
      expect(
        streakWeek(count: 0, last: today, now: now),
        everyElement(isFalse),
      );
    });
  });

  group('StreakCard', () {
    Future<void> pump(
      WidgetTester tester,
      Widget card, {
      ThemeMode mode = ThemeMode.dark,
    }) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.light(),
          darkTheme: PacerTheme.dark(),
          themeMode: mode,
          home: Scaffold(body: SingleChildScrollView(child: card)),
        ),
      );
      await tester.pumpAndSettle();
    }

    Color pillColor(WidgetTester tester) {
      final box = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('streak-pill')),
      );
      return (box.decoration! as BoxDecoration).color!;
    }

    testWidgets('active: lime accent, filled flame, 3 checks', (tester) async {
      langNotifier.value = Lang.en;
      await pump(
        tester,
        const StreakCard(
          count: 3,
          done: [false, false, true, true, true, false, false],
          todayIndex: 4,
          status: StreakStatus.active,
        ),
      );
      expect(find.text('ACTIVE STREAK'), findsOneWidget);
      // The giant count (size 56) — date labels below may also read "3".
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && w.data == '3' && w.style?.fontSize == 56,
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check), findsNWidgets(3));
      expect(find.byIcon(Icons.local_fire_department), findsWidgets);
      expect(
        pillColor(tester),
        PacerColors.lime.withValues(alpha: 0.14),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('at risk: amber accent and a nudge to run today', (
      tester,
    ) async {
      langNotifier.value = Lang.en;
      await pump(
        tester,
        const StreakCard(
          count: 4,
          done: [false, false, true, true, false, false, false],
          todayIndex: 4,
          status: StreakStatus.atRisk,
        ),
      );
      expect(find.text('STREAK AT RISK'), findsOneWidget);
      expect(find.text('Run today to keep your 4-day streak'), findsOneWidget);
      expect(
        pillColor(tester),
        PacerColors.streakAmber.withValues(alpha: 0.14),
      );
    });

    testWidgets('inactive: muted accent, outlined flame, zero checks', (
      tester,
    ) async {
      langNotifier.value = Lang.en;
      await pump(
        tester,
        const StreakCard(
          count: 0,
          done: [false, false, false, false, false, false, false],
          todayIndex: 4,
          status: StreakStatus.inactive,
        ),
      );
      expect(find.text('NO ACTIVE STREAK'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
      expect(
        find.byIcon(Icons.local_fire_department_outlined),
        findsOneWidget,
      );
      expect(
        pillColor(tester),
        PacerColors.slate400.withValues(alpha: 0.14),
      );
    });

    testWidgets('accent color updates when status changes', (tester) async {
      langNotifier.value = Lang.en;
      Widget card(StreakStatus s) => StreakCard(
        count: s == StreakStatus.inactive ? 0 : 2,
        done: const [false, false, false, false, false, false, false],
        todayIndex: 4,
        status: s,
      );
      await pump(tester, card(StreakStatus.active));
      final before = pillColor(tester);
      await pump(tester, card(StreakStatus.inactive));
      expect(pillColor(tester), isNot(before));
    });

    testWidgets('derives status from data when none given', (tester) async {
      langNotifier.value = Lang.en;
      await pump(
        tester,
        const StreakCard(
          count: 2,
          done: [false, false, false, false, true, false, false],
          todayIndex: 4,
        ),
      );
      expect(find.text('ACTIVE STREAK'), findsOneWidget);
    });

    testWidgets('renders in light theme and Indonesian without overflow', (
      tester,
    ) async {
      langNotifier.value = Lang.id;
      await pump(
        tester,
        const StreakCard(
          count: 1,
          done: [false, false, false, false, true, false, false],
          todayIndex: 4,
          status: StreakStatus.active,
        ),
        mode: ThemeMode.light,
      );
      expect(find.text('STREAK AKTIF'), findsOneWidget);
      expect(find.text('Jum'), findsOneWidget);
      expect(tester.takeException(), isNull);
      langNotifier.value = Lang.en;
    });
  });

  group('BottomNavPill', () {
    Future<void> pumpPill(
      WidgetTester tester, {
      int index = 0,
      ValueChanged<int>? onTap,
      VoidCallback? onStart,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: Scaffold(
            body: Center(
              child: BottomNavPill(
                index: index,
                onTap: onTap ?? (_) {},
                onStart: onStart ?? () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('is frosted glass: strong backdrop blur', (tester) async {
      await pumpPill(tester);
      final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      expect(
        filter.filter,
        ImageFilter.blur(
          sigmaX: BottomNavPill.blurSigma,
          sigmaY: BottomNavPill.blurSigma,
        ),
      );
      expect(BottomNavPill.blurSigma, greaterThanOrEqualTo(10));
    });

    testWidgets('selected tab shows filled icon, others outlined', (
      tester,
    ) async {
      await pumpPill(tester, index: 2);
      expect(find.byIcon(Icons.groups), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(find.byIcon(Icons.directions_run_outlined), findsOneWidget);
      expect(find.byIcon(Icons.leaderboard_outlined), findsOneWidget);
      expect(find.byIcon(Icons.groups_outlined), findsNothing);
    });

    testWidgets('tapping tabs and START fires callbacks', (tester) async {
      final taps = <int>[];
      var started = 0;
      await pumpPill(tester, onTap: taps.add, onStart: () => started++);
      await tester.tap(find.byIcon(Icons.home));
      await tester.tap(find.byIcon(Icons.directions_run_outlined));
      await tester.tap(find.byIcon(Icons.groups_outlined));
      await tester.tap(find.byIcon(Icons.leaderboard_outlined));
      await tester.tap(find.text('START'));
      expect(taps, [0, 1, 2, 3]);
      expect(started, 1);
    });

    testWidgets('exposes selected state to accessibility', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPill(tester, index: 3);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Leaderboard')),
        matchesSemantics(
          label: 'Leaderboard',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });
}
