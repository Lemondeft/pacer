import 'dart:math' as math;

import 'package:pacer/src/aktivitas/activity_model.dart';

/// Supported user-selected sport modes matching [aktivitasJenis].
enum SportType { walk, jog, run, ride }

/// Normalized detection verdicts across all Pacer sports plus vehicles.
enum DetectedCategory { walk, jog, run, ride, vehicle }

/// Hardware/OS activity recognition labels normalized from Android & iOS.
enum OsMotionLabel { walking, running, onBicycle, inVehicle, unknown }

/// Maps Pacer DB/UI string (`berjalan`, `joging`, `lari`, `bersepeda`) to [SportType].
SportType sportTypeFromJenis(String jenis) {
  switch (jenis.trim().toLowerCase()) {
    case 'berjalan':
      return SportType.walk;
    case 'joging':
      return SportType.jog;
    case 'bersepeda':
      return SportType.ride;
    case 'lari':
    default:
      return SportType.run;
  }
}

/// Maps [SportType] back to canonical Pacer `aktivitas.jenis` string.
String sportTypeToJenis(SportType type) {
  switch (type) {
    case SportType.walk:
      return 'berjalan';
    case SportType.jog:
      return 'joging';
    case SportType.run:
      return 'lari';
    case SportType.ride:
      return 'bersepeda';
  }
}

/// Parses a raw channel/platform string into [OsMotionLabel].
OsMotionLabel osMotionLabelFromString(String? raw) {
  switch (raw?.trim().toUpperCase()) {
    case 'WALKING':
      return OsMotionLabel.walking;
    case 'RUNNING':
      return OsMotionLabel.running;
    case 'ON_BICYCLE':
    case 'CYCLING':
      return OsMotionLabel.onBicycle;
    case 'IN_VEHICLE':
    case 'AUTOMOTIVE':
      return OsMotionLabel.inVehicle;
    case 'UNKNOWN':
    default:
      return OsMotionLabel.unknown;
  }
}

/// Calibration constants for all five pipeline layers across Pacer sports.
class DetectionThresholds {
  DetectionThresholds._();

  // Layer 1 — GPS Sanitization
  static const double maxGpsAccuracyMeters = 20.0;
  static const double maxHumanAccelMps2 = 4.0;
  static const double maxInitialAccelMps2 = 6.5;
  static const double maxInitialBurstSpeedMs = 18.0;
  static const double maxGapSpeedDeltaMs = 10.0;
  static const int outlierRecoveryStreak = 3;
  static const double outlierRecoveryMaxSpeedKmh = 45.0;
  static const double gpsRawTeleportCeilingKmh = 110.0;
  static const int windowDurationSeconds = 30;

  // Layer 2 / 4 — OS Fusion & Stride Bounds
  static const int minOsConfidence = 75;
  static const int minWalkingOsConfidence = 80;
  static const int minVehicleOsConfidence = 80;
  static const double walkStrideMinMeters = 0.50;
  static const double walkStrideMaxMeters = 1.15;
  static const double walkFromRunStrideMaxMeters = 1.05;
  static const double runStrideMinMeters = 1.15;
  static const double runStrideMaxMeters = 1.95;
  static const double protectedFootStrideMinMeters = 0.50;
  static const double protectedFootStrideMaxMeters = 2.15;
  static const double impossibleStrideMeters = 2.20;

  // Layer 3 — Targeted 25 Hz Accelerometer Bursts
  static const double ambiguitySpeedMinKmh = 7.5;
  static const double ambiguitySpeedMaxKmh = 15.0;
  static const double runBikeAmbiguityMinKmh = 10.5;
  static const double runBikeAmbiguityMaxKmh = 24.0;
  static const double rideAmbiguityLowMaxKmh = 16.0;
  static const double rideAmbiguityHighMinKmh = 35.0;
  static const int accelSampleRateHz = 25;
  static const int accelBurstDurationSec = 5;
  static const double accelHeelStrikePeakMps2 = 3.5;
  static const int accelMinPeakSpacingMs = 250;
  static const int accelMinWalkPeaks5s = 5;
  static const int runMinHeelStrikePeaks5s = 7;
  static const double accelMaxBikeStdMps2 = 1.7;
  static const double accelMaxBikeJerkMps3 = 20.0;
  static const double accelMinRunStdMps2 = 2.5;
  static const double accelMinFootStdMps2 = 2.1;
  static const double accelMaxVehicleStdMps2 = 0.9;
  static const double accelMaxVehicleJerkMps3 = 12.0;
  static const int accelMaxVehiclePeaks5s = 1;

  // Layer 4 — Multi-Sport & Vehicle Speeds + Hysteresis
  static const int requiredConsecutiveWindows = 2; // 60 s
  static const int walkInRunConsecutiveWindows = 4; // 120 s
  static const double walkToRunMinSpeedKmh = 7.5;
  static const double walkToFullRunMinSpeedKmh = 10.5;
  static const double runBikeSpeedThresholdFlatKmh = 24.0;
  static const double runBikeSpeedThresholdDownhillKmh = 28.0;
  static const double walkFromRunMaxSpeedKmh = 5.8;
  static const double footInBikeMaxSpeedKmh = 18.0;
  static const double vehicleMinOsSpeedKmh = 22.0;
  static const double vehicleFlatSpeedKmh = 45.0;
  static const double vehicleDownhillSpeedKmh = 60.0;
  static const double downhillCyclistProtectedMaxKmh = 58.0;

  // Layer 5 — Server Post-Upload Audit
  static const int serverSustainedWindowSec = 120;
  static const double serverMaxFlatWalkKmh = 11.5;
  static const double serverMaxDownhillWalkKmh = 15.5;
  static const int cadenceSpmMin = 145;
  static const int cadenceSpmMax = 210;
}

/// Raw 3-axis linear + gravity accelerometer reading (m/s^2).
class AccelSample {
  final double x;
  final double y;
  final double z;
  final int timestampMs;

  const AccelSample({
    required this.x,
    required this.y,
    required this.z,
    required this.timestampMs,
  });
}

/// Extracted time-domain dynamics from a targeted 5-second 25 Hz burst.
class AccelBurstFeatures {
  final double dynamicStdDevMps2;
  final int heelStrikePeaks;
  final double meanJerkMps3;
  final bool isCyclingSignature;
  final bool isVehicleSignature;
  final int? estimatedCadenceSpm;

