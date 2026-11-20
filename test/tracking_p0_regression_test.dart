import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/aktivitas/activity_repository.dart';
import 'package:pacer/src/local/memory_local_store.dart';
import 'package:pacer/src/local/store_factory_io.dart';
import 'package:pacer/src/sync/connectivity_service.dart';
import 'package:pacer/src/sync/sync_engine.dart';
import 'package:pacer/src/tracking/activity_classifier.dart';
import 'package:pacer/src/tracking/motion_sensors.dart';
import 'package:pacer/src/tracking/recorder.dart';
import 'package:pacer/src/tracking/route_map.dart';

class _FakeMotionSensors implements MotionSensorProvider {
  final StreamController<OsMotionEvent> motionController =
      StreamController<OsMotionEvent>.broadcast();
  final StreamController<int> stepsController =
      StreamController<int>.broadcast();

  @override
  Future<bool> ensureMotionPermission() async => true;

  @override
  Future<void> startMonitoring() async {}

  @override
  Future<void> stopMonitoring() async {}

  @override
  Stream<OsMotionEvent> get osMotionStream => motionController.stream;

  @override
  Stream<int> get stepDeltaStream => stepsController.stream;

  @override
  Future<List<AccelSample>> sampleAccelBurst({
    Duration duration = const Duration(
      seconds: DetectionThresholds.accelBurstDurationSec,
    ),
    int sampleRateHz = DetectionThresholds.accelSampleRateHz,
  }) async => const [];

  @override
  void dispose() {
    motionController.close();
    stepsController.close();
  }
}

Position _gpsPos({
  required double lat,
  required double lng,
  required DateTime at,
  double speed = 3.05,
  double accuracy = 5.0,
}) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: at,
  accuracy: accuracy,
  altitude: 10.0,
  altitudeAccuracy: 2.0,
  heading: 0.0,
  headingAccuracy: 5.0,
  speed: speed,
  speedAccuracy: 0.5,
);

List<AccelSample> _smoothCyclingBurst() => [
  for (var i = 0; i < 125; i++)
    AccelSample(
      x: 0.1 * math.sin(i * 0.2),
      y: 9.81 + 0.35 * math.sin(i * 0.25),
      z: 0.1 * math.cos(i * 0.2),
      timestampMs: i * 40,
    ),
];

