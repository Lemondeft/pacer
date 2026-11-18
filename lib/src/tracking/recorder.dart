import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:uuid/uuid.dart';

import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/auth/auth_repository.dart';
import 'package:pacer/src/cache/pacer_cache.dart';
import 'package:pacer/src/demo/pacer_dummy_data.dart';
import 'package:pacer/src/local/local_models.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/sync/sync_engine.dart';
import 'package:pacer/src/tracking/activity_classifier.dart';
import 'package:pacer/src/tracking/motion_sensors.dart';

/// Foreground GPS run recorder (DFD 2.0 tracking). Offline-first & crash-safe.
///
/// Lifecycle: [start] creates an offline local draft row with a client UUID,
/// filters incoming GPS fixes through Layer 1 [GpsSanitizer], fuses Layer 2/3 OS
/// motion & targeted 25 Hz accelerometer bursts every 30 s through Layer 4
/// [ActivityMismatchMonitor], incremental checkpoints persist points every 5
/// fixes/seconds; [pause]/[resume] freeze fixes, clock, and sensors; [finish]
/// atomically commits activity + cadence + route points locally and triggers sync.
class RunRecorder extends ChangeNotifier {
  static const double maxAccuracyM = DetectionThresholds.maxGpsAccuracyMeters;
  static const int distanceFilterM = 5;
  static const int checkpointPointInterval = 5;
  static const Duration checkpointTimeInterval = Duration(seconds: 5);
  static const Duration classificationInterval = Duration(
    seconds: DetectionThresholds.windowDurationSeconds,
  );

  final LocalStore? _storeOverride;
  final SyncEngine? _syncOverride;
  final Future<String?> Function()? _resolveUserId;
  final MotionSensorProvider _sensors;
  final bool _gpsStreamEnabled;

  RunRecorder({
    LocalStore? store,
    SyncEngine? sync,
    Future<String?> Function()? userIdProvider,
    MotionSensorProvider? sensors,
    bool enableGpsStream = true,
  }) : _storeOverride = store,
       _syncOverride = sync,
       _resolveUserId = userIdProvider,
       _sensors = sensors ?? PlatformMotionSensorProvider(),
       _gpsStreamEnabled = enableGpsStream;

  LocalStore get _store => _storeOverride ?? LocalStore.instance;
  SyncEngine get _sync => _syncOverride ?? SyncEngine.instance;

  StreamSubscription<Position>? _sub;
  StreamSubscription<OsMotionEvent>? _osMotionSub;
  StreamSubscription<int>? _stepsSub;
  Timer? _simTimer;
  Timer? _classificationTimer;
  bool _simMode = false;
  final Stopwatch _clock = Stopwatch();
  Duration _baseElapsed = Duration.zero;
  final List<_Fix> _fixes = [];

  final GpsSanitizer _sanitizer = GpsSanitizer();
  final ActivityMismatchMonitor _mismatchMonitor = ActivityMismatchMonitor();
  OsMotionLabel _lastOsActivity = OsMotionLabel.unknown;
  int _lastOsConfidence = 0;
  bool _hasStepEvents = false;
  int _windowSteps = 0;
  int _totalSteps = 0;
  bool _burstInFlight = false;
  final Set<int> _pauseBreakIndices = <int>{};
  bool _needsBreakOnNextFix = false;
  int _totalWindows = 0;
  int _cyclingBurstWindows = 0;
  int _bikeOsWindows = 0;
  double _peakWindowSpeedKmh = 0;
  int? _peakWindowCadenceSpm;

  String? _aktivitasId;
  String? _userId;
  DateTime? _mulaiAt;
  String _jenis = 'lari';
  bool _started = false;
  bool _recording = false;
  bool _starting = false;
  bool _finishing = false;
  double _distanceM = 0;
  String? _error;
  double? _anchorLat;
  double? _anchorLng;
  bool _disposed = false;

  int _checkpointedCount = 0;
  DateTime _lastCheckpointAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _checkpointInFlight;
  bool _checkpointQueued = false;

