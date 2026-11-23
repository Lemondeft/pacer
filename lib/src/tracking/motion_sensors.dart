import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'activity_classifier.dart';

/// Normalized OS motion recognition event with 0..100 confidence score.
class OsMotionEvent {
  final OsMotionLabel label;
  final int confidence;
  final DateTime timestamp;

  const OsMotionEvent({
    required this.label,
    required this.confidence,
    required this.timestamp,
  });
}

/// Abstract hardware sensor & OS activity recognition boundary for [RunRecorder].
abstract class MotionSensorProvider {
  Future<bool> ensureMotionPermission();
  Future<bool> ensureNotificationPermission() async => true;
  Future<void> startMonitoring() async {}
  Future<void> stopMonitoring() async {}

  Stream<OsMotionEvent> get osMotionStream;
  Stream<int> get stepDeltaStream;

  Future<List<AccelSample>> sampleAccelBurst({
    Duration duration = const Duration(
      seconds: DetectionThresholds.accelBurstDurationSec,
    ),
    int sampleRateHz = DetectionThresholds.accelSampleRateHz,
  });

  void dispose() {}
}

/// Safe fallback for Linux/Web/unsupported devices and isolated unit tests.
class NoopMotionSensorProvider implements MotionSensorProvider {
  const NoopMotionSensorProvider();

  @override
  Future<bool> ensureMotionPermission() async => false;

  @override
  Future<bool> ensureNotificationPermission() async => true;

  @override
  Future<void> startMonitoring() async {}

  @override
  Future<void> stopMonitoring() async {}

  @override
  Stream<OsMotionEvent> get osMotionStream => const Stream.empty();

  @override
  Stream<int> get stepDeltaStream => const Stream.empty();

  @override
  Future<List<AccelSample>> sampleAccelBurst({
    Duration duration = const Duration(
      seconds: DetectionThresholds.accelBurstDurationSec,
    ),
    int sampleRateHz = DetectionThresholds.accelSampleRateHz,
  }) async => const [];

  @override
  void dispose() {}
}

/// Hardware implementation backed by `com.example.pacer/motion` and `sensors_plus`.
class PlatformMotionSensorProvider implements MotionSensorProvider {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.example.pacer/motion',
  );
  static const EventChannel _activityChannel = EventChannel(
    'com.example.pacer/motion/activity',
  );
  static const EventChannel _stepsChannel = EventChannel(
    'com.example.pacer/motion/steps',
  );

  bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Stream<OsMotionEvent>? _osStream;
  Stream<int>? _stepsStream;

  @override
  Future<bool> ensureMotionPermission() async {
    if (!_isMobilePlatform) return false;
    try {
      final granted = await _methodChannel.invokeMethod<bool>(
        'ensurePermission',
      );
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> ensureNotificationPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final granted = await _methodChannel.invokeMethod<bool>(
        'ensureNotificationPermission',
      );
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> startMonitoring() async {
    if (!_isMobilePlatform) return;
    try {
      await _methodChannel.invokeMethod<void>('startMonitoring');
    } catch (_) {
      // Safe soft-fail when native side or permission is unavailable.
    }
  }

  @override
  Future<void> stopMonitoring() async {
    if (!_isMobilePlatform) return;
    try {
      await _methodChannel.invokeMethod<void>('stopMonitoring');
    } catch (_) {}
  }

  @override
  Stream<OsMotionEvent> get osMotionStream {
    if (!_isMobilePlatform) return const Stream.empty();
    return _osStream ??= _activityChannel
        .receiveBroadcastStream()
        .map((dynamic raw) {
          if (raw is! Map) {
            return OsMotionEvent(
              label: OsMotionLabel.unknown,
              confidence: 0,
              timestamp: DateTime.now().toUtc(),
            );
          }
          final map = Map<String, dynamic>.from(raw);
          return OsMotionEvent(
            label: osMotionLabelFromString(map['label'] as String?),
            confidence: (map['confidence'] as num?)?.toInt().clamp(0, 100) ?? 0,
            timestamp: DateTime.now().toUtc(),
          );
        })
        .handleError((Object _) {})
        .asBroadcastStream();
  }

  @override
  Stream<int> get stepDeltaStream {
    if (!_isMobilePlatform) return const Stream.empty();
    return _stepsStream ??= _stepsChannel
        .receiveBroadcastStream()
        .map((dynamic raw) => (raw as num?)?.toInt() ?? 0)
        .where((delta) => delta > 0)
        .handleError((Object _) {})
        .asBroadcastStream();
  }

  @override
  Future<List<AccelSample>> sampleAccelBurst({
    Duration duration = const Duration(
      seconds: DetectionThresholds.accelBurstDurationSec,
    ),
    int sampleRateHz = DetectionThresholds.accelSampleRateHz,
  }) async {
    if (!_isMobilePlatform || sampleRateHz <= 0) return const [];
    final samples = <AccelSample>[];
    final completer = Completer<List<AccelSample>>();
    StreamSubscription<AccelerometerEvent>? sub;
    Timer? timer;

    void finish() {
      timer?.cancel();
      sub?.cancel();
      if (!completer.isCompleted) {
        completer.complete(List<AccelSample>.unmodifiable(samples));
      }
    }

    try {
      final period = Duration(
        microseconds: (1000000 / sampleRateHz).round().clamp(1000, 1000000),
      );
      sub = accelerometerEventStream(samplingPeriod: period).listen(
        (event) {
          samples.add(
            AccelSample(
              x: event.x,
              y: event.y,
              z: event.z,
              timestampMs: event.timestamp.millisecondsSinceEpoch,
            ),
          );
        },
        onError: (_) => finish(),
        onDone: finish,
      );
      timer = Timer(duration, finish);
      return await completer.future;
    } catch (_) {
      finish();
      return const [];
    }
  }

  @override
  void dispose() {
    unawaited(stopMonitoring());
  }
}