  const AccelBurstFeatures({
    required this.dynamicStdDevMps2,
    required this.heelStrikePeaks,
    required this.meanJerkMps3,
    required this.isCyclingSignature,
    this.isVehicleSignature = false,
    this.estimatedCadenceSpm,
  });
}

/// Aggregated 30-second sensor + GPS evaluation input window.
class TelemetryWindow {
  final double medianSpeedKmh;
  final double p85SpeedKmh;
  final double distanceMeters;
  final double gradePercent;
  final int? steps;
  final OsMotionLabel osActivity;
  final int osConfidence;
  final AccelBurstFeatures? accelBurst;

  const TelemetryWindow({
    required this.medianSpeedKmh,
    required this.p85SpeedKmh,
    required this.distanceMeters,
    required this.gradePercent,
    required this.steps,
    required this.osActivity,
    required this.osConfidence,
    this.accelBurst,
  });
}

/// Result of scoring one 30-second window against the active sport.
class ActivityEvaluation {
  final bool isMismatch;
  final DetectedCategory detectedCategory;
  final String? suggestedJenis;
  final bool isVehicleDetected;
  final int confidenceScore;
  final List<String> reasons;

  const ActivityEvaluation({
    required this.isMismatch,
    required this.detectedCategory,
    required this.suggestedJenis,
    required this.isVehicleDetected,
    required this.confidenceScore,
    required this.reasons,
  });

  /// True specifically when the classified mismatch target is cycling (`bersepeda`).
  bool get isBikeDetected =>
      isMismatch && detectedCategory == DetectedCategory.ride;
}

/// Active latched prompt surfaced to the user after hysteresis confirmation.
class ActivityMismatch {
  final SportType selectedSport;
  final DetectedCategory detectedCategory;
  final String? suggestedJenis;
  final bool isVehicleDetected;
  final int confidenceScore;
  final List<String> reasons;

  const ActivityMismatch({
    required this.selectedSport,
    required this.detectedCategory,
    required this.suggestedJenis,
    required this.isVehicleDetected,
    required this.confidenceScore,
    required this.reasons,
  });
}

/// Canonical GPS coordinate passed into [GpsSanitizer].
class GpsFix {
  final double lat;
  final double lng;
  final double altitudeM;
  final double? speedMs;
  final double accuracyM;
  final DateTime timestamp;

  const GpsFix({
    required this.lat,
    required this.lng,
    required this.altitudeM,
    required this.speedMs,
    required this.accuracyM,
    required this.timestamp,
  });
}

enum GpsIngestStatus {
  accepted,
  droppedAccuracy,
  droppedInvalidCoords,
  droppedStaleTimestamp,
  droppedTeleport,
  droppedImplausibleAccel,
}

class GpsSanitizeResult {
  final GpsIngestStatus status;
  final double segmentDistanceMeters;
  final double segmentSpeedKmh;

  const GpsSanitizeResult({
    required this.status,
    this.segmentDistanceMeters = 0,
    this.segmentSpeedKmh = 0,
  });

  bool get accepted => status == GpsIngestStatus.accepted;
}

class _AcceptedSample {
  final DateTime timestamp;
  final double distMeters;
  final double speedKmh;
  final double altitudeM;

  const _AcceptedSample({
    required this.timestamp,
    required this.distMeters,
    required this.speedKmh,
    required this.altitudeM,
  });
}

/// Computes spherical Haversine distance in meters between two WGS-84 points.
double haversineMeters(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const earthRadiusM = 6371000.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLng = _degToRad(lng2 - lng1);
  final rLat1 = _degToRad(lat1);
  final rLat2 = _degToRad(lat2);
  final sinHalfLat = math.sin(dLat / 2);
  final sinHalfLng = math.sin(dLng / 2);
  final a =
      sinHalfLat * sinHalfLat +
      math.cos(rLat1) * math.cos(rLat2) * sinHalfLng * sinHalfLng;
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(math.max(0.0, 1.0 - a)));
  return earthRadiusM * c;
}

double _degToRad(double deg) => deg * math.pi / 180.0;

/// Layer 1 GPS kinematic filter & rolling 30-second telemetry aggregator.
class GpsSanitizer {
  GpsFix? _lastAccepted;
  double? _lastSegmentSpeedMs;
  final List<_AcceptedSample> _window = <_AcceptedSample>[];
  final List<GpsFix> _candidateOutliers = <GpsFix>[];

  GpsFix? get lastAccepted => _lastAccepted;

  static bool isNullIsland(double lat, double lng) =>
      lat.abs() < 1e-5 && lng.abs() < 1e-5;

  void reset() {
    _lastAccepted = null;
    _lastSegmentSpeedMs = null;
    _window.clear();
    _candidateOutliers.clear();
  }

  /// Clears spatial anchor on manual pause/resume so relocation during pause
  /// starts a fresh segment instead of bridging a straight chord or locking out fixes.
  void markPauseBreak() {
    _lastAccepted = null;
    _lastSegmentSpeedMs = null;
    _candidateOutliers.clear();
  }