void main() {
  group('P0-1 Unsynced local route protection & SQLite v5 osMotionSummary', () {
    test('saveRoutePoints refuses empty overwrite while activity syncState != synced in SqliteLocalStore and MemoryLocalStore', () async {
      final sqlStore = await openInMemorySqliteStore();
      final memStore = MemoryLocalStore();
      addTearDown(sqlStore.close);

      final t0 = DateTime.utc(2026, 11, 18, 6, 0);
      final pts = [
        for (var i = 0; i < 5; i++)
          RutePoint(
            aktivitasId: 'act-unsynced-1',
            urutan: i,
            lat: -6.2000 + i * 0.0001,
            lng: 106.8000,
            direkamAt: t0.add(Duration(seconds: i * 5)),
          ),
      ];

      for (final store in [sqlStore, memStore]) {
        await store.finalizeRunAtomic(
          id: 'act-unsynced-1',
          userId: 'runner-1',
          jenis: 'lari',
          mulaiAt: t0,
          selesaiAt: t0.add(const Duration(minutes: 5)),
          durasiS: 300,
          jarakM: 1000,
          allPoints: pts,
          osMotionSummary: const {
            'total_windows': 4,
            'max_window_kmh': 20.5,
            'peak_window_cadence_spm': 192,
          },
        );

        // Simulated empty remote response while still pending outbox must NOT wipe points.
        await store.saveRoutePoints('act-unsynced-1', const []);
        final kept = await ActivityRepository(store: store).getRoute(
          'act-unsynced-1',
        );
        expect(kept.length, 5);

        final savedAct = await store.getActivity('act-unsynced-1');
        expect(savedAct?.activity.osMotionSummary?['max_window_kmh'], 20.5);
        expect(
          savedAct?.activity.osMotionSummary?['peak_window_cadence_spm'],
          192,
        );
      }
    });
  });

  group('P0-2 & P0-3 GPS Filtering, Relocation Recovery, Warmup & Pause Breaks', () {
    test('rejects Null Island (0,0), fix #2 90 km/h spike (S2b), and post-gap 60 km/h jump (S6b) without starving subsequent fixes', () {
      final sanitizer = GpsSanitizer();
      final t0 = DateTime.utc(2026, 11, 18, 6, 0);

      // Null Island (0.0, 0.0) dropped immediately and cannot lock out Jakarta.
      final nullIsland = sanitizer.ingest(
        GpsFix(
          lat: 0.0,
          lng: 0.0,
          altitudeM: 0,
          speedMs: 3.0,
          accuracyM: 5.0,
          timestamp: t0,
        ),
      );
      expect(nullIsland.status, GpsIngestStatus.droppedInvalidCoords);

      final anchor = sanitizer.ingest(
        GpsFix(
          lat: -6.20000,
          lng: 106.80000,
          altitudeM: 10,
          speedMs: 0.0,
          accuracyM: 5.0,
          timestamp: t0.add(const Duration(seconds: 1)),
        ),
      );
      expect(anchor.accepted, isTrue);

      // Fix #2 jumps ~25 m in 1 s (~90 km/h) -> rejected cleanly.
      final fix2Spike = sanitizer.ingest(
        GpsFix(
          lat: -6.200225,
          lng: 106.80000,
          altitudeM: 10,
          speedMs: 3.0,
          accuracyM: 5.0,
          timestamp: t0.add(const Duration(seconds: 2)),
        ),
      );
      expect(fix2Spike.status, GpsIngestStatus.droppedImplausibleAccel);

      // True runner points (~11 km/h = 3.05 m/s -> ~0.0000274 deg/s) accept immediately.
      for (var s = 1; s <= 5; s++) {
        final next = sanitizer.ingest(
          GpsFix(
            lat: -6.20000 + s * 0.0000274,
            lng: 106.80000,
            altitudeM: 10,
            speedMs: 3.05,
            accuracyM: 5.0,
            timestamp: t0.add(Duration(seconds: 1 + s)),
          ),
        );
        expect(next.accepted, isTrue, reason: 'fix +${s}s should not starve');
      }

      // After 15 s blackout, 250 m (60 km/h) jump is rejected without locking out real track.
      final postGapJump = sanitizer.ingest(
        GpsFix(
          lat: -6.20250,
          lng: 106.80000,
          altitudeM: 10,
          speedMs: 3.05,
          accuracyM: 5.0,
          timestamp: t0.add(const Duration(seconds: 21)),
        ),
      );
      expect(postGapJump.status, GpsIngestStatus.droppedImplausibleAccel);

      final realPostGap = sanitizer.ingest(
        GpsFix(
          lat: -6.20000 + 21 * 0.0000274,
          lng: 106.80000,
          altitudeM: 10,
          speedMs: 3.05,
          accuracyM: 5.0,
          timestamp: t0.add(const Duration(seconds: 22)),
        ),
      );
      expect(realPostGap.accepted, isTrue);
    });

    test('recovers cleanly after 3 mutually consistent relocated fixes without jump chord', () {
      final sanitizer = GpsSanitizer();
      final t0 = DateTime.utc(2026, 11, 18, 6, 0);

      sanitizer.ingest(
        GpsFix(
          lat: -6.20000,
          lng: 106.80000,
          altitudeM: 10,
          speedMs: 3.0,
          accuracyM: 5.0,
          timestamp: t0,
        ),
      );
      // 3 fixes ~2 km away moving steadily at ~3 m/s
      for (var i = 0; i < 2; i++) {
        final r = sanitizer.ingest(
          GpsFix(
            lat: -6.22000 + i * 0.000027,
            lng: 106.80000,
            altitudeM: 10,
            speedMs: 3.0,
            accuracyM: 5.0,
            timestamp: t0.add(Duration(seconds: 5 + i)),
          ),
        );
        expect(r.accepted, isFalse);
      }
      final recovered = sanitizer.ingest(
        GpsFix(
          lat: -6.22000 + 2 * 0.000027,
          lng: 106.80000,
          altitudeM: 10,
          speedMs: 3.0,
          accuracyM: 5.0,
          timestamp: t0.add(const Duration(seconds: 7)),
        ),
      );
      expect(recovered.accepted, isTrue);
      expect(recovered.segmentDistanceMeters, 0.0);
    });

    test('RunRecorder.pause/resume clears spatial anchor (0m pause chord), records pauseBreakIndices, and gates paceSecPerKm warmup', () async {
      final store = MemoryLocalStore();
      final connectivity = ConnectivityService()..setTestOverride(false);
      final sync = SyncEngine(
        storeProvider: () => store,
        connectivity: connectivity,
      );
      final sensors = _FakeMotionSensors();
      final recorder = RunRecorder(
        store: store,
        sync: sync,
        userIdProvider: () async => 'runner-p0',
        sensors: sensors,
        enableGpsStream: false,
      );
      addTearDown(() async {
        recorder.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 25));
        sync.dispose();
        connectivity.dispose();
        sensors.dispose();
      });

      await recorder.start('lari');
      expect(recorder.paceSecPerKm, isNull); // < 20 m warmup

      final t0 = DateTime.utc(2026, 11, 18, 6, 0);
      recorder.recordPositionForTest(
        _gpsPos(lat: -6.20000, lng: 106.80000, at: t0),
        enforceKinematics: true,
      );
      recorder.recordPositionForTest(
        _gpsPos(
          lat: -6.20009,
          lng: 106.80000,
          at: t0.add(const Duration(seconds: 3)),
        ),
        enforceKinematics: true,
      );
      // Wait <= 5 s OR dist < 20 m keeps pace null
      expect(recorder.distanceM, closeTo(10.0, 0.5));
      expect(recorder.paceSecPerKm, isNull);

      recorder.pause();
      final beforeRelocateM = recorder.distanceM;
      recorder.resume();

      // Relocate 400 m away while paused (> 60 s break) -> resume starts new segment cleanly with 0 m chord.
      recorder.recordPositionForTest(
        _gpsPos(
          lat: -6.20369,
          lng: 106.80000,
          at: t0.add(const Duration(seconds: 68)),
        ),
        enforceKinematics: true,
      );
      expect(recorder.distanceM, closeTo(beforeRelocateM, 0.01));
      expect(recorder.pauseBreakIndices, contains(2));

      final summary = await recorder.finish();
      expect(summary, isNotNull);
      expect(
        RouteMap.breakIndicesFromRoute(summary!.points),
        contains(2),
      );
    });
  });

  group('P0-4 & P0-5 Activity Classification & Telemetry Summary', () {
    test('ActivityMismatchMonitor clears transient Run->Walk latch on resumed running (S8) but locks Bike/Vehicle cheats (S13c-2)', () {
      final monitor = ActivityMismatchMonitor();
      final t0 = DateTime.utc(2026, 11, 18, 6, 0);
      const walkWin = TelemetryWindow(
        medianSpeedKmh: 4.5,
        p85SpeedKmh: 5.0,
        distanceMeters: 37.5,
        gradePercent: 0,
        steps: 52,
        osActivity: OsMotionLabel.walking,
        osConfidence: 90,
      );
      const runWin = TelemetryWindow(
        medianSpeedKmh: 12.0,
        p85SpeedKmh: 12.5,
        distanceMeters: 100.0,
        gradePercent: 0,
        steps: 86,
        osActivity: OsMotionLabel.running,
        osConfidence: 92,
      );
      const bikeWin = TelemetryWindow(
        medianSpeedKmh: 25.0,
        p85SpeedKmh: 26.0,
        distanceMeters: 208.0,
        gradePercent: 0,
        steps: 0,
        osActivity: OsMotionLabel.onBicycle,
        osConfidence: 90,
      );

      for (var i = 0; i < 4; i++) {
        monitor.ingestWindow(
          selectedSport: SportType.run,
          window: walkWin,
          now: t0.add(Duration(seconds: i * 30)),
        );
      }
      expect(monitor.activeMismatch?.suggestedJenis, 'berjalan');

      // 2 clean running windows clear transient walk break.
      monitor.ingestWindow(
        selectedSport: SportType.run,
        window: runWin,
        now: t0.add(const Duration(seconds: 120)),
      );
      expect(monitor.activeMismatch?.suggestedJenis, 'berjalan');
      final cleared = monitor.ingestWindow(
        selectedSport: SportType.run,
        window: runWin,
        now: t0.add(const Duration(seconds: 150)),
      );
      expect(cleared, isNull);

      // Bike mismatch must NEVER auto-clear after resuming jogging.
      monitor.ingestWindow(
        selectedSport: SportType.run,
        window: bikeWin,
        now: t0.add(const Duration(seconds: 180)),
      );
      monitor.ingestWindow(
        selectedSport: SportType.run,
        window: bikeWin,
        now: t0.add(const Duration(seconds: 210)),
      );
      expect(monitor.activeMismatch?.suggestedJenis, 'bersepeda');
      for (var i = 0; i < 4; i++) {
        final stillFlagged = monitor.ingestWindow(
          selectedSport: SportType.run,
          window: runWin,
          now: t0.add(Duration(seconds: 240 + i * 30)),
        );
        expect(stillFlagged?.suggestedJenis, 'bersepeda');
      }
    });

    test('catches 15.5 km/h grey-zone cycling when OS is UNKNOWN & steps are null (S13c-1) and triggers L3 at 11.2 km/h (S11b)', () {
      expect(
        shouldTriggerAccelBurst(
          const TelemetryWindow(
            medianSpeedKmh: 11.2,
            p85SpeedKmh: 11.8,
            distanceMeters: 93,
            gradePercent: 0,
            steps: 70,
            osActivity: OsMotionLabel.running,
            osConfidence: 90,
          ),
          selectedSport: SportType.run,
        ),
        isTrue,
      );

      final burst = extractAccelBurstFeatures(_smoothCyclingBurst());
      final eval = evaluateActivityWindow(
        SportType.run,
        TelemetryWindow(
          medianSpeedKmh: 15.5,
          p85SpeedKmh: 16.2,
          distanceMeters: 129,
          gradePercent: 0,
          steps: null,
          osActivity: OsMotionLabel.unknown,
          osConfidence: 0,
          accelBurst: burst,
        ),
      );
      expect(eval.isMismatch, isTrue);
      expect(eval.suggestedJenis, 'bersepeda');
    });

    test('RunRecorder records osMotionSummary peak_window_cadence_spm into SQLite', () async {
      final sqlStore = await openInMemorySqliteStore();
      final connectivity = ConnectivityService()..setTestOverride(false);
      final sync = SyncEngine(
        storeProvider: () => sqlStore,
        connectivity: connectivity,
      );
      final sensors = _FakeMotionSensors();
      final recorder = RunRecorder(
        store: sqlStore,
        sync: sync,
        userIdProvider: () async => 'runner-summary',
        sensors: sensors,
        enableGpsStream: false,
      );
      addTearDown(() async {
        recorder.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 25));
        sync.dispose();
        connectivity.dispose();
        sensors.dispose();
        await sqlStore.close();
      });

      await recorder.start('lari');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final t0 = DateTime.utc(2026, 11, 18, 6, 0);
      // Simulate ~20.5 km/h (5.69 m/s) over 10 s with 32 steps (~192 spm * 0.5/min)
      recorder.recordPositionForTest(
        _gpsPos(lat: -6.20000, lng: 106.80000, at: t0, speed: 5.69),
        enforceKinematics: true,
      );
      recorder.recordPositionForTest(
        _gpsPos(
          lat: -6.20051,
          lng: 106.80000,
          at: t0.add(const Duration(seconds: 10)),
          speed: 5.69,
        ),
        enforceKinematics: true,
      );
      sensors.stepsController.add(96); // 96 steps / 30s = 192 spm
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await recorder.evaluateWindowForTest(now: t0.add(const Duration(seconds: 12)));

      final summary = await recorder.finish();
      final stored = await sqlStore.getActivity(summary!.aktivitasId);
      expect(stored?.activity.osMotionSummary?['total_windows'], 1);
      expect(
        stored?.activity.osMotionSummary?['peak_window_cadence_spm'],
        192,
      );
    });

    test('mergeRemoteActivities and saveRoutePoints([], ...) never cascade-delete existing SQLite route_points', () async {
      final sqlStore = await openInMemorySqliteStore();
      addTearDown(() async {
        await sqlStore.close();
      });

      final now = DateTime.utc(2026, 11, 20, 20, 45);
      const actId = '358381cc-8795-4dc4-9d5e-71d8ef7f4052';
      const userId = '9e6823f1-ca06-4733-ba74-050040b9a151';

      final initialPoints = <RutePoint>[
        RutePoint(
          aktivitasId: actId,
          urutan: 0,
          lat: -7.9510,
          lng: 112.6140,
          elevasiM: 500,
          kecepatanMs: 1.2,
          direkamAt: now,
        ),
        RutePoint(
          aktivitasId: actId,
          urutan: 1,
          lat: -7.9520,
          lng: 112.6145,
          elevasiM: 501,
          kecepatanMs: 1.3,
          direkamAt: now.add(const Duration(seconds: 60)),
        ),
      ];

      final activity = Activity(
        id: actId,
        userId: userId,
        jenis: 'berjalan',
        mulaiAt: now,
        selesaiAt: now.add(const Duration(seconds: 238)),
        durasiS: 238,
        jarakM: 191.55,
        cadenceSpm: 72,
      );

      // Insert synced activity and its route points into SQLite.
      await sqlStore.mergeRemoteActivities(userId, [activity]);
      await sqlStore.saveRoutePoints(actId, initialPoints);
      expect((await sqlStore.getRoutePoints(actId)).length, 2);

      // Simulate listLocalActivities refreshing from Supabase and calling mergeRemoteActivities.
      await sqlStore.mergeRemoteActivities(userId, [
        activity.copyWith(validationStatus: 'verified'),
      ]);

      // Route points must NOT be cascade-deleted by mergeRemoteActivities!
      final afterMergePoints = await sqlStore.getRoutePoints(actId);
      expect(afterMergePoints.length, 2);
      expect(afterMergePoints.first.lat, closeTo(-7.9510, 1e-6));

      // Calling saveRoutePoints with an empty list must also preserve existing points.
      await sqlStore.saveRoutePoints(actId, const []);
      expect((await sqlStore.getRoutePoints(actId)).length, 2);
    });
  });
}