  bool get started => _started;
  bool get recording => _recording;
  double get distanceM => _distanceM;
  Duration get elapsed => _baseElapsed + _clock.elapsed;
  String? get error => _error;
  String? get aktivitasId => _aktivitasId;
  String get jenis => _jenis;

  ActivityMismatch? get activeMismatch => _mismatchMonitor.activeMismatch;

  int? get liveCadenceSpm {
    final secs = elapsed.inSeconds;
    if (!_hasStepEvents || secs < 10 || _totalSteps <= 0) return null;
    return (_totalSteps / (secs / 60.0)).round().clamp(30, 240);
  }

  LatLng? get anchor => _fixes.isNotEmpty
      ? LatLng(_fixes.first.lat, _fixes.first.lng)
      : (_anchorLat != null && _anchorLng != null
            ? LatLng(_anchorLat!, _anchorLng!)
            : null);

  List<LatLng> get points => [for (final f in _fixes) LatLng(f.lat, f.lng)];

  Set<int> get pauseBreakIndices => Set<int>.unmodifiable(_pauseBreakIndices);

  int get pointCount => _fixes.length;

  Future<String> _requireUserId() async {
    final provided = await _resolveUserId?.call();
    if (provided != null && provided.isNotEmpty) return provided;
    final resolved = await AuthRepository(store: _store).resolveUserId();
    return resolved ?? PacerDummyData.demoUserId;
  }

  /// Location service + permission gate. False leaves state untouched.
  Future<bool> ensureGps() async {
    final service = await Geolocator.isLocationServiceEnabled();
    if (!service) {
      _error = 'gpsOff';
      notifyListeners();
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _error = 'gpsDenied';
      notifyListeners();
      return false;
    }
    _error = null;
    notifyListeners();
    return true;
  }

  void _resetTrackingTelemetry() {
    _sanitizer.reset();
    _mismatchMonitor.reset();
    _lastOsActivity = OsMotionLabel.unknown;
    _lastOsConfidence = 0;
    _hasStepEvents = false;
    _windowSteps = 0;
    _totalSteps = 0;
    _burstInFlight = false;
    _pauseBreakIndices.clear();
    _needsBreakOnNextFix = false;
    _totalWindows = 0;
    _cyclingBurstWindows = 0;
    _bikeOsWindows = 0;
    _peakWindowSpeedKmh = 0;
    _peakWindowCadenceSpm = null;
  }

  void _startSensors({required bool requestPermission}) {
    _stopSensors();
    if (requestPermission) {
      unawaited(_initMobileSensors());
    } else {
      _subscribeSensorStreams();
    }
    _classificationTimer = Timer.periodic(
      classificationInterval,
      (_) => unawaited(_evaluateCurrentWindow()),
    );
  }

  Future<void> _initMobileSensors() async {
    try {
      await _sensors.ensureMotionPermission();
      if (_disposed || !_started || !_recording) return;
      await _sensors.startMonitoring();
      if (_disposed || !_started || !_recording) return;
      _subscribeSensorStreams();
    } catch (_) {
      // Safe fallback to GPS + targeted accel when motion APIs are denied.
    }
  }

  void _subscribeSensorStreams() {
    _osMotionSub?.cancel();
    _stepsSub?.cancel();
    _osMotionSub = _sensors.osMotionStream.listen((event) {
      if (_disposed || !_recording) return;
      _lastOsActivity = event.label;
      _lastOsConfidence = event.confidence;
    });
    _stepsSub = _sensors.stepDeltaStream.listen((delta) {
      if (_disposed || !_recording || delta <= 0) return;
      _hasStepEvents = true;
      _windowSteps += delta;
      _totalSteps += delta;
    });
  }

  void _stopSensors() {
    _classificationTimer?.cancel();
    _classificationTimer = null;
    _osMotionSub?.cancel();
    _osMotionSub = null;
    _stepsSub?.cancel();
    _stepsSub = null;
    unawaited(_sensors.stopMonitoring());
  }

