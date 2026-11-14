import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:pacer/main.dart';
import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/auth/user_model.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/memory_local_store.dart';
import 'package:pacer/src/sync/connectivity_service.dart';
import 'package:pacer/src/tracking/recorder.dart';
import 'package:pacer/src/tracking/route_map.dart';
import 'package:pacer/src/ui/app_strings.dart';
import 'package:pacer/src/ui/app_theme.dart';
import 'package:pacer/src/ui/more_screens.dart';
import 'package:pacer/src/ui/screens.dart';
import 'package:pacer/src/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

Position _pos(
  double lat,
  double lng, {
  double accuracy = 5,
  double altitude = 10,
  double speed = 1.6,
}) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime.utc(2026, 11, 14, 7),
  accuracy: accuracy,
  altitude: altitude,
  altitudeAccuracy: 3,
  heading: 0,
  headingAccuracy: 1,
  speed: speed,
  speedAccuracy: 0.5,
);

void main() {
  setUp(() {
    langNotifier.value = Lang.id;
    langUserLocked = false;
    SharedPreferences.setMockInitialValues({});
    LocalStore.instance = MemoryLocalStore();
    ConnectivityService.instance.setTestOverride(false);
  });

  tearDown(() {
    ConnectivityService.instance.setTestOverride(null);
    LocalStore.instance = MemoryLocalStore();
    langNotifier.value = Lang.id;
    langUserLocked = false;
  });

  group('Derived workout metrics and RunRecorder route capture', () {
    test('computeElevationGainM ignores <= 1.5m jitter and sums real climbs', () {
      final pts = <RutePoint>[
        const RutePoint(
          aktivitasId: 'a1',
          urutan: 0,
          lat: -6.200,
          lng: 106.800,
          elevasiM: 10.0,
        ),
        const RutePoint(
          aktivitasId: 'a1',
          urutan: 1,
          lat: -6.201,
          lng: 106.800,
          elevasiM: 11.0, // <= 1.5m delta: ignored
        ),
        const RutePoint(
          aktivitasId: 'a1',
          urutan: 2,
          lat: -6.202,
          lng: 106.801,
          elevasiM: 16.0, // +6.0m climb from anchor 10.0
        ),
        const RutePoint(
          aktivitasId: 'a1',
          urutan: 3,
          lat: -6.203,
          lng: 106.802,
          elevasiM: 12.0, // downhill resets anchor
        ),
        const RutePoint(
          aktivitasId: 'a1',
          urutan: 4,
          lat: -6.204,
          lng: 106.803,
          elevasiM: 15.0, // +3.0m climb from anchor 12.0
        ),
      ];
      expect(computeElevationGainM(pts), closeTo(9.0, 0.01));
    });

    test('estimateCaloriesKcal scales by sport type, weight, and duration', () {
      expect(
        estimateCaloriesKcal(jenis: 'lari', durasiS: 0, jarakM: 500),
        0,
      );
      final walkKcal = estimateCaloriesKcal(
        jenis: 'berjalan',
        durasiS: 1800,
        jarakM: 2500,
        weightKg: 70,
      );
      final runKcal = estimateCaloriesKcal(
        jenis: 'lari',
        durasiS: 1800,
        jarakM: 5000,
        weightKg: 70,
      );
      expect(walkKcal, greaterThan(80));
      expect(runKcal, greaterThan(walkKcal));
      // Zero distance with active duration still estimates resting-to-light burn.
      expect(
        estimateCaloriesKcal(jenis: 'berjalan', durasiS: 120, jarakM: 0),
        greaterThan(0),
      );
    });

    test('computeRunMetrics produces real stride/cadence for walking and omits for cycling', () {
      final walkMetrics = computeRunMetrics(
        jenis: 'berjalan',
        durasiS: 720,
        jarakM: 1080,
        heightCm: 175,
        weightKg: 70,
        points: const [
          RutePoint(
            aktivitasId: 'w1',
            urutan: 0,
            lat: -6.200,
            lng: 106.800,
            elevasiM: 10,
          ),
          RutePoint(
            aktivitasId: 'w1',
            urutan: 1,
            lat: -6.205,
            lng: 106.805,
            elevasiM: 22,
          ),
        ],
      );
      expect(walkMetrics.caloriesKcal, greaterThan(0));
      expect(walkMetrics.elevationGainM, closeTo(12.0, 0.01));
      expect(walkMetrics.stepLengthCm, isNotNull);
      expect(walkMetrics.stepLengthCm!, greaterThan(50));
      expect(walkMetrics.cadenceSpm, isNotNull);
      expect(walkMetrics.cadenceSpm!, inInclusiveRange(60, 220));

      final bikeMetrics = computeRunMetrics(
        jenis: 'bersepeda',
        durasiS: 900,
        jarakM: 5000,
      );
      expect(bikeMetrics.stepLengthCm, isNull);
      expect(bikeMetrics.cadenceSpm, isNull);
      expect(bikeMetrics.caloriesKcal, greaterThan(0));

      final zeroDistWalk = computeRunMetrics(
        jenis: 'berjalan',
        durasiS: 16,
        jarakM: 0,
      );
      expect(zeroDistWalk.stepLengthCm, 0);
      expect(zeroDistWalk.cadenceSpm, 0);
    });

    test('RunRecorder.simulate(berjalan) preserves sport type and route points in RunSummary', () async {
      final store = MemoryLocalStore();
      await store.setLastUserId('walker-1');
      LocalStore.instance = store;

      final recorder = RunRecorder(store: store);
      addTearDown(recorder.dispose);

      await recorder.simulate('berjalan');
      recorder.pause();
      recorder.recordPositionForTest(_pos(-6.2000, 106.8000, altitude: 10));
      recorder.recordPositionForTest(_pos(-6.2015, 106.8012, altitude: 16));
      recorder.recordPositionForTest(_pos(-6.2030, 106.8025, altitude: 20));

      final summary = await recorder.finish();
      expect(summary, isNotNull);
      expect(summary!.jenis, 'berjalan');
      expect(summary.pointCount, 3);
      expect(summary.points.length, 3);
      expect(summary.jarakM, greaterThan(300));
      expect(summary.anchorLat, closeTo(-6.2000, 0.0001));
      expect(summary.anchorLng, closeTo(106.8000, 0.0001));
    });
  });

  group('RunFinishScreen OSM route & derived display', () {
    testWidgets('shows OSM FlutterMap polyline, markers, controls, and derived metrics for walking', (tester) async {
      final store = MemoryLocalStore();
      await store.setLastUserId('walker-2');
      await store.upsertProfile(
        const UserProfile(
          id: 'walker-2',
          nama: 'Sari',
          tinggiCm: 168,
          beratKg: 60,
        ),
      );
      LocalStore.instance = store;

      const pts = [
        RutePoint(
          aktivitasId: 'walk-123',
          urutan: 0,
          lat: -6.2000,
          lng: 106.8000,
          elevasiM: 12,
        ),
        RutePoint(
          aktivitasId: 'walk-123',
          urutan: 1,
          lat: -6.2018,
          lng: 106.8015,
          elevasiM: 18,
        ),
        RutePoint(
          aktivitasId: 'walk-123',
          urutan: 2,
          lat: -6.2035,
          lng: 106.8030,
          elevasiM: 25,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.light(),
          home: RunFinishScreen(
            title: S.sportName('berjalan'),
            isHistoryDetail: true,
            aktivitasId: 'walk-123',
            summary: const RunSummary(
              aktivitasId: 'walk-123',
              jenis: 'berjalan',
              jarakM: 1200,
              durasiS: 720,
              pointCount: 3,
              points: pts,
              anchorLat: -6.2000,
              anchorLng: 106.8000,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RouteMap), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(PolylineLayer), findsOneWidget);
      expect(find.byType(MarkerLayer), findsOneWidget);
      expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
      expect(find.byIcon(Icons.center_focus_strong_rounded), findsOneWidget);
      expect(find.byIcon(Icons.grid_on_rounded), findsOneWidget);

      // Summary card shows real totals (Indonesian comma separator default)
      expect(find.text('1,20 Km'), findsOneWidget);
      expect(find.text('12.00'), findsOneWidget);
      expect(find.text("10'00\""), findsOneWidget);

      // Real derived metric units — no hardcoded mock 854/212/1,00 values
      expect(find.text('854'), findsNothing);
      expect(find.text('212'), findsNothing);
      expect(find.text('1,00'), findsNothing);
      expect(find.text('cm'), findsOneWidget);
      expect(find.text('spm'), findsOneWidget);
      expect(find.text('13'), findsOneWidget);
      expect(find.text('m'), findsOneWidget);

      // Minimal toggle button flips between OSM tiles and minimal offline canvas
      await tester.tap(find.byIcon(Icons.grid_on_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    });

    testWidgets('shows OSM fallback neighborhood, non-blank 0\'00\'\' pace, and handles system back via onBack when 0 GPS points', (tester) async {
      var backCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.light(),
          home: RunFinishScreen(
            title: S.sportName('berjalan'),
            isHistoryDetail: true,
            aktivitasId: 'walk-empty',
            onBack: () => backCalls++,
            summary: const RunSummary(
              aktivitasId: 'walk-empty',
              jenis: 'berjalan',
              jarakM: 0,
              durasiS: 16,
              pointCount: 0,
              points: [],
              anchorLat: -6.2088,
              anchorLng: 106.8456,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Still renders real OSM map around anchor + empty route pill instead of fake Bezier placeholder.
      expect(find.byType(RouteMap), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text(S.noGpsPoints), findsOneWidget);

      // Avg Pace is never blank!
      expect(find.text("0'00\""), findsOneWidget);
      expect(find.text('00.16'), findsOneWidget);

      // System back invokes embedded onBack instead of closing app.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(backCalls, 1);
    });
  });

  group('Android system back button & MainShell tab history', () {
    testWidgets('CreateAccountScreen returns to GetStartedScreen on system back', (tester) async {
      await tester.pumpWidget(const PacerApp());
      await tester.pumpAndSettle();

      expect(find.text(S.appTagline), findsOneWidget);
      await tester.tap(find.text(S.signUp));
      await tester.pumpAndSettle();
      expect(find.byType(CreateAccountScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(GetStartedScreen), findsOneWidget);
      expect(find.text(S.appTagline), findsOneWidget);
    });

    testWidgets('MainShell back navigates through tab history and shows double-back toast on Home', (tester) async {
      final store = MemoryLocalStore();
      await store.setLastUserId('nav-user');
      await store.upsertProfile(
        const UserProfile(id: 'nav-user', nama: 'Budi', peran: 'user'),
      );
      LocalStore.instance = store;

      await tester.pumpWidget(
        MaterialApp(theme: PacerTheme.light(), home: const MainShell()),
      );
      await tester.pumpAndSettle();

      // Starts on Home tab.
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.widget<BottomNavPill>(find.byType(BottomNavPill)).index, 0);

      // Switch Home -> Teams via BottomNavPill label.
      await tester.tap(find.text(S.teams));
      await tester.pumpAndSettle();
      expect(tester.widget<BottomNavPill>(find.byType(BottomNavPill)).index, 2);

      // Switch Teams -> Leaderboard.
      await tester.tap(find.text(S.leaderboard));
      await tester.pumpAndSettle();
      expect(tester.widget<BottomNavPill>(find.byType(BottomNavPill)).index, 3);

      // First system Back returns Leaderboard -> Teams.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.widget<BottomNavPill>(find.byType(BottomNavPill)).index, 2);

      // Second system Back returns Teams -> Home.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.widget<BottomNavPill>(find.byType(BottomNavPill)).index, 0);

      // Third system Back on Home shows double-back prompt instead of exiting immediately.
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(S.pressBackAgainToExit), findsOneWidget);
    });
  });

  group('RouteMap OpenFreeMap clean vector styles', () {
    vt.Style fakeStyle(String name, String bgHex) {
      final theme = const vt.ThemeReader().read({
        'version': 8,
        'name': name,
        'layers': [
          {
            'id': 'background',
            'type': 'background',
            'paint': {'background-color': bgHex},
          },
        ],
      });
      return vt.Style(
        name: name,
        theme: theme,
        providers: const vt.TileProviders({}),
        attributions: [
          vt.StyleAttribution.parse(
            'OpenFreeMap © OpenMapTiles Data from OpenStreetMap',
          ),
        ],
      );
    }

    const pts = [
      LatLng(-6.2000, 106.8000),
      LatLng(-6.2015, 106.8015),
    ];

    testWidgets('selects Positron in light mode and Dark in dark mode with labels disabled by default', (tester) async {
      final requestedUris = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.light(),
          home: Scaffold(
            body: RouteMap(
              points: pts,
              fitBounds: true,
              styleLoader: (uri) async {
                requestedUris.add(uri);
                return fakeStyle('positron', '#F8FAFC');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(requestedUris, [RouteMap.lightStyleUri]);
      final lightLayer = tester.widget<vt.VectorTileLayer>(
        find.byType(vt.VectorTileLayer),
      );
      expect(lightLayer.showLabels, isFalse);
      expect(lightLayer.glyphs, isNull);
      expect(
        find.text('OpenFreeMap © OpenMapTiles Data from OpenStreetMap'),
        findsOneWidget,
      );

      // Switching theme brightness reloads dark style cleanly without leaks.
      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: Scaffold(
            body: RouteMap(
              points: pts,
              fitBounds: true,
              styleLoader: (uri) async {
                requestedUris.add(uri);
                return fakeStyle('dark', '#0F172A');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(requestedUris, [RouteMap.lightStyleUri, RouteMap.darkStyleUri]);
      final darkLayer = tester.widget<vt.VectorTileLayer>(
        find.byType(vt.VectorTileLayer),
      );
      expect(darkLayer.showLabels, isFalse);
      expect(find.byType(PolylineLayer), findsOneWidget);
      expect(find.byType(MarkerLayer), findsOneWidget);
    });

    testWidgets('uses Fiord dark style and strips landuse_residential polygons', (tester) async {
      expect(
        RouteMap.darkStyleUri,
        'https://tiles.openfreemap.org/styles/fiord',
      );
      final rawTheme = const vt.ThemeReader().read({
        'version': 8,
        'name': 'fiord',
        'layers': [
          {
            'id': 'background',
            'type': 'background',
            'paint': {'background-color': '#45516E'},
          },
          {
            'id': 'landuse_residential',
            'type': 'fill',
            'paint': {'fill-color': 'rgb(234, 234, 230)'},
          },
          {
            'id': 'water',
            'type': 'fill',
            'paint': {'fill-color': '#38435C'},
          },
        ],
      });
      final rawStyle = vt.Style(
        name: 'fiord',
        theme: rawTheme,
        providers: const vt.TileProviders({}),
      );

      final cleaned = RouteMap.sanitizeStyle(rawStyle, RouteMap.darkStyleUri);
      expect(
        cleaned.theme.layers.map((l) => l.id).toList(),
        ['background', 'water'],
      );
      // Positron remains unmodified.
      expect(
        identical(
          RouteMap.sanitizeStyle(rawStyle, RouteMap.lightStyleUri),
          rawStyle,
        ),
        isTrue,
      );
    });

    testWidgets('RunTrackerScreen map button toggles interactive Map Focus mode and avoids empty-chip overlap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: const RunTrackerScreen(sportType: 'lari'),
        ),
      );
      await tester.pumpAndSettle();

      // Empty chip is hidden so it never sits behind MULAI.
      expect(find.text(S.noGpsPoints), findsNothing);
      expect(find.text(S.distanceKm), findsOneWidget);

      final initialBtn = tester.widget<MapCircleButton>(
        find.byType(MapCircleButton),
      );
      expect(initialBtn.active, isFalse);

      final initialMap = tester.widget<RouteMap>(find.byType(RouteMap));
      expect(initialMap.fitBounds, isFalse);
      expect(initialMap.showControls, isFalse);

      // Tap map button -> activates unobstructed Map Focus + compact top HUD.
      await tester.tap(find.byType(MapCircleButton));
      await tester.pumpAndSettle();

      final activeBtn = tester.widget<MapCircleButton>(
        find.byType(MapCircleButton),
      );
      expect(activeBtn.active, isTrue);
      expect(activeBtn.icon, Icons.speed_rounded);
      expect(find.text(S.distanceKm), findsNothing);
      expect(find.text(S.metricDistance), findsOneWidget);
      expect(find.text(S.metricDuration), findsOneWidget);
      expect(find.text(S.metricCalories), findsOneWidget);

      final focusedMap = tester.widget<RouteMap>(find.byType(RouteMap));
      expect(focusedMap.fitBounds, isTrue);
      expect(focusedMap.showControls, isTrue);

      // Map overlay controls underneath SafeArea receive taps cleanly.
      final gridToggle = find.byIcon(Icons.grid_on_rounded);
      expect(gridToggle, findsOneWidget);
      await tester.tap(gridToggle);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.map_outlined), findsAtLeastNWidgets(1));

      // Tap map button again -> returns to Hero readout mode.
      await tester.tap(find.byType(MapCircleButton));
      await tester.pumpAndSettle();
      expect(find.text(S.distanceKm), findsOneWidget);
      expect(
        tester.widget<MapCircleButton>(find.byType(MapCircleButton)).active,
        isFalse,
      );
    });

    testWidgets('degrades gracefully to themed grid behind route when offline style load fails', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PacerTheme.dark(),
          home: Scaffold(
            body: RouteMap(
              points: pts,
              fitBounds: true,
              styleLoader: (_) => Future.error(Exception('offline cold boot')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(vt.VectorTileLayer), findsNothing);
      expect(find.byType(PolylineLayer), findsOneWidget);
      expect(find.byType(MarkerLayer), findsOneWidget);
    });
  });
}