  GpsSanitizeResult ingest(GpsFix fix) {
    if (!fix.accuracyM.isFinite ||
        fix.accuracyM < 0 ||
        fix.accuracyM > DetectionThresholds.maxGpsAccuracyMeters) {
      return const GpsSanitizeResult(status: GpsIngestStatus.droppedAccuracy);
    }
    if (!fix.lat.isFinite ||
        !fix.lng.isFinite ||
        isNullIsland(fix.lat, fix.lng) ||
        !isValidLatLng(fix.lat, fix.lng)) {
      return const GpsSanitizeResult(
        status: GpsIngestStatus.droppedInvalidCoords,
      );
    }

    final prev = _lastAccepted;
    if (prev == null) {
      _candidateOutliers.clear();
      final initialSpeedMs =
          (fix.speedMs != null && fix.speedMs!.isFinite && fix.speedMs! >= 0)
          ? fix.speedMs!
          : 0.0;
      _lastAccepted = fix;
      _window.add(
        _AcceptedSample(
          timestamp: fix.timestamp,
          distMeters: 0,
          speedKmh: initialSpeedMs * 3.6,
          altitudeM: fix.altitudeM.isFinite ? fix.altitudeM : 0.0,
        ),
      );
      return GpsSanitizeResult(
        status: GpsIngestStatus.accepted,
        segmentDistanceMeters: 0,
        segmentSpeedKmh: initialSpeedMs * 3.6,
      );
    }

    final dtSec =
        fix.timestamp.difference(prev.timestamp).inMicroseconds / 1e6;
    if (!dtSec.isFinite || dtSec <= 0) {
      return const GpsSanitizeResult(
        status: GpsIngestStatus.droppedStaleTimestamp,
      );
    }

    final distM = haversineMeters(prev.lat, prev.lng, fix.lat, fix.lng);
    final speedMs = distM / dtSec;
    final speedKmh = speedMs * 3.6;
    if (speedKmh > DetectionThresholds.gpsRawTeleportCeilingKmh) {
      return _recordRejectedAndMaybeRecover(
        fix,
        GpsIngestStatus.droppedTeleport,
      );
    }

    final prevSpeedMs = _lastSegmentSpeedMs;
    if (prevSpeedMs == null) {
      if (dtSec <= 10.0) {
        final baselineSpeedMs =
            (prev.speedMs != null &&
                prev.speedMs!.isFinite &&
                prev.speedMs! >= 0)
            ? prev.speedMs!
            : 0.0;
        final initialAccelMps2 = (speedMs - baselineSpeedMs).abs() / dtSec;
        if (initialAccelMps2 > DetectionThresholds.maxInitialAccelMps2 ||
            (speedMs > DetectionThresholds.maxInitialBurstSpeedMs &&
                dtSec <= 2.0)) {
          return _recordRejectedAndMaybeRecover(
            fix,
            GpsIngestStatus.droppedImplausibleAccel,
          );
        }
      } else if (speedKmh > DetectionThresholds.outlierRecoveryMaxSpeedKmh) {
        return _recordRejectedAndMaybeRecover(
          fix,
          GpsIngestStatus.droppedImplausibleAccel,
        );
      }
    } else if (dtSec <= 10.0) {
      final accelMps2 = (speedMs - prevSpeedMs).abs() / dtSec;
      if (accelMps2 > DetectionThresholds.maxHumanAccelMps2) {
        return _recordRejectedAndMaybeRecover(
          fix,
          GpsIngestStatus.droppedImplausibleAccel,
        );
      }
    } else if ((speedMs - prevSpeedMs).abs() >
        DetectionThresholds.maxGapSpeedDeltaMs) {
      return _recordRejectedAndMaybeRecover(
        fix,
        GpsIngestStatus.droppedImplausibleAccel,
      );
    }

    _candidateOutliers.clear();
    _lastAccepted = fix;
    _lastSegmentSpeedMs = speedMs;
    _window.add(
      _AcceptedSample(
        timestamp: fix.timestamp,
        distMeters: distM,
        speedKmh: speedKmh,
        altitudeM: fix.altitudeM.isFinite
            ? fix.altitudeM
            : _window.last.altitudeM,
      ),
    );
    _pruneWindow(fix.timestamp);
    return GpsSanitizeResult(
      status: GpsIngestStatus.accepted,
      segmentDistanceMeters: distM,
      segmentSpeedKmh: speedKmh,
    );
  }

  /// Recovers from genuine relocations after [outlierRecoveryStreak] mutually
  /// consistent rejected fixes without adding an implausible jump chord.
  GpsSanitizeResult _recordRejectedAndMaybeRecover(
    GpsFix fix,
    GpsIngestStatus rejectedStatus,
  ) {
    if (_candidateOutliers.isEmpty) {
      _candidateOutliers.add(fix);
      return GpsSanitizeResult(status: rejectedStatus);
    }
    final prevCand = _candidateOutliers.last;
    final dtSec =
        fix.timestamp.difference(prevCand.timestamp).inMicroseconds / 1e6;
    if (!dtSec.isFinite || dtSec <= 0) {
      return GpsSanitizeResult(status: rejectedStatus);
    }
    final distM = haversineMeters(prevCand.lat, prevCand.lng, fix.lat, fix.lng);
    final candSpeedMs = distM / dtSec;
    final candSpeedKmh = candSpeedMs * 3.6;
    if (candSpeedKmh > DetectionThresholds.outlierRecoveryMaxSpeedKmh) {
      _candidateOutliers
        ..clear()
        ..add(fix);
      return GpsSanitizeResult(status: rejectedStatus);
    }
    if (_candidateOutliers.length >= 2) {
      final anchorCand = _candidateOutliers[_candidateOutliers.length - 2];
      final prevDt =
          prevCand.timestamp.difference(anchorCand.timestamp).inMicroseconds /
          1e6;
      if (prevDt > 0) {
        final prevSpeed =
            haversineMeters(
              anchorCand.lat,
              anchorCand.lng,
              prevCand.lat,
              prevCand.lng,
            ) /
            prevDt;
        if (dtSec <= 10.0 &&
            (candSpeedMs - prevSpeed).abs() / dtSec >
                DetectionThresholds.maxHumanAccelMps2) {
          _candidateOutliers
            ..clear()
            ..add(fix);
          return GpsSanitizeResult(status: rejectedStatus);
        }
      }
    }

    _candidateOutliers.add(fix);
    if (_candidateOutliers.length < DetectionThresholds.outlierRecoveryStreak) {
      return GpsSanitizeResult(status: rejectedStatus);
    }

    _candidateOutliers.clear();
    _lastAccepted = fix;
    _lastSegmentSpeedMs = candSpeedMs;
    _window.add(
      _AcceptedSample(
        timestamp: fix.timestamp,
        distMeters: 0,
        speedKmh: candSpeedKmh,
        altitudeM: fix.altitudeM.isFinite
            ? fix.altitudeM
            : (_window.isNotEmpty ? _window.last.altitudeM : 0.0),
      ),
    );
    _pruneWindow(fix.timestamp);
    return GpsSanitizeResult(
      status: GpsIngestStatus.accepted,
      segmentDistanceMeters: 0,
      segmentSpeedKmh: candSpeedKmh,
    );
  }

