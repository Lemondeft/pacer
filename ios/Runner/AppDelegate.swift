import CoreMotion
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let activityManager = CMMotionActivityManager()
  private let pedometer = CMPedometer()
  private var activitySink: FlutterEventSink?
  private var stepsSink: FlutterEventSink?
  private var lastPedometerSteps = 0
  private var monitoring = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()

    let methodChannel = FlutterMethodChannel(
      name: "com.example.pacer/motion",
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(false)
        return
      }
      switch call.method {
      case "ensurePermission":
        self.ensureMotionPermission(result: result)
      case "startMonitoring":
        self.startMonitoring()
        result(nil)
      case "stopMonitoring":
        self.stopMonitoring()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let activityChannel = FlutterEventChannel(
      name: "com.example.pacer/motion/activity",
      binaryMessenger: messenger
    )
    activityChannel.setStreamHandler(MotionStreamHandler(
      onListen: { [weak self] sink in self?.activitySink = sink },
      onCancel: { [weak self] in self?.activitySink = nil }
    ))

    let stepsChannel = FlutterEventChannel(
      name: "com.example.pacer/motion/steps",
      binaryMessenger: messenger
    )
    stepsChannel.setStreamHandler(MotionStreamHandler(
      onListen: { [weak self] sink in self?.stepsSink = sink },
      onCancel: { [weak self] in self?.stepsSink = nil }
    ))
  }

  private func ensureMotionPermission(result: @escaping FlutterResult) {
    if !CMMotionActivityManager.isActivityAvailable() && !CMPedometer.isStepCountingAvailable() {
      result(false)
      return
    }
    let status = CMMotionActivityManager.authorizationStatus()
    switch status {
    case .authorized:
      result(true)
    case .denied, .restricted:
      result(false)
    case .notDetermined:
      let now = Date()
      activityManager.queryActivityStarting(from: now, to: now, to: .main) { _, error in
        let granted = error == nil && CMMotionActivityManager.authorizationStatus() == .authorized
        result(granted)
      }
    @unknown default:
      result(false)
    }
  }

  private func startMonitoring() {
    guard !monitoring else { return }
    monitoring = true
    lastPedometerSteps = 0

    if CMMotionActivityManager.isActivityAvailable() {
      activityManager.startActivityUpdates(to: .main) { [weak self] activity in
        guard let self = self, let activity = activity, self.monitoring else { return }
        let label: String
        if activity.automotive {
          label = "IN_VEHICLE"
        } else if activity.cycling {
          label = "ON_BICYCLE"
        } else if activity.running {
          label = "RUNNING"
        } else if activity.walking {
          label = "WALKING"
        } else {
          label = "UNKNOWN"
        }
        let confidence: Int
        switch activity.confidence {
        case .high:
          confidence = 90
        case .medium:
          confidence = 65
        case .low:
          confidence = 35
        @unknown default:
          confidence = 35
        }
        self.activitySink?(["label": label, "confidence": confidence])
      }
    }

    if CMPedometer.isStepCountingAvailable() {
      pedometer.startUpdates(from: Date()) { [weak self] data, _ in
        guard let self = self, let data = data else { return }
        DispatchQueue.main.async {
          guard self.monitoring else { return }
          let total = data.numberOfSteps.intValue
          let delta = max(0, total - self.lastPedometerSteps)
          self.lastPedometerSteps = total
          if delta > 0 {
            self.stepsSink?(delta)
          }
        }
      }
    }
  }

  private func stopMonitoring() {
    monitoring = false
    activityManager.stopActivityUpdates()
    pedometer.stopUpdates()
    lastPedometerSteps = 0
  }
}

private final class MotionStreamHandler: NSObject, FlutterStreamHandler {
  private let onListenCallback: (@escaping FlutterEventSink) -> Void
  private let onCancelCallback: () -> Void

  init(
    onListen: @escaping (@escaping FlutterEventSink) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.onListenCallback = onListen
    self.onCancelCallback = onCancel
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    onListenCallback(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    onCancelCallback()
    return nil
  }
}
