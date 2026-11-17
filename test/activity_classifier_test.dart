import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pacer/src/local/memory_local_store.dart';
import 'package:pacer/src/sync/connectivity_service.dart';
import 'package:pacer/src/sync/sync_engine.dart';
import 'package:pacer/src/tracking/activity_classifier.dart';
import 'package:pacer/src/tracking/motion_sensors.dart';
import 'package:pacer/src/tracking/recorder.dart';

class _FakeMotionSensors implements MotionSensorProvider {
  final StreamController<OsMotionEvent> motionController =
      StreamController<OsMotionEvent>.broadcast();
  final StreamController<int> stepsController =
      StreamController<int>.broadcast();
  List<AccelSample> nextBurst = const [];
  int burstCalls = 0;

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
  }) async {
    burstCalls++;
    return nextBurst;
  }

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
  double alt = 10,
  double accuracy = 5,
  double speed = 0,
}) => Position(
  longitude: lng,
  latitude: lat,
  timestamp: at,
  accuracy: accuracy,
  altitude: alt,
  altitudeAccuracy: 3,
  heading: 0,
  headingAccuracy: 1,
  speed: speed,
  speedAccuracy: 1,
);

List<AccelSample> _footImpactBurst() {
  // 125 samples @ 25 Hz (5 seconds): periodic ~4.5 m/s^2 heel strikes every 400 ms (10 samples)
  return List<AccelSample>.generate(125, (i) {
    final phase = i % 10;
    final spike = phase == 2 ? 15.0 : (phase == 3 ? 11.5 : 9.8);
    return AccelSample(x: 0.4, y: spike, z: 0.3, timestampMs: i * 40);
  });
}

