import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/memory_local_store.dart';
import 'package:pacer/src/sync/connectivity_service.dart';
import 'package:pacer/src/ui/app_strings.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/coach_board.dart';
import 'package:pacer/src/ui/more_screens.dart';
import 'package:pacer/src/ui/pacer_glass.dart';
import 'package:pacer/src/ui/screens.dart';
import 'package:pacer/src/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    langNotifier.value = Lang.en;
    langUserLocked = false;
    setLinuxTheme(PacerLinuxTheme.defaultPacer);
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
    setLinuxTheme(PacerLinuxTheme.defaultPacer);
    setThemeMode(ThemeMode.dark);
  });

  Widget wrapThemed(
    Widget child, {
    PacerLinuxTheme preset = PacerLinuxTheme.defaultPacer,
    ThemeMode mode = ThemeMode.dark,
  }) {
    setLinuxTheme(preset);
    setThemeMode(mode);
    return MaterialApp(
      theme: PacerTheme.light(preset),
      darkTheme: PacerTheme.dark(preset),
      themeMode: mode,
      home: child,
    );
  }

  group('BottomNavPill typography & responsive width contracts', () {
    testWidgets(
      'displays full Leaderboard label without truncation at 320px, 390px, and 900px',
      (tester) async {
        for (final size in const [
          Size(320, 640),
          Size(390, 844),
          Size(900, 800),
        ]) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(wrapThemed(const MainShell()));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final labelFinder = find.text(S.leaderboard);
          expect(labelFinder, findsOneWidget);
          final labelWidget = tester.widget<Text>(labelFinder);
          expect(labelWidget.overflow, isNot(TextOverflow.ellipsis));

          final pillRect = tester.getRect(find.byType(BottomNavPill));
          final labelRect = tester.getRect(labelFinder);
          expect(pillRect.left, greaterThanOrEqualTo(0));
          expect(pillRect.right, lessThanOrEqualTo(size.width));
          expect(labelRect.left, greaterThanOrEqualTo(pillRect.left));
          expect(labelRect.right, lessThanOrEqualTo(pillRect.right));
        }
        await tester.binding.setSurfaceSize(null);
      },
    );
  });

  group('HomeScreen medium weekly overview layout', () {
    testWidgets(
      'renders Avg Pace and Workouts without clipping at 768px and 900px',
      (tester) async {
        for (final size in const [Size(768, 900), Size(900, 800)]) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(wrapThemed(const MainShell()));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final avgPace = find.text(S.avgPaceShort);
          final workouts = find.text(S.workoutsShort);
          expect(avgPace, findsOneWidget);
          expect(workouts, findsOneWidget);

          final avgText = tester.widget<Text>(avgPace);
          final workoutsText = tester.widget<Text>(workouts);
          expect(avgText.overflow, isNot(TextOverflow.ellipsis));
          expect(workoutsText.overflow, isNot(TextOverflow.ellipsis));
          expect(tester.getSize(avgPace).width, greaterThan(40));
          expect(tester.getSize(workouts).width, greaterThan(40));
        }
        await tester.binding.setSurfaceSize(null);
      },
    );
  });

  group('Elevated screens & themes matrix', () {
    testWidgets(
      'PacerSquircleBorder implements OutlinedBorder equality and copyWith',
      (tester) async {
        const b = PacerSquircleBorder(16, rimColor: Color(0x88FFFFFF));
        expect(b, isA<OutlinedBorder>());
        expect(b.copyWith(side: const BorderSide(width: 2)), isNot(equals(b)));
        expect(b.scale(2), const PacerSquircleBorder(32, rimColor: Color(0x88FFFFFF)));
      },
    );

    testWidgets(
      'renders upgraded screens across Light, Dark, and Linux presets without overflow',
      (tester) async {
        final configs = <({PacerLinuxTheme preset, ThemeMode mode, Size size})>[
          (preset: PacerLinuxTheme.defaultPacer, mode: ThemeMode.light, size: const Size(360, 800)),
          (preset: PacerLinuxTheme.defaultPacer, mode: ThemeMode.dark, size: const Size(900, 800)),
          (preset: PacerLinuxTheme.adwaita, mode: ThemeMode.light, size: const Size(360, 800)),
          (preset: PacerLinuxTheme.yaru, mode: ThemeMode.dark, size: const Size(360, 800)),
          (preset: PacerLinuxTheme.nord, mode: ThemeMode.dark, size: const Size(900, 800)),
        ];

        final screens = <Widget Function()>[
          () => RunSetupScreen(onStartWithChallenges: (_, _, _) {}),
          () => const StatisticScreen(),
          () => const LeaderboardScreen(),
          () => const AccountScreen(),
          () => const ThemeSettingsScreen(),
          () => const CoachBoardScreen(),
        ];

        for (final cfg in configs) {
          await tester.binding.setSurfaceSize(cfg.size);
          for (final buildScreen in screens) {
            await tester.pumpWidget(
              wrapThemed(
                buildScreen(),
                preset: cfg.preset,
                mode: cfg.mode,
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));
            expect(
              tester.takeException(),
              isNull,
              reason:
                  'Unexpected exception on ${buildScreen().runtimeType} under ${cfg.preset}/${cfg.mode} at ${cfg.size}',
            );
          }
        }
        await tester.binding.setSurfaceSize(null);
      },
    );
  });
}
