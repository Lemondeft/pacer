# Activity Classification & Anti-Cheat Specification (All Sports + Vehicle)

Pacer's five-layer activity classification and anti-cheat pipeline spans all four supported sports (`'berjalan'` Walk, `'joging'` Jogging, `'lari'` Outdoor Run, `'bersepeda'` Cycling) plus motor vehicle (`IN_VEHICLE`) detection.

---

## 1. Universal 5-Layer Architecture

1. **Layer 1 — GPS Kinematic Sanitization (`GpsSanitizer` in `lib/src/tracking/activity_classifier.dart`)**
   - Drops coordinates with horizontal accuracy `> 20.0 m`, invalid/non-finite WGS-84 coordinates, or non-monotonic timestamps (`<= lastValidTimestamp`).
   - Enforces a raw teleport ceiling (`110.0 km/h`) and single-ping multipath acceleration clamp (`|v2 - v1| / dt > 4.0 m/s^2` within `<= 10 s`). Smooth motor vehicle ramps stay below `4.0 m/s^2` and pass through to Layers 4–5 for cheat detection.
   - Maintains a 30-second sliding buffer computing `medianSpeedKmh`, `p85SpeedKmh`, `distanceMeters`, and filtered `gradePercent`.

2. **Layer 2 — Passive OS Sensor Hub (`MotionSensorProvider` in `lib/src/tracking/motion_sensors.dart`)**
   - Streams hardware-fused OS motion labels (`WALKING`, `RUNNING`, `ON_BICYCLE`, `IN_VEHICLE`, `UNKNOWN`) with integer `0..100` confidence plus hardware step deltas (`TYPE_STEP_DETECTOR` / `TYPE_STEP_COUNTER` on Android; `CMMotionActivityManager` + `CMPedometer` on iOS) over platform channel `com.example.pacer/motion`.
   - Safely falls back to `NoopMotionSensorProvider` on Linux desktop, Web, tests, or denied motion permissions.

3. **Layer 3 — Targeted 25 Hz Accelerometer Burst Analysis**
   - Samples a battery-safe **5-second (`125`-sample) burst at `25 Hz`** via `sensors_plus` at most once per 30 s window only when telemetry enters a sport-specific ambiguity zone, OS confidence `< 75`, or pedometer steps are unavailable (`null`).
   - Computes vector magnitude $m_i$, gravity-centered dynamic acceleration $d_i = m_i - \bar{m}$, dynamic standard deviation $\sigma_d$, mean absolute jerk $J_{\text{mean}}$, `250 ms` refractory foot-strike impact peaks (`> 3.5 m/s^2`), plus cycling (`peaks < 5 && std <= 1.7 && jerk <= 20.0`) and smooth vehicle cabin (`peaks <= 1 && std <= 0.9 && jerk <= 12.0`) signatures.

4. **Layer 4 — Bidirectional Multi-Sport Fusion & Hysteresis (`evaluateActivityWindow`, `ActivityMismatchMonitor`)**
   - Evaluates the active sport against competing modes with protective biomechanics guardrails:
     - **Walk (`berjalan`) -> Bike (`bersepeda`)**: `score >= 70` from OS `ON_BICYCLE`/`IN_VEHICLE`, zero/impossible crank stride (`> 2.20 m`), smooth cycling burst, or sustained pace `> 14.0 km/h` flat (`> 17.5 km/h` downhill). Protected when `RUNNING >= 75` or foot-strike `peaks >= 6`. Required: **2 consecutive windows (`60 s`)**.
     - **Walk (`berjalan`) -> Jog/Run (`joging` / `lari`)**: `RUNNING >= 75` + valid run stride `1.15..1.95 m` (`steps >= 50`) or foot-strike `peaks >= 7 && std >= 2.5`; picks `'lari'` at `>= 10.5 km/h`, `'joging'` at `7.5..10.5 km/h`. Protects brisk `6.4 km/h` walkers. Required: **2 windows (`60 s`)**.
     - **Jog/Run (`joging` / `lari`) -> Bike Cheat (`bersepeda`)**: `ON_BICYCLE >= 75` at `> 10.5 km/h`, `steps < 8` / stride `> 2.20 m`, cycling accel signature, or sustained pace `> 24.0 km/h` flat (`> 28.0 km/h` downhill). Protected by `RUNNING >= 75`, valid foot stride `1.0..2.15 m`, or `peaks >= 6`. Required: **2 windows (`60 s`)**.
     - **Jog/Run (`joging` / `lari`) -> Walk (`berjalan`)**: sustained `< 5.8 km/h` on gentle terrain (`-1% <= grade <= 3%`), `WALKING >= 80`, walk stride `0.50..1.05 m`, `std <= 2.2`. Never prompts `'joging' <-> 'lari'`. Required: **4 consecutive windows (`120 s`)**.
     - **Bike (`bersepeda`) -> Foot (`berjalan` / `joging` / `lari`)**: `WALKING >= 80` or `RUNNING >= 75`, `steps >= 25` (`stride 0.50..1.95 m`), or `peaks >= 5 && std >= 2.1` at `<= 18.0 km/h`. Cancelled if `> 18 km/h` or `ON_BICYCLE >= 75`. Required: **2 windows (`60 s`)**.
     - **Any Sport -> Motor Vehicle (`vehicle`)**: `IN_VEHICLE >= 80` at `>= 22 km/h` with smooth cabin accel (`std <= 0.9, jerk <= 12.0, peaks <= 1`), or sustained `> 45 km/h` flat (`> 60 km/h` downhill). Protects steep cycling descents (`<= 58 km/h`) with `ON_BICYCLE`. Required: **2 windows (`60 s`)**.

