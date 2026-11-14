import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:uuid/uuid.dart';

import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/auth/auth_repository.dart';
import 'package:pacer/src/cache/pacer_cache.dart';
import 'package:pacer/src/local/local_models.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/sync/sync_engine.dart';

/// Foreground GPS run recorder (DFD 2.0 tracking). Offline-first & crash-safe.
///
/// Lifecycle: [start] creates an offline local draft row with a client UUID
/// and listens to GPS fixes without requiring network connectivity; incremental
/// checkpoints persist points every 5 fixes/seconds; [pause]/[resume] freeze
/// both fixes and the clock; [finish] atomically commits the finished activity,
/// route points, and outbox sync item locally, then triggers background sync.
class RunRecorder extends ChangeNotifier {
  static const double maxAccuracyM = 20;
  static const int distanceFilterM = 5;
  static const int checkpointPointInterval = 5;
  static const Duration checkpointTimeInterval = Duration(seconds: 5);

  final LocalStore? _storeOverride;
  final SyncEngine? _syncOverride;
  final Future<String?> Function()? _userIdProvider;

  RunRecorder({
    LocalStore? store,
    SyncEngine? sync,
    this._userIdProvider,
  }) : _storeOverride = store,
       _syncOverride = sync;

  LocalStore get _store => _storeOverride ?? LocalStore.instance;
  SyncEngine get _sync => _syncOverride ?? SyncEngine.instance;

  StreamSubscription<Position>? _sub;
  Timer? _simTimer;
  bool _simMode = false;
  final Stopwatch _clock = Stopwatch();
  Duration _baseElapsed = Duration.zero;
  final List<_Fix> _fixes = [];

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

  LatLng? get anchor => _fixes.isNotEmpty
      ? LatLng(_fixes.first.lat, _fixes.first.lng)
      : (_anchorLat != null && _anchorLng != null
            ? LatLng(_anchorLat!, _anchorLng!)
            : null);

  List<LatLng> get points => [for (final f in _fixes) LatLng(f.lat, f.lng)];

  int get pointCount => _fixes.length;

  Future<String> _requireUserId() async {
    final provided = await _userIdProvider?.call();
    final uid =
        provided ?? await AuthRepository(store: _store).resolveUserId();
    if (uid == null) throw StateError('No signed-in user.');
    return uid;
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

  /// Creates the local draft workout and starts GPS tracking offline-first.
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
      _started = true;
      _simMode = true;
      _armSimTimer();
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
    _simMode = false;
    _clock.stop();
    _clock.reset();

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
      _onFix(
        Position(
          latitude: -6.2296 + _simTick * 0.0001,
          longitude: 106.8294 + _simTick * 0.00007,
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
    _clock.stop();
    _recording = false;
    unawaited(_flushCheckpoint());
    notifyListeners();
  }

  void resume() {
    if (!_started || _recording) return;
    if (_simMode) {
      _armSimTimer();
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
    _clock.start();
    _recording = true;
    unawaited(_captureInitialFix());
  }

  Future<void> _captureInitialFix() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (_disposed || !_started || _simMode) return;
      if (last != null) {
        _anchorLat = last.latitude;
        _anchorLng = last.longitude;
        if (_fixes.isEmpty && last.accuracy <= maxAccuracyM && _recording) {
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
      _anchorLat = current.latitude;
      _anchorLng = current.longitude;
      if (_fixes.isEmpty) {
        _onFix(current);
      }
    } catch (_) {
      // Optional initial seed; continuous stream remains primary.
    }
  }

  @visibleForTesting
  void recordPositionForTest(Position p) => _onFix(p);

  void _onFix(Position p) {
    if (p.accuracy > maxAccuracyM) return;
    final prev = _fixes.isEmpty ? null : _fixes.last;
    if (prev != null) {
      _distanceM += Geolocator.distanceBetween(
        prev.lat,
        prev.lng,
        p.latitude,
        p.longitude,
      );
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
    notifyListeners();
    if (id == null) return false;
    await _store.discardDraft(id);
    return true;
  }

  /// Atomically commits workout, route points, and sync outbox item locally,
  /// then triggers background sync. Returns [RunSummary] reliably even offline.
  Future<RunSummary?> finish() async {
    if (!_started || _finishing) return null;
    _finishing = true;
    try {
      _sub?.cancel();
      _sub = null;
      _simTimer?.cancel();
      _simTimer = null;
      _clock.stop();
      await _checkpointInFlight;

      final id = _aktivitasId;
      final uid = _userId ?? await _requireUserId();
      if (id == null) return null;

      final selesai = DateTime.now().toUtc();
      final totalDurationS = elapsed.inSeconds;
      final startAt = _mulaiAt ?? selesai.subtract(elapsed);
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
      );

      PacerCache.instance.invalidatePrefix('activities_');
      PacerCache.instance.invalidatePrefix('streak_');
      PacerCache.instance.invalidatePrefix('leaderboard_');
      await _sync.refreshCounts(userId: uid);
      unawaited(_sync.triggerSync(userId: uid));

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
      );
    } finally {
      _finishing = false;
    }
  }

  /// Pace min/km from the live totals; null when stationary.
  double? get paceSecPerKm =>
      _distanceM > 0 ? elapsed.inSeconds / (_distanceM / 1000) : null;

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _simTimer?.cancel();
    if (_started) {
      unawaited(_flushCheckpoint());
    }
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
  const RunSummary({
    required this.aktivitasId,
    required this.jenis,
    required this.jarakM,
    required this.durasiS,
    required this.pointCount,
    this.points = const [],
    this.anchorLat,
    this.anchorLng,
  });
}