  Future<void> _evaluateCurrentWindow({DateTime? now}) async {
    if (_disposed || !_started || !_recording) return;
    final stepsInWindow = _hasStepEvents ? _windowSteps : null;
    _windowSteps = 0;

    final sport = sportTypeFromJenis(_jenis);
    final baseWindow = _sanitizer.buildWindow(
      steps: stepsInWindow,
      osActivity: _lastOsActivity,
      osConfidence: _lastOsConfidence,
      now: now,
    );

    AccelBurstFeatures? burst;
    if (!_burstInFlight &&
        shouldTriggerAccelBurst(baseWindow, selectedSport: sport)) {
      _burstInFlight = true;
      try {
        final samples = await _sensors.sampleAccelBurst();
        if (_disposed || !_started) return;
        if (samples.length >= 10) {
          burst = extractAccelBurstFeatures(samples);
        }
      } catch (_) {
        // Non-fatal: continue with OS + stride + kinematics.
      } finally {
        _burstInFlight = false;
      }
    }

    final prevMismatch = _mismatchMonitor.activeMismatch;
    final windowWithBurst = TelemetryWindow(
      medianSpeedKmh: baseWindow.medianSpeedKmh,
      p85SpeedKmh: baseWindow.p85SpeedKmh,
      distanceMeters: baseWindow.distanceMeters,
      gradePercent: baseWindow.gradePercent,
      steps: baseWindow.steps,
      osActivity: baseWindow.osActivity,
      osConfidence: baseWindow.osConfidence,
      accelBurst: burst,
    );
    _recordWindowTelemetry(windowWithBurst, stepsInWindow);
    final nextMismatch = _mismatchMonitor.ingestWindow(
      selectedSport: sport,
      window: windowWithBurst,
      now: now,
    );
    if (!identical(prevMismatch, nextMismatch) && !_disposed) {
      notifyListeners();
    }
  }

  void _recordWindowTelemetry(TelemetryWindow w, int? stepsInWindow) {
    _totalWindows++;
    if (w.accelBurst?.isCyclingSignature == true) _cyclingBurstWindows++;
    if (w.osActivity == OsMotionLabel.onBicycle &&
        w.osConfidence >= DetectionThresholds.minOsConfidence) {
      _bikeOsWindows++;
    }
    if (w.medianSpeedKmh >= _peakWindowSpeedKmh) {
      _peakWindowSpeedKmh = w.medianSpeedKmh;
      if (stepsInWindow != null) {
        _peakWindowCadenceSpm = (stepsInWindow * 2).clamp(0, 240);
      } else if (w.accelBurst?.estimatedCadenceSpm != null) {
        _peakWindowCadenceSpm = w.accelBurst!.estimatedCadenceSpm;
      }
    }
  }

  Map<String, dynamic>? _buildMotionSummary() {
    if (_totalWindows == 0 && _bikeOsWindows == 0 && _cyclingBurstWindows == 0) {
      return null;
    }
    return {
      'total_windows': _totalWindows,
      'cycling_burst_windows': _cyclingBurstWindows,
      'bike_os_windows': _bikeOsWindows,
      'max_window_kmh': double.parse(_peakWindowSpeedKmh.toStringAsFixed(2)),
      if (_peakWindowCadenceSpm != null)
        'peak_window_cadence_spm': _peakWindowCadenceSpm,
    };
  }

  @visibleForTesting
  Future<void> evaluateWindowForTest({DateTime? now}) =>
      _evaluateCurrentWindow(now: now);

  /// Switches the active sport mid-run, persists draft sport, and resets hysteresis.
  Future<void> switchSport(String newJenis) async {
    if (!aktivitasJenis.contains(newJenis)) {
      throw ArgumentError.value(newJenis, 'newJenis', 'must be a known jenis');
    }
    _jenis = newJenis;
    _mismatchMonitor.reset();
    final id = _aktivitasId;
    if (id != null && _started) {
      await _store.updateDraftSport(id, newJenis);
    }
    notifyListeners();
  }