5. **Layer 5 — Server Post-Upload Audit (`supabase/functions/validate-activity/index.ts`)**
   - Invoked non-fatally by `SyncEngine` right after `rute_points` upload completes.
   - Optionally map-matches tracks via `OSRM_BASE_URL` or `VALHALLA_BASE_URL` to inspect `motorway`/`trunk` highway tags and scans sliding 120-second grade-adjusted windows across all four sports + vehicle speeds, honoring uploaded `cadence_spm` (`145..210 spm`).
   - Marks `aktivitas.validation_status` (`verified`, `flagged_ride`, `flagged_mismatch`, `flagged_vehicle`, `reclassified`), updates `suggested_sport`, triggers `recompute_user_challenge_progress` (which excludes flagged rows across all sports), and emits `user_notifications` rows (`sport_reclassification_suggested`, `vehicle_activity_flagged`).

---

## 2. Threshold Calibration Constants (`DetectionThresholds`)

| Constant | Value | Purpose |
| :--- | :--- | :--- |
| `maxGpsAccuracyMeters` | `20.0 m` | Reject low-accuracy GPS fixes |
| `maxHumanAccelMps2` | `4.0 m/s²` | Reject single-ping multipath velocity teleports |
| `gpsRawTeleportCeilingKmh` | `110.0 km/h` | Upper raw sanity ceiling retaining vehicle speeds for L4/L5 |
| `windowDurationSeconds` | `30 s` | Rolling telemetry evaluation interval |
| `requiredConsecutiveWindows` | `2` (`60 s`) | Default hysteresis window count for mismatch / vehicle alerts |
| `walkInRunConsecutiveWindows` | `4` (`120 s`) | Conservative Run/Jog -> Walk hysteresis to avoid trail/cooldown nagging |
| `minOsConfidence` | `75` | Minimum confidence for `ON_BICYCLE` / `RUNNING` |
| `walkStrideRangeMeters` | `0.50..1.15 m` | Valid walking stride |
| `runStrideRangeMeters` | `1.15..1.95 m` | Valid running stride |
| `impossibleStrideMeters` | `> 2.20 m` | Crank rotation phantom step cutoff |
| `accelSampleRateHz` / `Duration` | `25 Hz` / `5 s` | `125`-sample burst budget |
| `accelHeelStrikePeakMps2` | `> 3.5 m/s²` | Gravity-removed impact spike threshold (`250 ms` refractory) |
| `accelMaxBikeStdMps2` / `Jerk` | `1.7 m/s²` / `20.0 m/s³` | Non-impact cycling threshold |
| `accelMaxVehicleStdMps2` / `Jerk` | `0.9 m/s²` / `12.0 m/s³` | Low-vibration vehicle cabin threshold |
| `runBikeSpeedThreshold` | `24.0` flat / `28.0` downhill km/h | Sustained non-foot cutoff during Run/Jog |
| `vehicleSpeedLimit` | `45.0` flat / `60.0` downhill km/h | Sustained motor vehicle cutoff across all sports |
| `serverSustainedWindowSec` | `120 s` | Server post-upload audit window |
| `serverWalkLimitsKmh` | `11.5` flat / `15.5` downhill km/h | Server Walk speed ceiling |

---

## 3. Required Verification Scenarios

1. Original Walk vs. Bike matrix:
   - Urban GPS Drift (`45 km/h` ping with `accuracy: 42 m` dropped; not flagged)
   - Brisk Walk (`6.4 km/h`, `58` steps, `WALKING (85)` -> stays Walk)
   - Downhill Jog (`13.5 km/h`, `-4%`, `82` steps, `RUNNING (88)`, `9` peaks -> protected from bike flag, suggests `'lari'`)
   - Uphill Bike Climb Gray Zone (`10.0 km/h`, `+4%`, `0` steps, `UNKNOWN (0)`, `0` peaks, `std 0.65`, `jerk 9.4` -> Bike)
   - Pocket Cycling Phantom Steps (`19.5 km/h`, `45` steps = `3.61 m` stride, `ON_BICYCLE (82)` -> Bike)
   - Handlebar Bike Permissions Denied (`16.8 km/h`, `steps: null`, `0` peaks, `std 0.45`, `jerk 11.0` -> Bike)
2. Full Multi-Activity + Vehicle extensions:
   - Jog/Run -> Bike Cheat (`26 km/h`, smooth accel + `ON_BICYCLE` -> `'bersepeda'`)
   - Fast Runner Protected (`16.5 km/h`, `RUNNING (90)`, `1.65 m` stride, `10` peaks -> not flagged)
   - Walk -> Run (`11.5 km/h`, `RUNNING (85)`, `1.35 m` stride, `9` peaks -> suggests `'lari'`)
   - Bike -> Walk Forgotten Sport (`5.4 km/h`, `WALKING (86)`, `0.85 m` stride, `7` peaks -> suggests `'berjalan'`)
   - Vehicle Cheat (`50 km/h` or `28 km/h` + `IN_VEHICLE (88)`, smooth cabin accel -> `isVehicleDetected == true`)
   - Steep Downhill Cyclist Protected (`48 km/h`, `-6%`, `ON_BICYCLE (85)` -> not flagged as vehicle)
   - Hysteresis guarantee (`4` consecutive windows for Run -> Walk vs `2` for Swap / Vehicle)