  void _pruneWindow(DateTime now) {
    final cutoff = now.subtract(
      const Duration(seconds: DetectionThresholds.windowDurationSeconds),
    );
    while (_window.length > 1 && _window.first.timestamp.isBefore(cutoff)) {
      _window.removeAt(0);
    }
  }

  /// Aggregates median speed, p85 speed, distance, and grade over the trailing 30 s.
  TelemetryWindow buildWindow({
    required int? steps,
    required OsMotionLabel osActivity,
    required int osConfidence,
    AccelBurstFeatures? accelBurst,
    DateTime? now,
  }) {
    if (_window.isEmpty) {
      return TelemetryWindow(
        medianSpeedKmh: 0,
        p85SpeedKmh: 0,
        distanceMeters: 0,
        gradePercent: 0,
        steps: steps,
        osActivity: osActivity,
        osConfidence: osConfidence,
        accelBurst: accelBurst,
      );
    }
    final refNow = now ?? _window.last.timestamp;
    _pruneWindow(refNow);

    // Exclude the synthetic anchor (distMeters == 0) once real movement segments exist.
    final segSpeeds = <double>[];
    var totalDist = 0.0;
    for (var i = 0; i < _window.length; i++) {
      final s = _window[i];
      totalDist += s.distMeters;
      if (i > 0 || s.distMeters > 0) {
        segSpeeds.add(s.speedKmh);
      }
    }
    if (segSpeeds.isEmpty) {
      segSpeeds.add(_window.last.speedKmh);
    }
    segSpeeds.sort();

    final median = _quantile(segSpeeds, 0.50);
    final p85 = _quantile(segSpeeds, 0.85);
    var grade = 0.0;
    if (totalDist >= 10.0 && _window.length >= 2) {
      final dz = _window.last.altitudeM - _window.first.altitudeM;
      grade = (dz / totalDist * 100.0).clamp(-35.0, 35.0);
    }

    return TelemetryWindow(
      medianSpeedKmh: median,
      p85SpeedKmh: p85,
      distanceMeters: totalDist,
      gradePercent: grade,
      steps: steps,
      osActivity: osActivity,
      osConfidence: osConfidence,
      accelBurst: accelBurst,
    );
  }

  double _quantile(List<double> sorted, double q) {
    if (sorted.isEmpty) return 0;
    if (sorted.length == 1) return sorted.first;
    final pos = q * (sorted.length - 1);
    final lo = pos.floor();
    final hi = pos.ceil();
    if (lo == hi) return sorted[lo];
    final frac = pos - lo;
    return sorted[lo] * (1.0 - frac) + sorted[hi] * frac;
  }
}

/// Sport-aware battery gating deciding when to sample a 5 s 25 Hz accel burst.
bool shouldTriggerAccelBurst(
  TelemetryWindow w, {
  SportType selectedSport = SportType.walk,
}) {
  final lowOsConfidence =
      w.osActivity == OsMotionLabel.unknown ||
      w.osConfidence < DetectionThresholds.minOsConfidence;

  switch (selectedSport) {
    case SportType.walk:
      final inAmbiguity =
          w.medianSpeedKmh >= DetectionThresholds.ambiguitySpeedMinKmh &&
          w.medianSpeedKmh <= DetectionThresholds.ambiguitySpeedMaxKmh;
      final missingPedometer =
          w.steps == null &&
          w.medianSpeedKmh >= DetectionThresholds.ambiguitySpeedMinKmh;
      if (w.medianSpeedKmh < 2.0 &&
          w.osActivity == OsMotionLabel.walking &&
          w.osConfidence >= DetectionThresholds.minOsConfidence) {
        return false;
      }
      return inAmbiguity || lowOsConfidence || missingPedometer;

    case SportType.jog:
    case SportType.run:
      final inBikeBand =
          w.medianSpeedKmh >= DetectionThresholds.runBikeAmbiguityMinKmh &&
          w.medianSpeedKmh <= DetectionThresholds.runBikeAmbiguityMaxKmh;
      final slowWalkCheck =
          w.medianSpeedKmh >= 2.0 &&
          w.medianSpeedKmh < DetectionThresholds.walkFromRunMaxSpeedKmh &&
          w.osActivity != OsMotionLabel.running;
      final missingPedometer =
          w.steps == null &&
          w.medianSpeedKmh >= DetectionThresholds.runBikeAmbiguityMinKmh;
      return inBikeBand ||
          slowWalkCheck ||
          (lowOsConfidence && w.medianSpeedKmh >= 4.0) ||
          missingPedometer;

    case SportType.ride:
      final inLowFootBand =
          w.medianSpeedKmh >= 2.0 &&
          w.medianSpeedKmh <= DetectionThresholds.rideAmbiguityLowMaxKmh;
      final inVehicleBand =
          w.medianSpeedKmh >= DetectionThresholds.rideAmbiguityHighMinKmh;
      final steadyRide =
          !lowOsConfidence &&
          w.osActivity == OsMotionLabel.onBicycle &&
          w.steps != null &&
          !inLowFootBand &&
          !inVehicleBand;
      if (steadyRide) return false;
      return inLowFootBand ||
          inVehicleBand ||
          (lowOsConfidence && w.medianSpeedKmh >= 2.0) ||
          (w.steps == null && w.medianSpeedKmh >= 2.0);
  }
}

