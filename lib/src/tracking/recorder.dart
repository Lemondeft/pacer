import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/aktivitas/activity_repository.dart';

/// Foreground GPS run recorder (DFD 2.0 tracking). No widgets.
///
/// Lifecycle: [start] creates the aktivitas row and listens to the position
/// stream; [pause]/[resume] freeze both fixes and the clock; [finish]
/// persists duration, distance, route points, stats, and streak, then returns
/// a [RunSummary]. Fixes worse than [maxAccuracyM] are dropped (urban-canyon
/// jitter); raw points are stored, never snapped.
class RunRecorder extends ChangeNotifier {
  static const double maxAccuracyM = 20;
  static const int distanceFilterM = 5;

  final ActivityRepository _repo;
  RunRecorder({ActivityRepository? repo})
    : _repo = repo ?? ActivityRepository();

  StreamSubscription<Position>? _sub;
  final Stopwatch _clock = Stopwatch();
  final List<_Fix> _fixes = [];

  String? _aktivitasId;
  String _jenis = 'lari';
  bool _started = false;
  bool _recording = false;
  double _distanceM = 0;
  String? _error;

  bool get started => _started;
  bool get recording => _recording;
  double get distanceM => _distanceM;
  Duration get elapsed => _clock.elapsed;
  String? get error => _error;
  String? get aktivitasId => _aktivitasId;

  List<LatLng> get points => [for (final f in _fixes) LatLng(f.lat, f.lng)];

  int get pointCount => _fixes.length;

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
    return true;
  }

  /// Creates the aktivitas row and starts listening. Throws [StateError]
  /// when signed out (RLS owner insert needs auth.uid()).
  Future<void> start(String jenis) async {
    if (_started) return;
    if (!aktivitasJenis.contains(jenis)) {
      throw ArgumentError.value(jenis, 'jenis', 'must be a known jenis');
    }
    final activity = await _repo.createActivity(jenis: jenis);
    _aktivitasId = activity.id;
    _jenis = jenis;
    _fixes.clear();
    _distanceM = 0;
    _started = true;
    _resumeStream();
    notifyListeners();
  }

  void pause() {
    _sub?.cancel();
    _sub = null;
    _clock.stop();
    _recording = false;
    notifyListeners();
  }

  void resume() {
    if (!_started || _recording) return;
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
  }

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
        speed: p.speed,
        alt: p.altitude,
        at: p.timestamp,
      ),
    );
    notifyListeners();
  }

  /// Persists everything and resets. Returns null when never started.
  Future<RunSummary?> finish() async {
    if (!_started) return null;
    _sub?.cancel();
    _sub = null;
    _clock.stop();
    _recording = false;
    _started = false;
    final id = _aktivitasId;
    _aktivitasId = null;
    notifyListeners();
    if (id == null) return null;

    final now = DateTime.now();
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
    final finished = await _repo.finishActivity(id, jarakM: _distanceM);
    if (points.isNotEmpty) await _repo.addRoutePoints(id, points);
    await _repo.upsertStatistik(
      periodeKey(now),
      _distanceM,
      finished.durasiS ?? 0,
    );
    await _repo.recordStreak(now);
    final summary = RunSummary(
      aktivitasId: id,
      jenis: _jenis,
      jarakM: _distanceM,
      durasiS: finished.durasiS ?? 0,
      pointCount: points.length,
    );
    _fixes.clear();
    _distanceM = 0;
    return summary;
  }

  /// Pace min/km from the live totals; null when stationary.
  double? get paceSecPerKm =>
      _distanceM > 0 ? _clock.elapsed.inSeconds / (_distanceM / 1000) : null;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class _Fix {
  final double lat;
  final double lng;
  final double speed;
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
  const RunSummary({
    required this.aktivitasId,
    required this.jenis,
    required this.jarakM,
    required this.durasiS,
    required this.pointCount,
  });
}
