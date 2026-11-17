import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:pacer/src/ui/app_strings.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/pacer_glass.dart';
import 'package:pacer/src/ui/widgets.dart';

void main() {
  setUp(() {
    langNotifier.value = Lang.en;
  });

  tearDown(() {
    langNotifier.value = Lang.id;
  });

  Future<void> pumpFrames(WidgetTester tester, [int count = 22]) async {
    for (var f = 0; f < count; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Widget wrapPill({
    int index = 0,
    ValueChanged<int>? onTap,
    VoidCallback? onStart,
    ThemeMode mode = ThemeMode.dark,
    bool disableAnimations = false,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: const Size(420, 800),
        disableAnimations: disableAnimations,
      ),
      child: MaterialApp(
        theme: PacerTheme.light(),
        darkTheme: PacerTheme.dark(),
        themeMode: mode,
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
  }

  testWidgets(
    'rest state mounts no PacerScrubberDroplet; hold expands droplet and morphs into a circle over START',
    (tester) async {
      final tapped = <int>[];
      var starts = 0;

      await tester.pumpWidget(
        wrapPill(index: 0, onTap: tapped.add, onStart: () => starts++),
      );

      // Resting bar mounts no extra scrubber droplet lens.
      expect(find.byType(PacerScrubberDroplet), findsNothing);

      final pillRect = tester.getRect(find.byType(BottomNavPill));
      final homeCenter = tester.getCenter(find.text(S.home));
      final startCenter = tester.getCenter(find.text('START'));
      final teamsCenter = tester.getCenter(find.text(S.teams));

      // Press and hold past long-press threshold (~140 ms) to lift & expand droplet.
      final gesture = await tester.startGesture(homeCenter);
      await tester.pump(const Duration(milliseconds: 180));
      await pumpFrames(tester, 18);

      final dropletFinder = find.byKey(
        const ValueKey('pacer_nav_scrubber_droplet'),
      );
      expect(dropletFinder, findsOneWidget);

      final expandedOnTab = tester.widget<PacerScrubberDroplet>(dropletFinder);
      expect(expandedOnTab.size.width, greaterThanOrEqualTo(105));
      expect(expandedOnTab.size.height, greaterThanOrEqualTo(80));
      expect(expandedOnTab.size.width, greaterThan(expandedOnTab.size.height + 16));
      expect(expandedOnTab.cornerRadius, lessThan(expandedOnTab.size.height / 2 - 4));
      expect(expandedOnTab.refractionIndex, greaterThanOrEqualTo(1.10));
      expect(expandedOnTab.refractionWidth, greaterThanOrEqualTo(18.0));
      expect(expandedOnTab.magnification, 1.0);
      expect(expandedOnTab.blur, 0.0);
      expect(expandedOnTab.glowColor, isNull);
      expect(find.byType(Tooltip), findsNothing);

      // Drag gradually onto the center START orb and settle velocity deformation.
      for (var i = 1; i <= 6; i++) {
        final pos = Offset.lerp(homeCenter, startCenter, i / 6)!;
        await gesture.moveTo(pos);
        await tester.pump(const Duration(milliseconds: 30));
      }
      await pumpFrames(tester, 32);

      final onStartDroplet = tester.widget<PacerScrubberDroplet>(dropletFinder);
      expect(
        (onStartDroplet.size.width - onStartDroplet.size.height).abs(),
        lessThan(1.5),
      );
      expect(
        onStartDroplet.cornerRadius,
        closeTo(onStartDroplet.size.height / 2, 1.0),
      );
      expect(onStartDroplet.center.dx, closeTo(pillRect.width / 2, 3.0));
      expect(onStartDroplet.glowColor, isNotNull);
      // Dragging across START never fires onStart prematurely.
      expect(starts, 0);

      // Continue scrubbing right past START onto Teams: droplet morphs back to pill.
      for (var i = 1; i <= 5; i++) {
        final pos = Offset.lerp(startCenter, teamsCenter, i / 5)!;
        await gesture.moveTo(pos);
        await tester.pump(const Duration(milliseconds: 30));
      }
      await pumpFrames(tester, 24);

      final onTeamsDroplet = tester.widget<PacerScrubberDroplet>(dropletFinder);
      expect(
        onTeamsDroplet.size.width,
        greaterThan(onTeamsDroplet.size.height + 8),
      );
      expect(onTeamsDroplet.glowColor, isNull);

      // Release over Teams commits tab index 2 (Teams) without calling onStart.
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tapped, [2]);
      expect(starts, 0);
      expect(find.byType(PacerScrubberDroplet), findsNothing);
    },
  );

  testWidgets(
    'releasing dragged circular droplet on START invokes onStart cleanly',
    (tester) async {
      final tapped = <int>[];
      var starts = 0;

      await tester.pumpWidget(
        wrapPill(
          index: 1,
          onTap: tapped.add,
          onStart: () => starts++,
          mode: ThemeMode.light,
        ),
      );

      final historyCenter = tester.getCenter(find.text(S.history));
      final startCenter = tester.getCenter(find.text('START'));

      final gesture = await tester.startGesture(historyCenter);
      await tester.pump(const Duration(milliseconds: 180));
      for (var i = 1; i <= 5; i++) {
        await gesture.moveTo(Offset.lerp(historyCenter, startCenter, i / 5)!);
        await tester.pump(const Duration(milliseconds: 25));
      }
      await pumpFrames(tester, 32);

      final droplet = tester.widget<PacerScrubberDroplet>(
        find.byType(PacerScrubberDroplet),
      );
      expect((droplet.size.width - droplet.size.height).abs(), lessThan(1.5));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(starts, 1);
      expect(tapped, isEmpty);
      expect(find.byType(PacerScrubberDroplet), findsNothing);
    },
  );

  testWidgets(
    'immediate horizontal drag activates scrubber without long-press delay and commits Leaderboard',
    (tester) async {
      final tapped = <int>[];
      await tester.pumpWidget(wrapPill(index: 0, onTap: tapped.add));

      final homeCenter = tester.getCenter(find.text(S.home));
      final leaderboardCenter = tester.getCenter(find.text(S.leaderboard));

      final gesture = await tester.startGesture(homeCenter);
      await gesture.moveTo(homeCenter + const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byType(PacerScrubberDroplet), findsOneWidget);

      await gesture.moveTo(leaderboardCenter);
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tapped, [3]);
      expect(find.byType(PacerScrubberDroplet), findsNothing);
    },
  );

  testWidgets(
    'respects disableAnimations accessibility while still morphing to START circle during scrub',
    (tester) async {
      var starts = 0;
      await tester.pumpWidget(
        wrapPill(
          index: 0,
          disableAnimations: true,
          onStart: () => starts++,
        ),
      );

      final homeCenter = tester.getCenter(find.text(S.home));
      final startCenter = tester.getCenter(find.text('START'));

      final gesture = await tester.startGesture(homeCenter);
      await tester.pump(const Duration(milliseconds: 180));
      await gesture.moveTo(startCenter);
      await tester.pump();

      final droplet = tester.widget<PacerScrubberDroplet>(
        find.byType(PacerScrubberDroplet),
      );
      expect((droplet.size.width - droplet.size.height).abs(), lessThan(0.5));
      expect(droplet.glowColor, isNotNull);

      await gesture.up();
      await tester.pump();

      expect(starts, 1);
      expect(find.byType(PacerScrubberDroplet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shader-native path (Linux/Impeller) inside FittedBox + LiquidGlassView positions droplet without ParentDataWidget error or full-bar blowup',
    (tester) async {
      PacerGlass.debugShaderFilterSupport = true;
      try {
        final tapped = <int>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: PacerTheme.light(),
            darkTheme: PacerTheme.dark(),
            themeMode: ThemeMode.dark,
            home: Scaffold(
              body: LiquidGlassView(
                pixelRatio: 0.85,
                realTimeCapture: false,
                useSync: false,
                batch: false,
                backgroundWidget: const SizedBox.expand(),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: 390,
                    height: 80.7 * (390 / 377),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: PacerGlassScope(
                        hasBackdropView: true,
                        clarity: 0.85,
                        child: BottomNavPill(
                          index: 0,
                          onTap: tapped.add,
                          onStart: () {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final homeCenter = tester.getCenter(find.text(S.home));
        final teamsCenter = tester.getCenter(find.text(S.teams));

        final gesture = await tester.startGesture(homeCenter);
        await tester.pump(const Duration(milliseconds: 180));
        await pumpFrames(tester, 18);

        expect(tester.takeException(), isNull);

        final dropletFinder = find.byKey(
          const ValueKey('pacer_nav_scrubber_droplet'),
        );
        final lensFinder = find.descendant(
          of: dropletFinder,
          matching: find.byType(LiquidGlassLens),
        );
        expect(dropletFinder, findsOneWidget);
        expect(lensFinder, findsOneWidget);

        final lensRect = tester.getRect(lensFinder);
        // Expanded cube blocks past the 80.7px bar height without
        // erroneously stretching across the full scrubber overlay.
        expect(lensRect.width, inInclusiveRange(96.0, 128.0));
        expect(lensRect.height, inInclusiveRange(84.0, 108.0));
        expect(lensRect.center.dx, closeTo(homeCenter.dx, 14.0));

        await gesture.moveTo(teamsCenter);
        await pumpFrames(tester, 18);
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(tapped, [2]);
        expect(find.byType(PacerScrubberDroplet), findsNothing);
      } finally {
        PacerGlass.debugShaderFilterSupport = null;
      }
    },
  );

  testWidgets(
    'START stays unclipped/unmasked and tabs render in one fixed ShaderMask during scrub',
    (tester) async {
      await tester.pumpWidget(wrapPill());
      final homeCenter = tester.getCenter(find.text(S.home));
      final startCenter = tester.getCenter(find.text('START'));

      final gesture = await tester.startGesture(homeCenter);
      await tester.pump(const Duration(milliseconds: 180));
      await gesture.moveTo(startCenter);
      await pumpFrames(tester, 22);

      expect(find.byType(PacerScrubberDroplet), findsOneWidget);
      expect(find.text('START'), findsOneWidget);
      // Mornye architecture: one fixed icon row inside a single ShaderMask,
      // zero duplicate icon rows or ClipPath cutouts slicing START or tabs.
      expect(find.text(S.home), findsOneWidget);
      expect(find.text(S.history), findsOneWidget);
      expect(find.text(S.teams), findsOneWidget);
      expect(find.text(S.leaderboard), findsOneWidget);
      expect(
        find.ancestor(of: find.text(S.home), matching: find.byType(ShaderMask)),
        findsOneWidget,
      );
      expect(
        find.ancestor(of: find.text('START'), matching: find.byType(ClipPath)),
        findsNothing,
      );
      expect(
        find.ancestor(of: find.text('START'), matching: find.byType(ShaderMask)),
        findsNothing,
      );

      await gesture.cancel();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'micro-jitter drag avoids pill shake and release smoothly recovers rest fill & border alpha',
    (tester) async {
      var activeTab = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => wrapPill(
            index: activeTab,
            onTap: (idx) => setState(() => activeTab = idx),
          ),
        ),
      );

      final homeCenter = tester.getCenter(find.text(S.home));
      final historyCenter = tester.getCenter(find.text(S.history));

      final gesture = await tester.startGesture(homeCenter);
      await tester.pump(const Duration(milliseconds: 180));
      await gesture.moveTo(historyCenter);
      await pumpFrames(tester, 18);

      // Simulate uneven desktop mouse quantization steps during slow drag.
      final widths = <double>[];
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(Offset(i.isEven ? 1.5 : -1.5, 0));
        await tester.pump(const Duration(milliseconds: 16));
        final droplet = tester.widget<PacerScrubberDroplet>(
          find.byType(PacerScrubberDroplet),
        );
        widths.add(droplet.size.width);
      }
      final minW = widths.reduce((a, b) => a < b ? a : b);
      final maxW = widths.reduce((a, b) => a > b ? a : b);
      expect(maxW - minW, lessThan(6.0));

      // Release and sample settling frames until the droplet hands over to rest.
      await gesture.up();
      final presences = <double>[];
      final tintAlphas = <double>[];
      final borderAlphas = <double>[];
      for (var f = 0; f < 30; f++) {
        await tester.pump(const Duration(milliseconds: 16));
        final matches = find.byType(PacerScrubberDroplet);
        if (matches.evaluate().isEmpty) break;
        final droplet = tester.widget<PacerScrubberDroplet>(matches);
        presences.add(droplet.glassPresence);
        tintAlphas.add(droplet.tintColor.a);
        borderAlphas.add(droplet.borderColor!.a);
      }

      expect(activeTab, 1);
      expect(presences.length, greaterThanOrEqualTo(4));
      expect(presences.last, lessThan(presences.first));
      // Fill & border must stay visible (converging to restCubeFill 0.18 / 0.42),
      // never fading to 0 transparent right before restLayer mounts.
      expect(tintAlphas.last, greaterThanOrEqualTo(tintAlphas.first));
      expect(tintAlphas.last, greaterThan(0.10));
      expect(borderAlphas.last, greaterThan(0.35));

      await tester.pumpAndSettle();
      expect(find.byType(PacerScrubberDroplet), findsNothing);
    },
  );
}