/// Extracts gravity-compensated dynamic features from a 25 Hz burst.
AccelBurstFeatures extractAccelBurstFeatures(
  List<AccelSample> samples, {
  int sampleRateHz = DetectionThresholds.accelSampleRateHz,
}) {
  if (samples.length < 10) {
    return const AccelBurstFeatures(
      dynamicStdDevMps2: 0,
      heelStrikePeaks: 0,
      meanJerkMps3: 0,
      isCyclingSignature: false,
      isVehicleSignature: false,
      estimatedCadenceSpm: null,
    );
  }

  final magnitudes = <double>[
    for (final s in samples) math.sqrt(s.x * s.x + s.y * s.y + s.z * s.z),
  ];
  var magSum = 0.0;
  for (final m in magnitudes) {
    magSum += m;
  }
  final meanMag = magSum / magnitudes.length;

  final dynamic = <double>[for (final m in magnitudes) m - meanMag];
  var varSum = 0.0;
  for (final d in dynamic) {
    varSum += d * d;
  }
  final dynamicStdDevMps2 = math.sqrt(varSum / dynamic.length);

  var jerkSum = 0.0;
  var jerkCount = 0;
  for (var i = 1; i < dynamic.length; i++) {
    final dtSec = math.max(
      (samples[i].timestampMs - samples[i - 1].timestampMs) / 1000.0,
      1.0 / sampleRateHz,
    );
    jerkSum += (dynamic[i] - dynamic[i - 1]).abs() / dtSec;
    jerkCount++;
  }
  final meanJerkMps3 = jerkCount > 0 ? jerkSum / jerkCount : 0.0;

  final minPeakGapSamples = (0.25 * sampleRateHz).ceil();
  var heelStrikePeaks = 0;
  var lastPeakIndex = -minPeakGapSamples;
  final peakTimesMs = <int>[];

  for (var i = 1; i < dynamic.length - 1; i++) {
    final isLocalMax =
        dynamic[i] > dynamic[i - 1] && dynamic[i] >= dynamic[i + 1];
    if (isLocalMax &&
        dynamic[i] > DetectionThresholds.accelHeelStrikePeakMps2 &&
        i - lastPeakIndex >= minPeakGapSamples) {
      heelStrikePeaks++;
      lastPeakIndex = i;
      peakTimesMs.add(samples[i].timestampMs);
    }
  }

  int? estimatedCadenceSpm;
  if (peakTimesMs.length >= 2) {
    final spanMs = peakTimesMs.last - peakTimesMs.first;
    if (spanMs > 0) {
      final intervals = peakTimesMs.length - 1;
      estimatedCadenceSpm = ((intervals * 60000.0) / spanMs).round().clamp(
        40,
        240,
      );
    }
  }

  final isCyclingSignature =
      heelStrikePeaks < DetectionThresholds.accelMinWalkPeaks5s &&
      dynamicStdDevMps2 <= DetectionThresholds.accelMaxBikeStdMps2 &&
      meanJerkMps3 <= DetectionThresholds.accelMaxBikeJerkMps3;

  final isVehicleSignature =
      heelStrikePeaks <= DetectionThresholds.accelMaxVehiclePeaks5s &&
      dynamicStdDevMps2 <= DetectionThresholds.accelMaxVehicleStdMps2 &&
      meanJerkMps3 <= DetectionThresholds.accelMaxVehicleJerkMps3;

  return AccelBurstFeatures(
    dynamicStdDevMps2: dynamicStdDevMps2,
    heelStrikePeaks: heelStrikePeaks,
    meanJerkMps3: meanJerkMps3,
    isCyclingSignature: isCyclingSignature,
    isVehicleSignature: isVehicleSignature,
    estimatedCadenceSpm: estimatedCadenceSpm,
  );
}

/// Evaluates one 30-second telemetry window across all four sports + vehicles.
ActivityEvaluation evaluateActivityWindow(
  SportType selectedSport,
  TelemetryWindow w,
) {
  final currentCat = switch (selectedSport) {
    SportType.walk => DetectedCategory.walk,
    SportType.jog => DetectedCategory.jog,
    SportType.run => DetectedCategory.run,
    SportType.ride => DetectedCategory.ride,
  };

  // 1. Universal Motor Vehicle Cheat Check (protected for downhill cyclists)
  final vehicleEval = _evaluateVehicle(selectedSport, w);
  if (vehicleEval != null) return vehicleEval;

  // 2. Sport-specific bidirectional checks
  switch (selectedSport) {
    case SportType.walk:
      final bikeEval = _evaluateWalkToBike(w);
      if (bikeEval.isBikeDetected) return bikeEval;
      final runEval = _evaluateWalkToRunOrJog(w, priorReasons: bikeEval.reasons);
      if (runEval != null) return runEval;
      return bikeEval;

    case SportType.jog:
    case SportType.run:
      final bikeEval = _evaluateRunToBike(w, selectedCat: currentCat);
      if (bikeEval.isMismatch) return bikeEval;
      final walkEval = _evaluateRunToWalk(
        w,
        selectedCat: currentCat,
        priorReasons: bikeEval.reasons,
      );
      if (walkEval != null) return walkEval;
      return bikeEval;

    case SportType.ride:
      return _evaluateRideToFoot(w);
  }
}

/// Backwards-compatible wrapper exposing the Walk->Bike view over [evaluateActivityWindow].
ActivityEvaluation evaluateWalkToBikeWindow(
  SportType selectedSport,
  TelemetryWindow w,
) => evaluateActivityWindow(selectedSport, w);

ActivityEvaluation? _evaluateVehicle(
  SportType selectedSport,
  TelemetryWindow w,
) {
  // Guardrail: steep downhill cycling up to 58 km/h with ON_BICYCLE stays valid.
  if (selectedSport == SportType.ride &&
      w.gradePercent < -2.0 &&
      w.medianSpeedKmh <= DetectionThresholds.downhillCyclistProtectedMaxKmh &&
      w.osActivity == OsMotionLabel.onBicycle &&
      w.osConfidence >= DetectionThresholds.minOsConfidence) {
    return null;
  }

  // Foot-motion protection: valid running or heel strikes prevent false vehicle flags.
  final hasRunningOs =
      w.osActivity == OsMotionLabel.running &&
      w.osConfidence >= DetectionThresholds.minOsConfidence;
  final hasFootImpacts =
      w.accelBurst != null &&
      w.accelBurst!.heelStrikePeaks >= DetectionThresholds.accelMinWalkPeaks5s + 1;
  final stride = (w.steps != null && w.steps! > 0)
      ? w.distanceMeters / w.steps!
      : double.infinity;
  final hasFootStride =
      w.steps != null &&
      w.steps! >= 25 &&
      stride >= DetectionThresholds.protectedFootStrideMinMeters &&
      stride <= DetectionThresholds.protectedFootStrideMaxMeters &&
      w.medianSpeedKmh <= 25.0;
  if (hasRunningOs || hasFootImpacts || hasFootStride) {
    return null;
  }

  var score = 0;
  final reasons = <String>[];

  if (w.osActivity == OsMotionLabel.inVehicle &&
      w.osConfidence >= DetectionThresholds.minVehicleOsConfidence &&
      w.medianSpeedKmh >= DetectionThresholds.vehicleMinOsSpeedKmh) {
    score += 50;
    reasons.add('OS_VEHICLE_CONFIRMED');
  }
  if (w.accelBurst != null &&
      w.accelBurst!.isVehicleSignature &&
      w.medianSpeedKmh >= DetectionThresholds.vehicleMinOsSpeedKmh) {
    score += 35;
    reasons.add('ACCEL_CABIN_SMOOTH');
  }
  if (w.steps != null &&
      w.distanceMeters > 20 &&
      w.medianSpeedKmh >= DetectionThresholds.vehicleMinOsSpeedKmh &&
      w.steps! < 4) {
    score += 35;
    reasons.add('ZERO_STEP_VEHICLE_PACE');
  }

  final hardVehicleLimit = w.gradePercent < -2.0
      ? DetectionThresholds.vehicleDownhillSpeedKmh
      : DetectionThresholds.vehicleFlatSpeedKmh;
  if (w.medianSpeedKmh > hardVehicleLimit) {
    score += 70;
    reasons.add('SUSTAINED_VEHICLE_SPEED');
  }

  final clamped = score.clamp(0, 100);
  if (clamped >= 70) {
    reasons.add('VEHICLE_DETECTED');
    return ActivityEvaluation(
      isMismatch: true,
      detectedCategory: DetectedCategory.vehicle,
      suggestedJenis: null,
      isVehicleDetected: true,
      confidenceScore: clamped,
      reasons: reasons,
    );
  }
  return null;
}