  /// Dismisses the active mismatch/vehicle prompt and arms cooldown.
  void dismissMismatchPrompt({DateTime? now}) {
    _mismatchMonitor.dismiss(now: now);
    notifyListeners();
  }

  /// Creates the local draft workout and starts GPS + sensor tracking offline-first.
  Future<void> start(String jenis) async {
    if (_started || _starting) return;
    if (!aktivitasJenis.contains(jenis)) {
      throw ArgumentError.value(jenis, 'jenis', 'must be a known jenis');
    }
    _starting = true;
    try {
      final uid = await _requireUserId();
      final id = const Uuid().v4();
      final now = DateTime.now().toUtc();
      await _store.saveDraftStart(
        id: id,
        userId: uid,
        jenis: jenis,
        mulaiAt: now,
      );
      _aktivitasId = id;
      _userId = uid;
      _mulaiAt = now;
      _jenis = jenis;
      _fixes.clear();
      _checkpointedCount = 0;
      _distanceM = 0;
      _anchorLat = null;
      _anchorLng = null;
      _baseElapsed = Duration.zero;
      _clock.reset();
      _lastCheckpointAt = DateTime.now();
      _resetTrackingTelemetry();
      _started = true;
      _resumeStream();
      notifyListeners();
    } finally {
      _starting = false;
    }
  }

  /// Synthetic-fix mode for GPS-less platforms (Linux desktop): creates a local
  /// draft offline-first and feeds drifting fixes through the real pipeline.
  Future<void> simulate([String jenis = 'lari']) async {
    if (_started || _starting) return;
    final sport = aktivitasJenis.contains(jenis) ? jenis : 'lari';
    _starting = true;
    try {
      final uid = await _requireUserId();
      final id = const Uuid().v4();
      final now = DateTime.now().toUtc();
      await _store.saveDraftStart(
        id: id,
        userId: uid,
        jenis: sport,
        mulaiAt: now,
      );
      _aktivitasId = id;
      _userId = uid;
      _mulaiAt = now;
      _jenis = sport;
      _fixes.clear();
      _checkpointedCount = 0;
      _distanceM = 0;
      _anchorLat = null;
      _anchorLng = null;
      _baseElapsed = Duration.zero;
      _clock.reset();
      _lastCheckpointAt = DateTime.now();
      _resetTrackingTelemetry();
      _started = true;
      _simMode = true;
      _armSimTimer();
      _startSensors(requestPermission: false);
      _clock.start();
      _recording = true;
      notifyListeners();
    } finally {
      _starting = false;
    }
  }

  /// Hydrates a crash-recovered draft run in paused state so the user can
  /// either resume tracking or finish and save it.
  void restoreDraft(ActiveDraftRun draft) {
    _sub?.cancel();
    _sub = null;
    _simTimer?.cancel();
    _simTimer = null;
    _stopSensors();
    _simMode = false;
    _clock.stop();
    _clock.reset();
    _resetTrackingTelemetry();

    _aktivitasId = draft.id;
    _userId = draft.userId;
    _jenis = draft.jenis;
    _mulaiAt = draft.mulaiAt;
    _baseElapsed = Duration(seconds: draft.elapsedS);
    _distanceM = draft.distanceM;
    _fixes
      ..clear()
      ..addAll([
        for (final p in draft.points)
          _Fix(
            lat: p.lat,
            lng: p.lng,
            speed: p.kecepatanMs,
            alt: p.elevasiM ?? 0,
            at: p.direkamAt ?? draft.mulaiAt,
          ),
      ]);
    for (final f in _fixes) {
      _sanitizer.ingest(
        GpsFix(
          lat: f.lat,
          lng: f.lng,
          altitudeM: f.alt,
          speedMs: f.speed,
          accuracyM: 5,
          timestamp: f.at,
        ),
      );
    }
    _checkpointedCount = _fixes.length;
    _lastCheckpointAt = DateTime.now();
    _started = true;
    _recording = false;
    _error = null;
    notifyListeners();
  }

  int _simTick = 0;

