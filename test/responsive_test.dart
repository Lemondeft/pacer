// Viewport-matrix regression per the responsive rules: test at 360, 600,
// 900, 1280 plus landscape. Checks: no layout exceptions, grids on medium+,
// nav pill capped at ~480, NavigationRail on expanded.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/ui/more_screens.dart';
import 'package:pacer/src/ui/screens.dart';
import 'package:pacer/src/ui/widgets.dart';

void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    Size logicalSize,
    WidgetBuilder builder,
  ) async {
    tester.view.physicalSize = logicalSize * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Builder(builder: builder)));
    await tester.pumpAndSettle();
  }

  const viewports = {
    'phone 360x800': Size(360, 800),
    'compact edge 600x800': Size(600, 800),
    'tablet 900x800': Size(900, 800),
    'desktop 1280x800': Size(1280, 800),
    'landscape 852x393': Size(852, 393),
  };

  for (final entry in viewports.entries) {
    testWidgets('MainShell lays out at ${entry.key} without overflow', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, entry.value, (_) => const MainShell());
      expect(tester.takeException(), isNull);
      expect(find.byType(StreakCard), findsOneWidget);
    });

    testWidgets('GetStarted lays out at ${entry.key} without overflow', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        entry.value,
        (_) => GetStartedScreen(onSignIn: () {}, onLogIn: () {}),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(PacerLogo), findsOneWidget);
    });

    testWidgets('CreateAccount lays out at ${entry.key} without overflow', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        entry.value,
        (_) => CreateAccountScreen(onSubmitted: () {}),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(AuthField), findsNWidgets(4));
    });
  }

  testWidgets('nav pill grows past phone size but caps at ~480 on tablet', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const Size(900, 800), (_) => const MainShell());
    final rect = tester.getRect(find.byType(BottomNavPill));
    expect(rect.width, greaterThan(377));
    expect(rect.width, lessThanOrEqualTo(480));
    expect(tester.takeException(), isNull);
  });

  testWidgets('nav pill fits narrow screens without overflowing', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const Size(320, 640), (_) => const MainShell());
    final rect = tester.getRect(find.byType(BottomNavPill));
    expect(rect.width, lessThanOrEqualTo(320));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded width uses NavigationRail instead of the pill', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const Size(1280, 800), (_) => const MainShell());
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(BottomNavPill), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('team cards become a grid on tablet widths', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const Size(900, 800), (_) => const TeamsScreen());
    expect(find.byType(GridView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history cards become a grid on tablet widths', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const Size(900, 800), (_) => const HistoryScreen());
    expect(find.byType(GridView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