ActivityEvaluation _evaluateWalkToBike(TelemetryWindow w) {
  if (w.osActivity == OsMotionLabel.running &&
      w.osConfidence >= DetectionThresholds.minOsConfidence) {
    return const ActivityEvaluation(
      isMismatch: false,
      detectedCategory: DetectedCategory.walk,
      suggestedJenis: null,
      isVehicleDetected: false,
      confidenceScore: 0,
      reasons: ['VERIFIED_RUNNING'],
    );
  }

  var score = 0;
  final reasons = <String>[];
  final flatSpeedThreshold = w.gradePercent < -2.0 ? 11.5 : 8.5;

  if ((w.osActivity == OsMotionLabel.onBicycle ||
          w.osActivity == OsMotionLabel.inVehicle) &&
      w.osConfidence >= DetectionThresholds.minOsConfidence) {
    if (w.medianSpeedKmh > flatSpeedThreshold) {
      score += 45;
      reasons.add('OS_BIKE_CONFIRMED');
    }
  } else if (w.osActivity == OsMotionLabel.walking &&
      w.osConfidence >= DetectionThresholds.minWalkingOsConfidence) {
    score -= 35;
  }

  if (w.steps != null && w.distanceMeters > 20) {
    final strideMeters = w.steps! > 0
        ? w.distanceMeters / w.steps!
        : double.infinity;
    if (w.medianSpeedKmh > 9.5 && w.steps! < 5) {
      score += 45;
      reasons.add('ZERO_STEP_VELOCITY');
    } else if (w.medianSpeedKmh > 10.5 &&
        strideMeters > DetectionThresholds.impossibleStrideMeters) {
      score += 45;
      reasons.add('STRIDE_IMPOSSIBLE_${strideMeters.toStringAsFixed(2)}M');
    } else if (strideMeters >= DetectionThresholds.walkStrideMinMeters &&
        strideMeters <= 1.85 &&
        w.steps! >= 20) {
      score -= 40;
    }
  }

  final burst = w.accelBurst;
  if (burst != null) {
    if (burst.isCyclingSignature && w.medianSpeedKmh > 8.0) {
      score += 45;
      reasons.add('ACCEL_NO_HEEL_STRIKE');
    } else if (burst.heelStrikePeaks >= 6 && burst.dynamicStdDevMps2 >= 2.2) {
      score -= 40;
    }
  }

  final hardWalkLimitKmh = w.gradePercent < -2.0 ? 17.5 : 14.0;
  if (w.medianSpeedKmh > hardWalkLimitKmh && score >= 0) {
    score += 40;
    reasons.add('SUSTAINED_NON_WALK_PACE');
  }

  final clampedScore = score.clamp(0, 100);
  final detected = clampedScore >= 70;
  return ActivityEvaluation(
    isMismatch: detected,
    detectedCategory:
        detected ? DetectedCategory.ride : DetectedCategory.walk,
    suggestedJenis: detected ? 'bersepeda' : null,
    isVehicleDetected: false,
    confidenceScore: clampedScore,
    reasons: reasons,
  );
}

ActivityEvaluation? _evaluateWalkToRunOrJog(
  TelemetryWindow w, {
  required List<String> priorReasons,
}) {
  if (w.osActivity != OsMotionLabel.running ||
      w.osConfidence < DetectionThresholds.minOsConfidence ||
      w.medianSpeedKmh < DetectionThresholds.walkToRunMinSpeedKmh) {
    return null;
  }

  final hasSteps = w.steps != null;
  final stride = (hasSteps && w.steps! > 0)
      ? w.distanceMeters / w.steps!
      : 0.0;
  final validRunStride =
      hasSteps &&
      w.steps! >= 50 &&
      stride >= 0.80 &&
      stride <= DetectionThresholds.runStrideMaxMeters;
  final burst = w.accelBurst;
  final validRunBurst =
      burst != null &&
      burst.heelStrikePeaks >= DetectionThresholds.runMinHeelStrikePeaks5s &&
      burst.dynamicStdDevMps2 >= DetectionThresholds.accelMinRunStdMps2;

  if (hasSteps && !validRunStride) return null;
  if (!hasSteps && !validRunBurst) return null;
  if (burst != null && burst.isCyclingSignature) return null;

  final isFullRun =
      w.medianSpeedKmh >= DetectionThresholds.walkToFullRunMinSpeedKmh;
  final reasons = <String>{...priorReasons, 'RUN_DETECTED_IN_WALK'}.toList();
  return ActivityEvaluation(
    isMismatch: true,
    detectedCategory: isFullRun ? DetectedCategory.run : DetectedCategory.jog,
    suggestedJenis: isFullRun ? 'lari' : 'joging',
    isVehicleDetected: false,
    confidenceScore: math.max(80, w.osConfidence),
    reasons: reasons,
  );
}