  void _armSimTimer() {
    _simTimer?.cancel();
    _simTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _simTick++;
      // ~2.8 m/s jogging velocity (0.00002° lat + 0.000015° lng per 1 s).
      _onFix(
        Position(
          latitude: -6.2296 + _simTick * 0.00002,
          longitude: 106.8294 + _simTick * 0.000015,
          timestamp: DateTime.now(),
          accuracy: 5,
          altitude: 10,
          altitudeAccuracy: 3,
          heading: 90,
          headingAccuracy: 5,
          speed: 2.8,
          speedAccuracy: 0.5,
        ),
      );
    });
  }

  void pause() {
    _sub?.cancel();
    _sub = null;
    _simTimer?.cancel();
    _simTimer = null;
    _stopSensors();
    _clock.stop();
    _recording = false;
    if (_fixes.isNotEmpty) _needsBreakOnNextFix = true;
    unawaited(_flushCheckpoint());
    notifyListeners();
  }

  void resume() {
    if (!_started || _recording) return;
    if (_needsBreakOnNextFix && _fixes.isNotEmpty) {
      _sanitizer.markPauseBreak();
    }
    if (_simMode) {
      _armSimTimer();
      _startSensors(requestPermission: false);
      _clock.start();
      _recording = true;
      notifyListeners();
      return;
    }
    _resumeStream();
    notifyListeners();
  }

  void _resumeStream() {
    _sub?.cancel();
    if (_gpsStreamEnabled) {
      _sub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: distanceFilterM,
            ),
          ).listen(
            _onFix,
            onError: (_) {
              pause();
            },
          );
    } else {
      _sub = null;
    }
    _startSensors(requestPermission: true);
    _clock.start();
    _recording = true;
    unawaited(_captureInitialFix());
  }

  Future<void> _captureInitialFix() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (_disposed || !_started || _simMode) return;
      if (last != null &&
          !GpsSanitizer.isNullIsland(last.latitude, last.longitude) &&
          isValidLatLng(last.latitude, last.longitude)) {
        _anchorLat = last.latitude;
        _anchorLng = last.longitude;
        final ageSec = DateTime.now()
            .toUtc()
            .difference(last.timestamp.toUtc())
            .inSeconds;
        // Stale cached coordinates (>30s or >15m) center preview map only;
        // never inject stale fixes into distance or speed calculations.
        if (_fixes.isEmpty &&
            _recording &&
            ageSec >= 0 &&
            ageSec <= 30 &&
            last.accuracy <= 15.0) {
          _onFix(last);
        } else {
          notifyListeners();
        }
      }
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (_disposed || !_started || !_recording || _simMode) return;
      if (!GpsSanitizer.isNullIsland(current.latitude, current.longitude) &&
          isValidLatLng(current.latitude, current.longitude)) {
        _anchorLat = current.latitude;
        _anchorLng = current.longitude;
        if (_fixes.isEmpty) {
          _onFix(current);
        }
      }
    } catch (_) {
      // Optional initial seed; continuous stream remains primary.
    }
  }

  @visibleForTesting
  void recordPositionForTest(Position p, {bool enforceKinematics = false}) {
    final sameTimestampFixture =
        !enforceKinematics &&
        _fixes.isNotEmpty &&
        p.timestamp == _fixes.last.at;
    if (sameTimestampFixture) {
      if (p.accuracy > maxAccuracyM) return;
      final prev = _fixes.last;
      _distanceM += haversineMeters(prev.lat, prev.lng, p.latitude, p.longitude);
      _appendAcceptedFix(p);
      return;
    }
    _onFix(p);
  }

  void _onFix(Position p) {
    final result = _sanitizer.ingest(
      GpsFix(
        lat: p.latitude,
        lng: p.longitude,
        altitudeM: p.altitude,
        speedMs: p.speed < 0 ? null : p.speed,
        accuracyM: p.accuracy,
        timestamp: p.timestamp,
      ),
    );
    if (!result.accepted) return;
    _distanceM += result.segmentDistanceMeters;
    _appendAcceptedFix(p);
  }

  void _appendAcceptedFix(Position p) {
    if (_needsBreakOnNextFix) {
      if (_fixes.isNotEmpty) {
        _pauseBreakIndices.add(_fixes.length);
      }
      _needsBreakOnNextFix = false;
    }
    _fixes.add(
      _Fix(
        lat: p.latitude,
        lng: p.longitude,
        // Unknown speed arrives as -1: persist null, never negative.
        speed: p.speed < 0 ? null : p.speed,
        alt: p.altitude,
        at: p.timestamp,
      ),
    );
    final pendingPts = _fixes.length - _checkpointedCount;
    final sinceCheckpoint = DateTime.now().difference(_lastCheckpointAt);
    if (pendingPts >= checkpointPointInterval ||
        sinceCheckpoint >= checkpointTimeInterval) {
      unawaited(_flushCheckpoint());
    }
    notifyListeners();
  }

  Future<void> _flushCheckpoint() async {
    final id = _aktivitasId;
    if (id == null || !_started) return;
    if (_checkpointInFlight != null) {
      _checkpointQueued = true;
      await _checkpointInFlight;
      return;
    }
    final completer = Completer<void>();
    _checkpointInFlight = completer.future;
    try {
      final targetLen = _fixes.length;
      final newPoints = <RutePoint>[
        for (var i = _checkpointedCount; i < targetLen; i++)
          RutePoint(
            aktivitasId: id,
            urutan: i,
            lat: _fixes[i].lat,
            lng: _fixes[i].lng,
            elevasiM: _fixes[i].alt,
            kecepatanMs: _fixes[i].speed,
            direkamAt: _fixes[i].at,
          ),
      ];
      await _store.checkpointDraft(
        id: id,
        elapsedS: elapsed.inSeconds,
        distanceM: _distanceM,
        newPoints: newPoints,
      );
      _checkpointedCount = targetLen;
      _lastCheckpointAt = DateTime.now();
    } catch (_) {
      // Non-fatal: full points are also persisted atomically on finish().
    } finally {
      _checkpointInFlight = null;
      completer.complete();
    }
    if (_checkpointQueued) {
      _checkpointQueued = false;
      await _flushCheckpoint();
    }
  }

  /// Abandons an open recording and deletes its local draft row & points.
  Future<bool> discard() async {
    final id = _aktivitasId;
    _sub?.cancel();
    _sub = null;
    _simTimer?.cancel();
    _simTimer = null;
    _stopSensors();
    _simMode = false;
    _clock.stop();
    _checkpointQueued = false;
    await _checkpointInFlight;
    _clock.reset();
    _baseElapsed = Duration.zero;
    _recording = false;
    _started = false;
    _starting = false;
    _aktivitasId = null;
    _userId = null;
    _mulaiAt = null;
    _fixes.clear();
    _checkpointedCount = 0;
    _distanceM = 0;
    _anchorLat = null;
    _anchorLng = null;
    _resetTrackingTelemetry();
    notifyListeners();
    if (id == null) return false;
    await _store.discardDraft(id);
    return true;
  }

  /// Atomically commits workout, route points, and sync outbox item locally,
  /// then triggers background sync. Returns [RunSummary] reliably even offline.
  Future<RunSummary?> finish({List<String>? challengeIds}) async {
    if (!_started || _finishing) return null;
    _finishing = true;
    try {
      _sub?.cancel();
      _sub = null;
      _simTimer?.cancel();
      _simTimer = null;
      _stopSensors();
      _clock.stop();
      await _checkpointInFlight;

      final id = _aktivitasId;
      final uid = _userId ?? await _requireUserId();
      if (id == null) return null;

      final selesai = DateTime.now().toUtc();
      final totalDurationS = elapsed.inSeconds;
      final startAt = _mulaiAt ?? selesai.subtract(elapsed);
      final cadence = liveCadenceSpm;
      final mismatch = _mismatchMonitor.activeMismatch;
      final initialValidationStatus = mismatch == null
          ? null
          : (mismatch.isVehicleDetected
                ? 'flagged_vehicle'
                : (mismatch.suggestedJenis == 'bersepeda'
                      ? 'flagged_ride'
                      : 'flagged_mismatch'));
      final points = <RutePoint>[
        for (var i = 0; i < _fixes.length; i++)
          RutePoint(
            aktivitasId: id,
            urutan: i,
            lat: _fixes[i].lat,
            lng: _fixes[i].lng,
            elevasiM: _fixes[i].alt,
            kecepatanMs: _fixes[i].speed,
            direkamAt: _fixes[i].at,
          ),
      ];
      final totalDist = _distanceM;
      final sport = _jenis;
      final motionSummary = _buildMotionSummary();
      final anchorLat = _fixes.isNotEmpty ? _fixes.first.lat : _anchorLat;
      final anchorLng = _fixes.isNotEmpty ? _fixes.first.lng : _anchorLng;

      await _store.finalizeRunAtomic(
        id: id,
        userId: uid,
        jenis: sport,
        mulaiAt: startAt,
        selesaiAt: selesai,
        durasiS: totalDurationS,
        jarakM: totalDist,
        allPoints: points,
        challengeIds: challengeIds,
        suggestedSport: mismatch?.suggestedJenis,
        validationStatus: initialValidationStatus,
        cadenceSpm: cadence,
        osMotionSummary: motionSummary,
      );

      PacerCache.instance.invalidatePrefix('activities_');
      PacerCache.instance.invalidatePrefix('streak_');
      PacerCache.instance.invalidatePrefix('leaderboard_');
      if (uid != PacerDummyData.demoUserId) {
        await _sync.refreshCounts(userId: uid);
        unawaited(_sync.triggerSync(userId: uid));
      }

      _simMode = false;
      _recording = false;
      _started = false;
      _aktivitasId = null;
      _userId = null;
      _mulaiAt = null;
      _fixes.clear();
      _checkpointedCount = 0;
      _distanceM = 0;
      _anchorLat = null;
      _anchorLng = null;
      _baseElapsed = Duration.zero;
      _clock.reset();
      _resetTrackingTelemetry();
      notifyListeners();

      return RunSummary(
        aktivitasId: id,
        jenis: sport,
        jarakM: totalDist,
        durasiS: totalDurationS,
        pointCount: points.length,
        points: List<RutePoint>.unmodifiable(points),
        anchorLat: anchorLat,
        anchorLng: anchorLng,
        challengeIds: challengeIds ?? const [],
        suggestedSport: mismatch?.suggestedJenis,
        validationStatus: initialValidationStatus,
        cadenceSpm: cadence,
      );
    } finally {
      _finishing = false;
    }
  }

  /// Pace sec/km from live totals after warmup floor; null before 20 m & 5 s.
  double? get paceSecPerKm =>
      (_distanceM >= 20.0 && elapsed.inSeconds >= 5)
          ? elapsed.inSeconds / (_distanceM / 1000)
          : null;

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _simTimer?.cancel();
    _stopSensors();
    if (_started) {
      unawaited(_flushCheckpoint());
    }
    _sensors.dispose();
    super.dispose();
  }
}

class _Fix {
  final double lat;
  final double lng;
  final double? speed;
  final double alt;
  final DateTime at;
  const _Fix({
    required this.lat,
    required this.lng,
    required this.speed,
    required this.alt,
    required this.at,
  });
}

/// What [RunRecorder.finish] persisted, for the finish screen.
class RunSummary {
  final String aktivitasId;
  final String jenis;
  final double jarakM;
  final int durasiS;
  final int pointCount;
  final List<RutePoint> points;
  final double? anchorLat;
  final double? anchorLng;
  final List<String> challengeIds;
  final String? suggestedSport;
  final String? validationStatus;
  final int? cadenceSpm;
  const RunSummary({
    required this.aktivitasId,
    required this.jenis,
    required this.jarakM,
    required this.durasiS,
    required this.pointCount,
    this.points = const [],
    this.anchorLat,
    this.anchorLng,
    this.challengeIds = const [],
    this.suggestedSport,
    this.validationStatus,
    this.cadenceSpm,
  });
}
