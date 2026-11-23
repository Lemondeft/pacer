package com.example.pacer

import android.Manifest
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityRecognitionResult
import com.google.android.gms.location.DetectedActivity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), SensorEventListener {
    companion object {
        private const val METHOD_CHANNEL = "com.example.pacer/motion"
        private const val ACTIVITY_CHANNEL = "com.example.pacer/motion/activity"
        private const val STEPS_CHANNEL = "com.example.pacer/motion/steps"
        private const val ACTION_ACTIVITY_UPDATE = "com.example.pacer.ACTION_ACTIVITY_UPDATE"
        private const val MOTION_PERMISSION_REQUEST_CODE = 4201
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 4202
    }

    private var activitySink: EventChannel.EventSink? = null
    private var stepsSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

    private var activityReceiver: BroadcastReceiver? = null
    private var activityPendingIntent: PendingIntent? = null
    private var sensorManager: SensorManager? = null
    private var activeStepSensorType: Int? = null
    private var lastCumulativeStepCount: Int? = null
    private var monitoring = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "ensurePermission" -> handleEnsurePermission(result)
                "ensureNotificationPermission" -> handleEnsureNotificationPermission(result)
                "startMonitoring" -> {
                    startMonitoring()
                    result.success(null)
                }
                "stopMonitoring" -> {
                    stopMonitoring()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, ACTIVITY_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                activitySink = events
            }

            override fun onCancel(arguments: Any?) {
                activitySink = null
            }
        })

        EventChannel(messenger, STEPS_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                stepsSink = events
            }

            override fun onCancel(arguments: Any?) {
                stepsSink = null
            }
        })
    }

    private fun hasActivityPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACTIVITY_RECOGNITION
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun handleEnsurePermission(result: MethodChannel.Result) {
        if (hasActivityPermission()) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.success(false)
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
            MOTION_PERMISSION_REQUEST_CODE
        )
    }

    private fun handleEnsureNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (pendingNotificationPermissionResult != null) {
            result.success(false)
            return
        }
        pendingNotificationPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            MOTION_PERMISSION_REQUEST_CODE -> {
                val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
                pendingPermissionResult?.success(granted)
                pendingPermissionResult = null
            }
            NOTIFICATION_PERMISSION_REQUEST_CODE -> {
                val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
                pendingNotificationPermissionResult?.success(granted)
                pendingNotificationPermissionResult = null
            }
        }
    }

    private fun startMonitoring() {
        if (monitoring || !hasActivityPermission()) return
        monitoring = true
        startActivityRecognition()
        startStepSensor()
    }

    private fun stopMonitoring() {
        if (!monitoring) return
        monitoring = false
        stopActivityRecognition()
        stopStepSensor()
    }

    @SuppressLint("MissingPermission")
    private fun startActivityRecognition() {
        try {
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent == null || !ActivityRecognitionResult.hasResult(intent)) return
                    val result = ActivityRecognitionResult.extractResult(intent) ?: return
                    val probable = result.mostProbableActivity
                    val label = when (probable.type) {
                        DetectedActivity.IN_VEHICLE -> "IN_VEHICLE"
                        DetectedActivity.ON_BICYCLE -> "ON_BICYCLE"
                        DetectedActivity.RUNNING -> "RUNNING"
                        DetectedActivity.WALKING, DetectedActivity.ON_FOOT -> "WALKING"
                        else -> "UNKNOWN"
                    }
                    activitySink?.success(
                        mapOf(
                            "label" to label,
                            "confidence" to probable.confidence.coerceIn(0, 100)
                        )
                    )
                }
            }
            val filter = IntentFilter(ACTION_ACTIVITY_UPDATE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(receiver, filter)
            }
            activityReceiver = receiver

            val intent = Intent(ACTION_ACTIVITY_UPDATE).setPackage(packageName)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
            val pendingIntent = PendingIntent.getBroadcast(this, 0, intent, flags)
            activityPendingIntent = pendingIntent
            ActivityRecognition.getClient(this).requestActivityUpdates(5000L, pendingIntent)
        } catch (_: Exception) {
            // Device may lack Play Services; Dart classifier falls back to GPS + accel.
        }
    }

    @SuppressLint("MissingPermission")
    private fun stopActivityRecognition() {
        activityPendingIntent?.let { pi ->
            try {
                ActivityRecognition.getClient(this).removeActivityUpdates(pi)
            } catch (_: Exception) {}
        }
        activityPendingIntent = null
        activityReceiver?.let { r ->
            try {
                unregisterReceiver(r)
            } catch (_: Exception) {}
        }
        activityReceiver = null
    }

    private fun startStepSensor() {
        val mgr = getSystemService(Context.SENSOR_SERVICE) as? SensorManager ?: return
        sensorManager = mgr
        lastCumulativeStepCount = null
        val detector = mgr.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)
        if (detector != null) {
            activeStepSensorType = Sensor.TYPE_STEP_DETECTOR
            mgr.registerListener(this, detector, SensorManager.SENSOR_DELAY_NORMAL)
            return
        }
        val counter = mgr.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (counter != null) {
            activeStepSensorType = Sensor.TYPE_STEP_COUNTER
            mgr.registerListener(this, counter, SensorManager.SENSOR_DELAY_NORMAL)
        }
    }

    private fun stopStepSensor() {
        sensorManager?.unregisterListener(this)
        sensorManager = null
        activeStepSensorType = null
        lastCumulativeStepCount = null
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || !monitoring) return
        when (event.sensor.type) {
            Sensor.TYPE_STEP_DETECTOR -> {
                if (activeStepSensorType == Sensor.TYPE_STEP_DETECTOR) {
                    stepsSink?.success(1)
                }
            }
            Sensor.TYPE_STEP_COUNTER -> {
                if (activeStepSensorType == Sensor.TYPE_STEP_COUNTER) {
                    val total = event.values.firstOrNull()?.toInt() ?: return
                    val prev = lastCumulativeStepCount
                    lastCumulativeStepCount = total
                    if (prev != null && total > prev) {
                        stepsSink?.success(total - prev)
                    }
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onDestroy() {
        stopMonitoring()
        super.onDestroy()
    }
}
