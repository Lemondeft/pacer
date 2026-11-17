import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/memory_local_store.dart';
import 'package:pacer/src/sync/connectivity_service.dart';
import 'package:pacer/src/ui/app_strings.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/more_screens.dart';
import 'package:pacer/src/ui/pacer_glass.dart';
import 'package:pacer/src/ui/screens.dart';
import 'package:pacer/src/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    langNotifier.value = Lang.en;
    langUserLocked = false;
    setThemeMode(ThemeMode.dark);
    SharedPreferences.setMockInitialValues({});
    LocalStore.instance = MemoryLocalStore();
    ConnectivityService.instance.setTestOverride(false);
  });

  tearDown(() {
    ConnectivityService.instance.setTestOverride(null);
    LocalStore.instance = MemoryLocalStore();
    langNotifier.value = Lang.id;
    langUserLocked = false;
    setThemeMode(ThemeMode.dark);
  });

  Widget wrapApp(Widget child, {ThemeMode themeMode = ThemeMode.dark}) =>
      MaterialApp(
        theme: PacerTheme.light(),
        darkTheme: PacerTheme.dark(),
        themeMode: themeMode,
        home: child,
      );

  testWidgets(
    'LeaderboardScreen places category filters left of divider and All Time with periods on right (EN & ID)',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      langNotifier.value = Lang.en;
      await tester.pumpWidget(wrapApp(LeaderboardScreen(onBack: () {})));
      await tester.pumpAndSettle();

      Finder findDivider() => find.byWidgetPredicate(
        (w) => w is Container &&
            w.constraints?.minWidth == 1 &&
            w.constraints?.minHeight == 20,
      );

      final dividerEnX = tester.getTopLeft(findDivider()).dx;
      final allMetricEnX = tester.getTopLeft(find.text('All')).dx;
      final distanceEnX = tester.getTopLeft(find.text('Distance')).dx;
      final caloriesEnX = tester.getTopLeft(find.text('Calories')).dx;
      final durationEnX = tester.getTopLeft(find.text('Duration')).dx;
      final allTimeEnX = tester.getTopLeft(find.text('All Time')).dx;
      final weeklyEnX = tester.getTopLeft(find.text('Weekly')).dx;
      final monthlyEnX = tester.getTopLeft(find.text('Monthly')).dx;

      expect(allMetricEnX, lessThan(distanceEnX));
      expect(distanceEnX, lessThan(caloriesEnX));
      expect(caloriesEnX, lessThan(durationEnX));
      expect(durationEnX, lessThan(dividerEnX));
      expect(dividerEnX, lessThan(allTimeEnX));
      expect(allTimeEnX, lessThan(weeklyEnX));
      expect(weeklyEnX, lessThan(monthlyEnX));

      langNotifier.value = Lang.id;
      await tester.pumpWidget(wrapApp(LeaderboardScreen(onBack: () {})));
      await tester.pumpAndSettle();

      final dividerIdX = tester.getTopLeft(findDivider()).dx;
      final allMetricIdX = tester.getTopLeft(find.text('Semua')).dx;
      final distanceIdX = tester.getTopLeft(find.text('Jarak')).dx;
      final caloriesIdX = tester.getTopLeft(find.text('Kalori')).dx;
      final durationIdX = tester.getTopLeft(find.text('Durasi')).dx;
      final allTimeIdX = tester.getTopLeft(find.text('Sepanjang Waktu')).dx;
      final weeklyIdX = tester.getTopLeft(find.text('Mingguan')).dx;
      final monthlyIdX = tester.getTopLeft(find.text('Bulanan')).dx;

      expect(allMetricIdX, lessThan(distanceIdX));
      expect(distanceIdX, lessThan(caloriesIdX));
      expect(caloriesIdX, lessThan(durationIdX));
      expect(durationIdX, lessThan(dividerIdX));
      expect(dividerIdX, lessThan(allTimeIdX));
      expect(allTimeIdX, lessThan(weeklyIdX));
      expect(weeklyIdX, lessThan(monthlyIdX));
    },
  );

  for (final mode in [ThemeMode.dark, ThemeMode.light]) {
    testWidgets(
      'MainShell mounts LiquidGlassView edge lens navbar and scrolls HomeScreen cleanly in $mode',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(wrapApp(const MainShell(), themeMode: mode));
        await tester.pumpAndSettle();

        final lgView = tester.widget<LiquidGlassView>(
          find.byType(LiquidGlassView),
        );
        expect(lgView.realTimeCapture, isFalse);

        final scopes = tester
            .widgetList<PacerGlassScope>(find.byType(PacerGlassScope))
            .toList();
        expect(scopes.any((s) => s.hasBackdropView), isTrue);

        final navGlass = tester.widget<PacerGlass>(
          find
              .descendant(
                of: find.byType(BottomNavPill),
                matching: find.byType(PacerGlass),
              )
              .first,
        );
        expect(navGlass.refractionWidth, 12.0);
        expect(navGlass.refractionIndexOverride, 1.18);
        expect(navGlass.magnification, 1.02);
        expect(navGlass.dispersionOverride, 1.2);
        expect(navGlass.lensBlurSigma, 2.8);
        expect(navGlass.continuousCorners, isTrue);

        // Inside MainShell's LiquidGlassView + PacerGlassScope(hasBackdropView: true),
        // BottomNavPill mounts an active PacerLiquidBackdrop instead of flat BackdropFilter.
        final lensBackdrop = tester.widget<PacerLiquidBackdrop>(
          find
              .descendant(
                of: find.byType(BottomNavPill),
                matching: find.byType(PacerLiquidBackdrop),
              )
              .first,
        );
        expect(lensBackdrop.refractionWidth, 12.0);
        expect(lensBackdrop.blurSigma, 2.8);

        // Scroll HomeScreen down past fold to exercise ScrollNotification capture
        // and verify dashboard sections stay interactive without overflow.
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -450));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -450));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(S.leaderboardSnapshotTitle), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(HomeScreen),
            matching: find.text(S.history),
          ),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets(
    'Enriched HomeScreen sections open real destinations cleanly',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapApp(const MainShell()));
      await tester.pumpAndSettle();

      // 1. Streak card -> StreaksScreen
      await tester.tap(find.byType(StreakCard));
      await tester.pumpAndSettle();
      expect(find.byType(StreaksScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(StreaksScreen))).pop();
      await tester.pumpAndSettle();

      final verticalScrollable = find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first;

      // 2. Quick-start sport chip -> RunSetupScreen with pre-selected sport
      final jogChip = find.text(S.sportName('joging')).first;
      await tester.ensureVisible(jogChip);
      await tester.tap(jogChip);
      await tester.pumpAndSettle();
      final setup = tester.widget<RunSetupScreen>(find.byType(RunSetupScreen));
      expect(setup.initialSport, 'joging');
      Navigator.of(tester.element(find.byType(RunSetupScreen))).pop();
      await tester.pumpAndSettle();

      // 3. Weekly overview -> StatisticScreen
      await tester.scrollUntilVisible(
        find.text(S.viewStats),
        250,
        scrollable: verticalScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.viewStats));
      await tester.pumpAndSettle();
      expect(find.byType(StatisticScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(StatisticScreen))).pop();
      await tester.pumpAndSettle();

      // 4. Challenges SectionHeader -> ChallengeListScreen
      final chalTitle = find.text(S.openChallengesTitle).evaluate().isNotEmpty
          ? S.openChallengesTitle
          : S.activeChallengesTitle;
      await tester.scrollUntilVisible(
        find.text(chalTitle),
        250,
        scrollable: verticalScrollable,
      );
      await tester.pumpAndSettle();
      // Tap See All inside the challenge SectionHeader.
      final seeAllButtons = find.text(S.seeAll);
      await tester.ensureVisible(seeAllButtons.first);
      await tester.tap(seeAllButtons.first);
      await tester.pumpAndSettle();
      expect(find.byType(ChallengeListScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(ChallengeListScreen))).pop();
      await tester.pumpAndSettle();

      // 5. Standing card -> switches MainShell tab to Leaderboard (index 3)
      await tester.scrollUntilVisible(
        find.text(S.leaderboardSnapshotTitle),
        250,
        scrollable: verticalScrollable,
      );
      await tester.pumpAndSettle();
      final standingTarget = find.text(S.openLeaderboardCta).evaluate().isNotEmpty
          ? find.text(S.openLeaderboardCta)
          : find.textContaining('#').first;
      await tester.ensureVisible(standingTarget);
      await tester.tap(standingTarget);
      await tester.pumpAndSettle();
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        3,
      );
    },
  );

  testWidgets(
    'ThemeSettingsScreen lets users switch Classic Linux Desktop Themes',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() {
        setLinuxTheme(PacerLinuxTheme.defaultPacer);
        tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        ValueListenableBuilder<PacerLinuxTheme>(
          valueListenable: linuxThemeNotifier,
          builder: (context, preset, _) => MaterialApp(
            theme: PacerTheme.light(preset),
            darkTheme: PacerTheme.dark(preset),
            themeMode: ThemeMode.dark,
            home: const ThemeSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Classic Linux Desktop Themes'), findsOneWidget);
      expect(linuxThemeNotifier.value, PacerLinuxTheme.defaultPacer);

      for (final info in PacerLinuxThemeInfo.all) {
        final target = find.byKey(ValueKey('linux_theme_${info.id.name}'));
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();

        expect(linuxThemeNotifier.value, info.id);
        final ctx = tester.element(find.byType(ThemeSettingsScreen));
        final scheme = PacerScheme.of(ctx);
        expect(scheme.accent, info.accent);
        expect(scheme.brandAccent, info.accent);
        expect(scheme.heroCardGradient.length, 2);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