List<AccelSample> _smoothCabinBurst({double amplitude = 0.25}) {
  return List<AccelSample>.generate(125, (i) {
    final dy = amplitude * math.sin(i * 0.25);
    return AccelSample(x: 0.1, y: 9.81 + dy, z: 0.05, timestampMs: i * 40);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Layer 4 Walk-vs-Bike 6 Baseline Test Cases', () {
    test('Case 1: normal flat brisk walk stays verified as walk', () {
      final res = evaluateWalkToBikeWindow(
        SportType.walk,
        const TelemetryWindow(
          medianSpeedKmh: 5.0,
          p85SpeedKmh: 5.5,
          distanceMeters: 41.6, // stride ~0.69 m
          gradePercent: 0.0,
          steps: 60,
          osActivity: OsMotionLabel.walking,
          osConfidence: 92,
        ),
      );
      expect(res.isBikeDetected, isFalse);
      expect(res.isMismatch, isFalse);
      expect(res.detectedCategory, DetectedCategory.walk);
    });

    test('Case 2: downhill trail run with high step cadence is not flagged as bike', () {
      final res = evaluateWalkToBikeWindow(
        SportType.walk,
        const TelemetryWindow(
          medianSpeedKmh: 12.8,
          p85SpeedKmh: 13.6,
          distanceMeters: 106.7, // stride ~1.33 m
          gradePercent: -6.0,
          steps: 80,
          osActivity: OsMotionLabel.running,
          osConfidence: 90,
        ),
      );
      expect(res.isBikeDetected, isFalse);
    });

    test('Case 3: stealth cycling in walk mode with ON_BICYCLE OS label detects bike', () {
      final res = evaluateWalkToBikeWindow(
        SportType.walk,
        const TelemetryWindow(
          medianSpeedKmh: 18.0,
          p85SpeedKmh: 19.5,
          distanceMeters: 150.0,
          gradePercent: 0.0,
          steps: 0,
          osActivity: OsMotionLabel.onBicycle,
          osConfidence: 90,
        ),
      );
      expect(res.isBikeDetected, isTrue);
      expect(res.isMismatch, isTrue);
      expect(res.suggestedJenis, 'bersepeda');
    });

    test('Case 4: cycling with ambiguous speed & smooth accel when OS is UNKNOWN detects bike', () {
      final smoothFeatures = extractAccelBurstFeatures(_smoothCabinBurst(amplitude: 0.9));
      final res = evaluateWalkToBikeWindow(
        SportType.walk,
        TelemetryWindow(
          medianSpeedKmh: 14.5,
          p85SpeedKmh: 15.8,
          distanceMeters: 120.8,
          gradePercent: 0.0,
          steps: 0,
          osActivity: OsMotionLabel.unknown,
          osConfidence: 40,
          accelBurst: smoothFeatures,
        ),
      );
      expect(res.isBikeDetected, isTrue);
      expect(res.suggestedJenis, 'bersepeda');
    });

    test('Case 5: uphill run when pedometer is null but heel-strike accel confirms foot motion is not flagged as bike', () {
      final footFeatures = extractAccelBurstFeatures(_footImpactBurst());
      expect(footFeatures.heelStrikePeaks, greaterThanOrEqualTo(5));
      expect(footFeatures.isCyclingSignature, isFalse);

      final res = evaluateWalkToBikeWindow(
        SportType.walk,
        TelemetryWindow(
          medianSpeedKmh: 11.2,
          p85SpeedKmh: 12.0,
          distanceMeters: 93.3,
          gradePercent: 3.5,
          steps: null,
          osActivity: OsMotionLabel.unknown,
          osConfidence: 30,
          accelBurst: footFeatures,
        ),
      );
      expect(res.isBikeDetected, isFalse);
    });

    test('Case 6: car drive in walking mode triggers vehicle alert without cycling suggestion', () {
      final smoothVehicle = extractAccelBurstFeatures(_smoothCabinBurst(amplitude: 0.15));
      expect(smoothVehicle.isVehicleSignature, isTrue);

      final res = evaluateWalkToBikeWindow(
        SportType.walk,
        TelemetryWindow(
          medianSpeedKmh: 52.0,
          p85SpeedKmh: 56.0,
          distanceMeters: 433.3,
          gradePercent: 0.0,
          steps: 0,
          osActivity: OsMotionLabel.inVehicle,
          osConfidence: 95,
          accelBurst: smoothVehicle,
        ),
      );
      expect(res.isVehicleDetected, isTrue);
      expect(res.isMismatch, isTrue);
      expect(res.suggestedJenis, isNull);
    });
  });

  group('Multi-Activity Matrix & Downhill Guardrails', () {
    test('Walk -> Run & Walk -> Jog suggestions match sustained speed and running OS/cadence', () {
      final toRun = evaluateActivityWindow(
        SportType.walk,
        const TelemetryWindow(
          medianSpeedKmh: 11.4,
          p85SpeedKmh: 12.2,
          distanceMeters: 95.0,
          gradePercent: 0.0,
          steps: 82,
          osActivity: OsMotionLabel.running,
          osConfidence: 90,
        ),
      );
      expect(toRun.isMismatch, isTrue);
      expect(toRun.detectedCategory, DetectedCategory.run);
      expect(toRun.suggestedJenis, 'lari');

      final toJog = evaluateActivityWindow(
        SportType.walk,
        const TelemetryWindow(
          medianSpeedKmh: 8.3,
          p85SpeedKmh: 8.8,
          distanceMeters: 69.2,
          gradePercent: 0.0,
          steps: 74,
          osActivity: OsMotionLabel.running,
          osConfidence: 85,
        ),
      );
      expect(toJog.isMismatch, isTrue);
      expect(toJog.detectedCategory, DetectedCategory.jog);
      expect(toJog.suggestedJenis, 'joging');
    });

    test('Run -> Cycling & Run -> Walk cooldown detection work in Run mode', () {
      final toBike = evaluateActivityWindow(
        SportType.run,
        const TelemetryWindow(
          medianSpeedKmh: 26.0,
          p85SpeedKmh: 28.0,
          distanceMeters: 216.6,
          gradePercent: 0.0,
          steps: 0,
          osActivity: OsMotionLabel.onBicycle,
          osConfidence: 92,
        ),
      );
      expect(toBike.isMismatch, isTrue);
      expect(toBike.detectedCategory, DetectedCategory.ride);
      expect(toBike.suggestedJenis, 'bersepeda');

      final toWalk = evaluateActivityWindow(
        SportType.run,
        const TelemetryWindow(
          medianSpeedKmh: 4.5,
          p85SpeedKmh: 5.0,
          distanceMeters: 37.5, // stride 0.72 m
          gradePercent: 0.0,
          steps: 52,
          osActivity: OsMotionLabel.walking,
          osConfidence: 92,
        ),
      );
      expect(toWalk.isMismatch, isTrue);
      expect(toWalk.detectedCategory, DetectedCategory.walk);
      expect(toWalk.suggestedJenis, 'berjalan');
    });

    test('Cycling -> Foot detects running on bike mode while protecting genuine 54 km/h downhill rides', () {
      final footFeatures = extractAccelBurstFeatures(_footImpactBurst());
      final footInBike = evaluateActivityWindow(
        SportType.ride,
        TelemetryWindow(
          medianSpeedKmh: 9.8,
          p85SpeedKmh: 10.6,
          distanceMeters: 81.6,
          gradePercent: 0.0,
          steps: 78,
          osActivity: OsMotionLabel.running,
          osConfidence: 88,
          accelBurst: footFeatures,
        ),
      );
      expect(footInBike.isMismatch, isTrue);
      expect(footInBike.isVehicleDetected, isFalse);
      expect(footInBike.suggestedJenis, anyOf('lari', 'joging'));

      final steepDownhillRide = evaluateActivityWindow(
        SportType.ride,
        const TelemetryWindow(
          medianSpeedKmh: 54.0,
          p85SpeedKmh: 57.0,
          distanceMeters: 450.0,
          gradePercent: -6.5,
          steps: 0,
          osActivity: OsMotionLabel.onBicycle,
          osConfidence: 90,
        ),
      );
      expect(steepDownhillRide.isVehicleDetected, isFalse);
      expect(steepDownhillRide.isMismatch, isFalse);

      final flatCarInBike = evaluateActivityWindow(
        SportType.ride,
        const TelemetryWindow(
          medianSpeedKmh: 56.0,
          p85SpeedKmh: 62.0,
          distanceMeters: 466.7,
          gradePercent: 0.0,
          steps: 0,
          osActivity: OsMotionLabel.inVehicle,
          osConfidence: 92,
        ),
      );
      expect(flatCarInBike.isVehicleDetected, isTrue);
      expect(flatCarInBike.suggestedJenis, isNull);
    });
  });

  group('ActivityMismatchMonitor Hysteresis & Cooldown', () {
    test('requires 2 consecutive windows for Walk->Bike and enforces dismiss cooldown', () {
      final monitor = ActivityMismatchMonitor(
        dismissCooldown: const Duration(minutes: 3),
      );
      const bikeWin = TelemetryWindow(
        medianSpeedKmh: 19.0,
        p85SpeedKmh: 20.5,
        distanceMeters: 158.0,
        gradePercent: 0.0,
        steps: 0,
        osActivity: OsMotionLabel.onBicycle,
        osConfidence: 90,
      );
      const normalWalk = TelemetryWindow(
        medianSpeedKmh: 4.8,
        p85SpeedKmh: 5.2,
        distanceMeters: 40.0,
        gradePercent: 0.0,
        steps: 56,
        osActivity: OsMotionLabel.walking,
        osConfidence: 92,
      );

      final t0 = DateTime.utc(2026, 11, 17, 7, 0, 0);
      // Single bike window does not latch; resetting back to walk clears counter.
      expect(
        monitor.ingestWindow(selectedSport: SportType.walk, window: bikeWin, now: t0),
        isNull,
      );
      expect(monitor.consecutiveWindows, 1);
      expect(
        monitor.ingestWindow(selectedSport: SportType.walk, window: normalWalk, now: t0.add(const Duration(seconds: 30))),
        isNull,
      );
      expect(monitor.consecutiveWindows, 0);

      // Two consecutive bike windows latch the mismatch.
      monitor.ingestWindow(selectedSport: SportType.walk, window: bikeWin, now: t0.add(const Duration(seconds: 60)));
      final latched = monitor.ingestWindow(selectedSport: SportType.walk, window: bikeWin, now: t0.add(const Duration(seconds: 90)));
      expect(latched, isNotNull);
      expect(latched!.suggestedJenis, 'bersepeda');

      // Dismiss suppresses alerts until cooldown expires.
      monitor.dismiss(now: t0.add(const Duration(seconds: 95)));
      expect(monitor.activeMismatch, isNull);
      monitor.ingestWindow(selectedSport: SportType.walk, window: bikeWin, now: t0.add(const Duration(minutes: 2)));
      expect(monitor.activeMismatch, isNull);

      // After cooldown (> 95s + 3m = 275s), 2 consecutive windows re-latch.
      final afterCooldown = t0.add(const Duration(minutes: 5));
      monitor.ingestWindow(selectedSport: SportType.walk, window: bikeWin, now: afterCooldown);
      final relached = monitor.ingestWindow(
        selectedSport: SportType.walk,
        window: bikeWin,
        now: afterCooldown.add(const Duration(seconds: 30)),
      );
      expect(relached?.suggestedJenis, 'bersepeda');
    });

    test('requires 4 consecutive windows (120 s) before flagging Walk inside Run mode', () {
      final monitor = ActivityMismatchMonitor();
      const slowWalk = TelemetryWindow(
        medianSpeedKmh: 4.5,
        p85SpeedKmh: 5.0,
        distanceMeters: 37.5,
        gradePercent: 0.0,
        steps: 52,
        osActivity: OsMotionLabel.walking,
        osConfidence: 90,
      );

      for (var i = 0; i < 3; i++) {
        expect(
          monitor.ingestWindow(selectedSport: SportType.run, window: slowWalk),
          isNull,
        );
      }
      final latched = monitor.ingestWindow(
        selectedSport: SportType.run,
        window: slowWalk,
      );
      expect(latched, isNotNull);
      expect(latched!.suggestedJenis, 'berjalan');
    });
  });

  group('Layer 1 GpsSanitizer & Accel Trigger Gating', () {
    test('drops inaccurate, teleport, and implausible acceleration fixes while aggregating clean metrics', () {
      final sanitizer = GpsSanitizer();
      final t0 = DateTime.utc(2026, 11, 17, 6, 0, 0);

      // Dropped poor accuracy (> 20 m)
      final poorAcc = sanitizer.ingest(
        GpsFix(lat: -6.2000, lng: 106.8000, altitudeM: 10, speedMs: 1.5, accuracyM: 35.0, timestamp: t0),
      );
      expect(poorAcc.status, GpsIngestStatus.droppedAccuracy);

      // Anchor fix accepted
      final anchor = sanitizer.ingest(
        GpsFix(lat: -6.2000, lng: 106.8000, altitudeM: 10, speedMs: 1.4, accuracyM: 5.0, timestamp: t0.add(const Duration(seconds: 1))),
      );
      expect(anchor.accepted, isTrue);

      // Dropped teleport (> 110 km/h)
      final teleport = sanitizer.ingest(
        GpsFix(lat: -6.2100, lng: 106.8100, altitudeM: 10, speedMs: 50, accuracyM: 5.0, timestamp: t0.add(const Duration(seconds: 2))),
      );
      expect(teleport.status, GpsIngestStatus.droppedTeleport);

      // Steady walk ~5 km/h (~1.39 m/s, ~13.9 m per 10s, +0.000125 deg lat ~13.9m)
      final f1 = sanitizer.ingest(
        GpsFix(lat: -6.200125, lng: 106.8000, altitudeM: 11, speedMs: 1.39, accuracyM: 5.0, timestamp: t0.add(const Duration(seconds: 11))),
      );
      final f2 = sanitizer.ingest(
        GpsFix(lat: -6.200250, lng: 106.8000, altitudeM: 12, speedMs: 1.39, accuracyM: 5.0, timestamp: t0.add(const Duration(seconds: 21))),
      );
      expect(f1.accepted, isTrue);
      expect(f2.accepted, isTrue);

      // Sudden jump to ~72 km/h in 1s -> accel > 4 m/s^2 -> droppedImplausibleAccel
      final accelSpike = sanitizer.ingest(
        GpsFix(lat: -6.200430, lng: 106.8000, altitudeM: 12, speedMs: 20.0, accuracyM: 5.0, timestamp: t0.add(const Duration(seconds: 22))),
      );
      expect(accelSpike.status, GpsIngestStatus.droppedImplausibleAccel);

      final win = sanitizer.buildWindow(
        steps: 32,
        osActivity: OsMotionLabel.walking,
        osConfidence: 90,
      );
      expect(win.distanceMeters, closeTo(27.8, 1.5));
      expect(win.medianSpeedKmh, closeTo(5.0, 0.5));
      expect(win.gradePercent, greaterThan(5.0));
    });

    test('shouldTriggerAccelBurst stays quiet for confident slow walking and triggers in ambiguous band', () {
      expect(
        shouldTriggerAccelBurst(
          const TelemetryWindow(
            medianSpeedKmh: 1.8,
            p85SpeedKmh: 2.0,
            distanceMeters: 15,
            gradePercent: 0,
            steps: 20,
            osActivity: OsMotionLabel.walking,
            osConfidence: 90,
          ),
          selectedSport: SportType.walk,
        ),
        isFalse,
      );

      expect(
        shouldTriggerAccelBurst(
          const TelemetryWindow(
            medianSpeedKmh: 10.5,
            p85SpeedKmh: 11.2,
            distanceMeters: 87,
            gradePercent: 0,
            steps: 0,
            osActivity: OsMotionLabel.walking,
            osConfidence: 82,
          ),
          selectedSport: SportType.walk,
        ),
        isTrue,
      );
    });
  });

  group('RunRecorder Sensor Fusion & Live Reclassification', () {
    test('detects cycling mismatch via fake MotionSensorProvider, switches sport in draft, and persists metadata on finish', () async {
      final store = MemoryLocalStore();
      await store.setLastUserId('runner-1');
      final connectivity = ConnectivityService()..setTestOverride(false);
      final sync = SyncEngine(
        storeProvider: () => store,
        connectivity: connectivity,
      );
      final sensors = _FakeMotionSensors();
      final recorder = RunRecorder(
        store: store,
        sync: sync,
        userIdProvider: () async => 'runner-1',
        sensors: sensors,
        enableGpsStream: false,
      );
      addTearDown(() async {
        recorder.dispose();
        sync.dispose();
        connectivity.dispose();
      });

      await recorder.start('berjalan');
      // Let _initMobileSensors complete permission + startMonitoring microtasks.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final t0 = DateTime.utc(2026, 11, 17, 7, 0, 0);

      // Push 3 steady cycling-speed GPS fixes (18 km/h = 5.0 m/s -> ~0.00045 deg lat per 10s)
      recorder.recordPositionForTest(
        _gpsPos(lat: -6.20000, lng: 106.80000, at: t0, speed: 5.0),
        enforceKinematics: true,
      );
      recorder.recordPositionForTest(
        _gpsPos(lat: -6.20045, lng: 106.80000, at: t0.add(const Duration(seconds: 10)), speed: 5.0),
        enforceKinematics: true,
      );
      recorder.recordPositionForTest(
        _gpsPos(lat: -6.20090, lng: 106.80000, at: t0.add(const Duration(seconds: 20)), speed: 5.0),
        enforceKinematics: true,
      );

      // OS reports high-confidence ON_BICYCLE
      sensors.motionController.add(
        OsMotionEvent(
          label: OsMotionLabel.onBicycle,
          confidence: 92,
          timestamp: t0.add(const Duration(seconds: 21)),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));

      await recorder.evaluateWindowForTest(now: t0.add(const Duration(seconds: 21)));
      expect(recorder.activeMismatch, isNull); // Hysteresis 1/2

      await recorder.evaluateWindowForTest(now: t0.add(const Duration(seconds: 22)));
      expect(recorder.activeMismatch, isNotNull);
      expect(recorder.activeMismatch!.suggestedJenis, 'bersepeda');

      // User accepts switch mid-session
      final draftId = recorder.aktivitasId!;
      await recorder.switchSport('bersepeda');
      expect(recorder.jenis, 'bersepeda');
      expect(recorder.activeMismatch, isNull);
      final draft = await store.loadActiveDraft('runner-1');
      expect(draft?.id, draftId);
      expect(draft?.jenis, 'bersepeda');

      final summary = await recorder.finish();
      expect(summary, isNotNull);
      expect(summary!.jenis, 'bersepeda');

      // Trigger another session where user does NOT switch despite pocket step noise
      await recorder.start('berjalan');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final t1 = DateTime.utc(2026, 11, 17, 8, 0, 0);
      sensors.stepsController.add(2);
      await Future<void>.delayed(const Duration(milliseconds: 5));

      recorder.recordPositionForTest(
        _gpsPos(lat: -6.21000, lng: 106.80000, at: t1, speed: 5.0),
        enforceKinematics: true,
      );
      recorder.recordPositionForTest(
        _gpsPos(lat: -6.21045, lng: 106.80000, at: t1.add(const Duration(seconds: 10)), speed: 5.0),
        enforceKinematics: true,
      );
      sensors.motionController.add(
        OsMotionEvent(
          label: OsMotionLabel.onBicycle,
          confidence: 94,
          timestamp: t1.add(const Duration(seconds: 11)),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await recorder.evaluateWindowForTest(now: t1.add(const Duration(seconds: 11)));
      await recorder.evaluateWindowForTest(now: t1.add(const Duration(seconds: 12)));
      expect(recorder.activeMismatch?.suggestedJenis, 'bersepeda');

      final flaggedSummary = await recorder.finish();
      expect(flaggedSummary?.suggestedSport, 'bersepeda');
      expect(flaggedSummary?.validationStatus, 'flagged_ride');
      final storedAct = await store.getActivity(flaggedSummary!.aktivitasId);
      expect(storedAct?.activity.suggestedSport, 'bersepeda');
      expect(storedAct?.activity.validationStatus, 'flagged_ride');
    });
  });
}