ActivityEvaluation _evaluateRunToBike(
  TelemetryWindow w, {
  required DetectedCategory selectedCat,
}) {
  final reasons = <String>[];

  final hasRunningOs =
      w.osActivity == OsMotionLabel.running &&
      w.osConfidence >= DetectionThresholds.minOsConfidence;
  final strideMeters = (w.steps != null && w.steps! > 0)
      ? w.distanceMeters / w.steps!
      : double.infinity;
  final hasValidFootStride =
      w.steps != null &&
      w.steps! >= 20 &&
      strideMeters >= 1.0 &&
      strideMeters <= DetectionThresholds.protectedFootStrideMaxMeters;
  final hasStrongImpacts =
      w.accelBurst != null &&
      w.accelBurst!.heelStrikePeaks >= 6 &&
      w.accelBurst!.dynamicStdDevMps2 >= 2.2;

  if (hasRunningOs || hasStrongImpacts) {
    return ActivityEvaluation(
      isMismatch: false,
      detectedCategory: selectedCat,
      suggestedJenis: null,
      isVehicleDetected: false,
      confidenceScore: 0,
      reasons: const ['VERIFIED_RUNNING'],
    );
  }

  var score = 0;
  if ((w.osActivity == OsMotionLabel.onBicycle ||
          w.osActivity == OsMotionLabel.inVehicle) &&
      w.osConfidence >= DetectionThresholds.minOsConfidence &&
      w.medianSpeedKmh > 10.5) {
    score += 45;
    reasons.add('OS_BIKE_CONFIRMED');
  }

  if (w.steps != null && w.distanceMeters > 20) {
    if (w.medianSpeedKmh > 13.0 && w.steps! < 8) {
      score += 45;
      reasons.add('ZERO_STEP_VELOCITY');
    } else if (w.medianSpeedKmh > 13.0 &&
        strideMeters > DetectionThresholds.impossibleStrideMeters) {
      score += 45;
      reasons.add('STRIDE_IMPOSSIBLE_${strideMeters.toStringAsFixed(2)}M');
    } else if (hasValidFootStride) {
      score -= 45;
    }
  }

  if (w.accelBurst != null) {
    if (w.accelBurst!.isCyclingSignature && w.medianSpeedKmh > 11.0) {
      final noFootCadence = w.steps == null || w.steps! < 8;
      final burstCadence = w.accelBurst!.estimatedCadenceSpm;
      final lowBurstCadence = burstCadence == null || burstCadence < 130;
      if (w.medianSpeedKmh >= 13.5 && noFootCadence && lowBurstCadence) {
        score += 70;
        reasons.add('ACCEL_BIKE_NO_STEPS');
      } else {
        score += 45;
        reasons.add('ACCEL_NO_HEEL_STRIKE');
      }
    }
  }

  final hardRunLimit = w.gradePercent < -2.0
      ? DetectionThresholds.runBikeSpeedThresholdDownhillKmh
      : DetectionThresholds.runBikeSpeedThresholdFlatKmh;
  if (w.medianSpeedKmh > hardRunLimit && score >= 0) {
    score += hasValidFootStride ? 20 : 70;
    reasons.add('RUN_TO_BIKE');
  }

  final clamped = score.clamp(0, 100);
  if (clamped >= 70 && !hasValidFootStride) {
    if (!reasons.contains('RUN_TO_BIKE')) reasons.add('RUN_TO_BIKE');
    return ActivityEvaluation(
      isMismatch: true,
      detectedCategory: DetectedCategory.ride,
      suggestedJenis: 'bersepeda',
      isVehicleDetected: false,
      confidenceScore: clamped,
      reasons: reasons,
    );
  }

  return ActivityEvaluation(
    isMismatch: false,
    detectedCategory: selectedCat,
    suggestedJenis: null,
    isVehicleDetected: false,
    confidenceScore: clamped,
    reasons: reasons,
  );
}

ActivityEvaluation? _evaluateRunToWalk(
  TelemetryWindow w, {
  required DetectedCategory selectedCat,
  required List<String> priorReasons,
}) {
  if (w.medianSpeedKmh <= 0.5 ||
      w.medianSpeedKmh >= DetectionThresholds.walkFromRunMaxSpeedKmh) {
    return null;
  }
  if (w.gradePercent < -1.0 || w.gradePercent > 3.0) {
    return null;
  }
  if (w.osActivity != OsMotionLabel.walking ||
      w.osConfidence < DetectionThresholds.minWalkingOsConfidence) {
    return null;
  }
  if (w.steps != null) {
    if (w.steps! < 15 || w.distanceMeters <= 15) return null;
    final stride = w.distanceMeters / w.steps!;
    if (stride < DetectionThresholds.walkStrideMinMeters ||
        stride > DetectionThresholds.walkFromRunStrideMaxMeters) {
      return null;
    }
  }
  if (w.accelBurst != null && w.accelBurst!.dynamicStdDevMps2 >= 2.2) {
    return null;
  }
  return ActivityEvaluation(
    isMismatch: true,
    detectedCategory: DetectedCategory.walk,
    suggestedJenis: 'berjalan',
    isVehicleDetected: false,
    confidenceScore: w.osConfidence.clamp(75, 100),
    reasons: <String>[...priorReasons, 'WALK_DETECTED_IN_RUN'],
  );
}

ActivityEvaluation _evaluateRideToFoot(TelemetryWindow w) {
  if (w.medianSpeedKmh > DetectionThresholds.footInBikeMaxSpeedKmh ||
      (w.osActivity == OsMotionLabel.onBicycle &&
          w.osConfidence >= DetectionThresholds.minOsConfidence)) {
    return const ActivityEvaluation(
      isMismatch: false,
      detectedCategory: DetectedCategory.ride,
      suggestedJenis: null,
      isVehicleDetected: false,
      confidenceScore: 0,
      reasons: ['VERIFIED_CYCLING'],
    );
  }

  var score = 0;
  final reasons = <String>[];

  final isOsWalking =
      w.osActivity == OsMotionLabel.walking &&
      w.osConfidence >= DetectionThresholds.minWalkingOsConfidence;
  final isOsRunning =
      w.osActivity == OsMotionLabel.running &&
      w.osConfidence >= DetectionThresholds.minOsConfidence;
  if (isOsWalking || isOsRunning) {
    score += 40;
    reasons.add('OS_FOOT_CONFIRMED');
  }

  if (w.steps != null && w.steps! >= 25 && w.distanceMeters > 15) {
    final stride = w.distanceMeters / w.steps!;
    if (stride >= DetectionThresholds.walkStrideMinMeters &&
        stride <= DetectionThresholds.runStrideMaxMeters) {
      score += 40;
      reasons.add('FOOT_STRIDE_CONFIRMED');
    }
  }

  final burst = w.accelBurst;
  if (burst != null &&
      burst.heelStrikePeaks >= DetectionThresholds.accelMinWalkPeaks5s &&
      burst.dynamicStdDevMps2 >= DetectionThresholds.accelMinFootStdMps2) {
    score += 40;
    reasons.add('ACCEL_FOOT_IMPACTS');
  }

  final clamped = score.clamp(0, 100);
  if (clamped >= 70) {
    final DetectedCategory cat;
    final String suggested;
    if (isOsRunning &&
        w.medianSpeedKmh >= DetectionThresholds.walkToFullRunMinSpeedKmh) {
      cat = DetectedCategory.run;
      suggested = 'lari';
    } else if (isOsRunning ||
        (w.medianSpeedKmh >= 6.8 && w.medianSpeedKmh <= 10.5)) {
      cat = DetectedCategory.jog;
      suggested = 'joging';
    } else {
      cat = DetectedCategory.walk;
      suggested = 'berjalan';
    }
    reasons.add('FOOT_IN_BIKE_MODE');
    return ActivityEvaluation(
      isMismatch: true,
      detectedCategory: cat,
      suggestedJenis: suggested,
      isVehicleDetected: false,
      confidenceScore: clamped,
      reasons: reasons,
    );
  }

  return ActivityEvaluation(
    isMismatch: false,
    detectedCategory: DetectedCategory.ride,
    suggestedJenis: null,
    isVehicleDetected: false,
    confidenceScore: clamped,
    reasons: reasons,
  );
}

/// Hysteresis controller gating UI alerts across 2–4 consecutive positive windows.
class ActivityMismatchMonitor {
  final Duration dismissCooldown;

  ActivityMismatchMonitor({
    this.dismissCooldown = const Duration(minutes: 3),
  });

  int _consecutiveWindows = 0;
  int _recoveryWindows = 0;
  String? _candidateKey;
  DateTime? _dismissedUntil;
  String? _dismissedKey;
  ActivityMismatch? _activeMismatch;

  int get consecutiveWindows => _consecutiveWindows;
  ActivityMismatch? get activeMismatch => _activeMismatch;

  void reset() {
    _consecutiveWindows = 0;
    _recoveryWindows = 0;
    _candidateKey = null;
    _dismissedUntil = null;
    _dismissedKey = null;
    _activeMismatch = null;
  }

  void dismiss({DateTime? now}) {
    final current = _activeMismatch;
    if (current != null) {
      _dismissedKey = _signatureKey(
        current.detectedCategory,
        current.suggestedJenis,
        current.isVehicleDetected,
      );
      _dismissedUntil = (now ?? DateTime.now()).add(dismissCooldown);
    }
    _consecutiveWindows = 0;
    _recoveryWindows = 0;
    _candidateKey = null;
    _activeMismatch = null;
  }

  /// Evaluates a single 30 s telemetry window and updates hysteresis state.
  ActivityMismatch? ingestWindow({
    required SportType selectedSport,
    required TelemetryWindow window,
    DateTime? now,
  }) {
    final eval = evaluateActivityWindow(selectedSport, window);
    if (!eval.isMismatch) {
      _consecutiveWindows = 0;
      _candidateKey = null;
      final active = _activeMismatch;
      // Auto-clear transient Run/Jog -> Walk break warnings once running
      // resumes for 2 consecutive windows; never auto-clear ride/vehicle flags.
      final isTransientFootDrop =
          active != null &&
          !active.isVehicleDetected &&
          active.detectedCategory == DetectedCategory.walk &&
          (selectedSport == SportType.run || selectedSport == SportType.jog);
      if (isTransientFootDrop &&
          window.medianSpeedKmh >= DetectionThresholds.walkToRunMinSpeedKmh) {
        _recoveryWindows++;
        if (_recoveryWindows >=
            DetectionThresholds.requiredConsecutiveWindows) {
          _activeMismatch = null;
          _recoveryWindows = 0;
        }
      } else {
        _recoveryWindows = 0;
      }
      return _activeMismatch;
    }

    _recoveryWindows = 0;

    final key = _signatureKey(
      eval.detectedCategory,
      eval.suggestedJenis,
      eval.isVehicleDetected,
    );
    final clockNow = now ?? DateTime.now();
    if (_dismissedKey == key &&
        _dismissedUntil != null &&
        clockNow.isBefore(_dismissedUntil!)) {
      return null;
    }

    if (_candidateKey == key) {
      _consecutiveWindows++;
    } else {
      _candidateKey = key;
      _consecutiveWindows = 1;
    }

    final required = _requiredWindowsFor(selectedSport, eval);
    if (_consecutiveWindows >= required) {
      _activeMismatch = ActivityMismatch(
        selectedSport: selectedSport,
        detectedCategory: eval.detectedCategory,
        suggestedJenis: eval.suggestedJenis,
        isVehicleDetected: eval.isVehicleDetected,
        confidenceScore: eval.confidenceScore,
        reasons: List<String>.unmodifiable(eval.reasons),
      );
    }
    return _activeMismatch;
  }

  int _requiredWindowsFor(SportType selectedSport, ActivityEvaluation eval) {
    final isRunToWalk =
        (selectedSport == SportType.jog || selectedSport == SportType.run) &&
        eval.detectedCategory == DetectedCategory.walk &&
        !eval.isVehicleDetected;
    return isRunToWalk
        ? DetectionThresholds.walkInRunConsecutiveWindows
        : DetectionThresholds.requiredConsecutiveWindows;
  }

  String _signatureKey(
    DetectedCategory category,
    String? suggestedJenis,
    bool isVehicle,
  ) => '${category.name}:${suggestedJenis ?? ''}:$isVehicle';
}
