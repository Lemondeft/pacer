// Layer 5 server-side multi-activity & anti-cheat validator Edge Function.
// Performs 120s sliding-window kinematics, grade-adjusted pace (GAP) normalization,
// optional OSRM road map-matching, hardware cadence checks, and notification dispatch.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type SportType = "berjalan" | "joging" | "lari" | "bersepeda";
type ValidationStatus =
  | "verified"
  | "flagged_ride"
  | "flagged_mismatch"
  | "flagged_vehicle"
  | "reclassified";

interface RoutePointRow {
  urutan: number;
  lat: number;
  lng: number;
  elevasi_m: number | null;
  kecepatan_ms: number | null;
  direkam_at: string | null;
}

interface SegmentMetric {
  dtS: number;
  distanceM: number;
  speedMs: number;
  gapSpeedMs: number;
  grade: number;
  tMs: number;
}

interface Verdict {
  validationStatus: ValidationStatus;
  suggestedSport: SportType | null;
  score: number;
  reasons: string[];
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function haversineMeters(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const r = 6_371_000;
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * r * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function clamp(v: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, v));
}

function percentile(sortedAsc: number[], p: number): number {
  if (sortedAsc.length === 0) return 0;
  const idx = (sortedAsc.length - 1) * clamp(p, 0, 1);
  const lo = Math.floor(idx);
  const hi = Math.ceil(idx);
  if (lo === hi) return sortedAsc[lo];
  const frac = idx - lo;
  return sortedAsc[lo] * (1 - frac) + sortedAsc[hi] * frac;
}

// Minetti-style energy-cost curve ratio relative to flat running (0% grade).
function gapEquivalentMultiplier(grade: number): number {
  const g = clamp(grade, -0.35, 0.35);
  const cost =
    155.4 * g ** 5 -
    30.4 * g ** 4 -
    43.3 * g ** 3 +
    46.3 * g ** 2 +
    19.5 * g +
    3.6;
  return clamp(cost / 3.6, 0.65, 2.2);
}

function analyzeSegments(points: RoutePointRow[]): {
  segments: SegmentMetric[];
  avgKmh: number;
  p90Kmh: number;
  sustained120sMaxKmh: number;
  gapAvgKmh: number;
  gapP90Kmh: number;
  maxUpGrade: number;
  totalDurationS: number;
} {
  const validPts = points
    .filter((p) => Number.isFinite(p.lat) && Number.isFinite(p.lng))
    .map((p) => ({
      ...p,
      tMs: p.direkam_at ? Date.parse(p.direkam_at) : NaN,
    }))
    .filter((p) => Number.isFinite(p.tMs));

  const segments: SegmentMetric[] = [];
  let maxUpGrade = 0;

  for (let i = 1; i < validPts.length; i++) {
    const prev = validPts[i - 1];
    const curr = validPts[i];
    const dtS = (curr.tMs - prev.tMs) / 1000;
    if (dtS < 0.5 || dtS > 300) continue;

    const rawDist = haversineMeters(prev.lat, prev.lng, curr.lat, curr.lng);
    const speedMs = rawDist / dtS;
    if (speedMs > 55) continue; // Ignore obvious >198 km/h GPS teleport spikes.

    let grade = 0;
    if (
      rawDist >= 15 &&
      prev.elevasi_m != null &&
      curr.elevasi_m != null &&
      Number.isFinite(prev.elevasi_m) &&
      Number.isFinite(curr.elevasi_m)
    ) {
      grade = clamp((curr.elevasi_m - prev.elevasi_m) / rawDist, -0.45, 0.45);
      if (grade > maxUpGrade) maxUpGrade = grade;
    }

    const mult = gapEquivalentMultiplier(grade);
    // Uphill running equates to faster flat-equivalent effort; steep downhill
    // slightly discounts artificially high coasting speeds for foot classification.
    const gapSpeedMs =
      grade >= 0 ? speedMs * mult : speedMs / Math.max(0.8, 1 + Math.abs(grade));

    segments.push({
      dtS,
      distanceM: rawDist,
      speedMs,
      gapSpeedMs,
      grade,
      tMs: curr.tMs,
    });
  }

  if (segments.length === 0) {
    return {
      segments,
      avgKmh: 0,
      p90Kmh: 0,
      sustained120sMaxKmh: 0,
      gapAvgKmh: 0,
      gapP90Kmh: 0,
      maxUpGrade: 0,
      totalDurationS: 0,
    };
  }

  let sumDist = 0;
  let sumDt = 0;
  let sumGapDist = 0;
  const speedsKmh: number[] = [];
  const gapSpeedsKmh: number[] = [];

  for (const s of segments) {
    sumDist += s.distanceM;
    sumDt += s.dtS;
    sumGapDist += s.gapSpeedMs * s.dtS;
    speedsKmh.push(s.speedMs * 3.6);
    gapSpeedsKmh.push(s.gapSpeedMs * 3.6);
  }
  speedsKmh.sort((a, b) => a - b);
  gapSpeedsKmh.sort((a, b) => a - b);

  // Sliding 120-second window sustained max speed.
  let sustained120sMaxKmh = 0;
  for (let start = 0; start < segments.length; start++) {
    let winDt = 0;
    let winDist = 0;
    for (let end = start; end < segments.length; end++) {
      winDt += segments[end].dtS;
      winDist += segments[end].distanceM;
      if (winDt >= 120) {
        const kmh = (winDist / winDt) * 3.6;
        if (kmh > sustained120sMaxKmh) sustained120sMaxKmh = kmh;
        break;
      }
    }
  }

  return {
    segments,
    avgKmh: sumDt > 0 ? (sumDist / sumDt) * 3.6 : 0,
    p90Kmh: percentile(speedsKmh, 0.9),
    sustained120sMaxKmh,
    gapAvgKmh: sumDt > 0 ? (sumGapDist / sumDt) * 3.6 : 0,
    gapP90Kmh: percentile(gapSpeedsKmh, 0.9),
    maxUpGrade,
    totalDurationS: sumDt,
  };
}

async function queryOsrmRoadMatch(
  points: RoutePointRow[],
): Promise<{ matched: boolean; highConfidenceRoad: boolean }> {
  const coords = points.filter(
    (p) => Number.isFinite(p.lat) && Number.isFinite(p.lng),
  );
  if (coords.length < 4) return { matched: false, highConfidenceRoad: false };

  const step = Math.max(1, Math.floor(coords.length / 50));
  const sampled = coords.filter((_, idx) => idx % step === 0).slice(0, 50);
  const coordStr = sampled.map((p) => `${p.lng},${p.lat}`).join(";");
  const baseUrl = Deno.env.get("OSRM_BASE_URL") || "https://router.project-osrm.org";
  const url = `${baseUrl}/match/v1/driving/${coordStr}?overview=false&tidy=true`;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 2500);
  try {
    const res = await fetch(url, { signal: controller.signal });
    if (!res.ok) return { matched: false, highConfidenceRoad: false };
    const data = await res.json();
    const matchings = Array.isArray(data?.matchings) ? data.matchings : [];
    if (matchings.length === 0) return { matched: false, highConfidenceRoad: false };
    const topConfidence = Math.max(
      ...matchings.map((m: { confidence?: number }) => Number(m?.confidence ?? 0)),
    );
    return {
      matched: topConfidence >= 0.4,
      highConfidenceRoad: topConfidence >= 0.7,
    };
  } catch {
    return { matched: false, highConfidenceRoad: false };
  } finally {
    clearTimeout(timeout);
  }
}

function classifyServerVerdict(params: {
  jenis: SportType;
  cadenceSpm: number | null;
  avgKmh: number;
  p90Kmh: number;
  sustained120sMaxKmh: number;
  gapAvgKmh: number;
  gapP90Kmh: number;
  maxUpGrade: number;
  totalDurationS: number;
  osrm: { matched: boolean; highConfidenceRoad: boolean };
}): Verdict {
  const reasons: string[] = [];
  const {
    jenis,
    cadenceSpm,
    avgKmh,
    p90Kmh,
    sustained120sMaxKmh,
    gapAvgKmh,
    gapP90Kmh,
    maxUpGrade,
    totalDurationS,
    osrm,
  } = params;

  if (totalDurationS < 60) {
    return {
      validationStatus: "verified",
      suggestedSport: null,
      score: 0.1,
      reasons: ["duration_under_60s"],
    };
  }

  // 1. Motorized vehicle check across all sports.
  const lowCadence = cadenceSpm == null || cadenceSpm < 50;
  if (
    sustained120sMaxKmh > 60 ||
    (p90Kmh >= 42 && lowCadence && (osrm.highConfidenceRoad || sustained120sMaxKmh >= 38))
  ) {
    reasons.push(`sustained_120s_max=${sustained120sMaxKmh.toFixed(1)}kmh`);
    reasons.push(`p90=${p90Kmh.toFixed(1)}kmh`);
    if (osrm.highConfidenceRoad) reasons.push("osrm_high_confidence_road");
    return {
      validationStatus: "flagged_vehicle",
      suggestedSport: null,
      score: 0.95,
      reasons,
    };
  }

  // 2. Foot sports (berjalan / joging / lari) claimed.
  if (jenis === "berjalan" || jenis === "joging" || jenis === "lari") {
    const nonRunningCadence = cadenceSpm == null || cadenceSpm < 115;
    if (
      sustained120sMaxKmh >= 20 ||
      (p90Kmh >= 18 && avgKmh >= 14.5 && nonRunningCadence) ||
      (gapP90Kmh >= 22 && nonRunningCadence)
    ) {
      reasons.push(`p90=${p90Kmh.toFixed(1)}kmh`);
      reasons.push(`sustained_120s=${sustained120sMaxKmh.toFixed(1)}kmh`);
      if (osrm.matched) reasons.push("osrm_road_corridor");
      return {
        validationStatus: "flagged_ride",
        suggestedSport: "bersepeda",
        score: 0.88,
        reasons,
      };
    }

    if (
      jenis === "berjalan" &&
      totalDurationS >= 120 &&
      (avgKmh >= 9.0 || (gapP90Kmh >= 10.5 && (cadenceSpm == null || cadenceSpm >= 145)))
    ) {
      const suggested: SportType = p90Kmh >= 12.5 ? "lari" : "joging";
      reasons.push(`walk_speed_too_high avg=${avgKmh.toFixed(1)}kmh`);
      return {
        validationStatus: "flagged_mismatch",
        suggestedSport: suggested,
        score: 0.78,
        reasons,
      };
    }

    if (
      jenis === "lari" &&
      totalDurationS >= 120 &&
      avgKmh < 5.5 &&
      p90Kmh < 6.8 &&
      maxUpGrade < 0.08 &&
      (cadenceSpm == null || cadenceSpm < 128)
    ) {
      reasons.push(`run_speed_matches_walk avg=${avgKmh.toFixed(1)}kmh`);
      return {
        validationStatus: "flagged_mismatch",
        suggestedSport: "berjalan",
        score: 0.75,
        reasons,
      };
    }
  }

  // 3. Cycling claimed (bersepeda).
  if (jenis === "bersepeda" && totalDurationS >= 120) {
    if (
      (avgKmh < 12.0 && cadenceSpm != null && cadenceSpm >= 138) ||
      (avgKmh < 7.5 && p90Kmh < 9.5 && cadenceSpm != null && cadenceSpm >= 95)
    ) {
      const suggested: SportType =
        gapAvgKmh >= 10.5 ? "lari" : gapAvgKmh >= 7.5 ? "joging" : "berjalan";
      reasons.push(`cycling_has_foot_cadence=${cadenceSpm}`);
      return {
        validationStatus: "flagged_mismatch",
        suggestedSport: suggested,
        score: 0.82,
        reasons,
      };
    }

    if (
      cadenceSpm == null &&
      totalDurationS >= 180 &&
      avgKmh < 6.5 &&
      p90Kmh < 8.5 &&
      maxUpGrade < 0.06
    ) {
      reasons.push(`cycling_slow_flat avg=${avgKmh.toFixed(1)}kmh`);
      return {
        validationStatus: "flagged_mismatch",
        suggestedSport: "berjalan",
        score: 0.72,
        reasons,
      };
    }
  }

  return {
    validationStatus: "verified",
    suggestedSport: null,
    score: 0.15,
    reasons: ["kinematics_consistent"],
  };
}

function sportLabel(sport: SportType, lang: string): string {
  const en = lang.toLowerCase() === "en";
  switch (sport) {
    case "berjalan":
      return en ? "Walking" : "Berjalan";
    case "joging":
      return en ? "Jogging" : "Joging";
    case "bersepeda":
      return en ? "Cycling" : "Bersepeda";
    case "lari":
      return en ? "Running" : "Lari";
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceKey) {
    return jsonResponse({ error: "Server configuration missing" }, 500);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    return jsonResponse({ error: "Missing bearer token" }, 401);
  }

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const {
    data: { user },
    error: authError,
  } = await admin.auth.getUser(token);
  if (authError || !user) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  let body: { aktivitas_id?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const aktivitasId = typeof body?.aktivitas_id === "string"
    ? body.aktivitas_id.trim()
    : "";
  if (!aktivitasId) {
    return jsonResponse({ error: "aktivitas_id required" }, 400);
  }

  const { data: activity, error: actErr } = await admin
    .from("aktivitas")
    .select("id, user_id, jenis, durasi_s, jarak_m, cadence_spm, validation_status")
    .eq("id", aktivitasId)
    .maybeSingle();

  if (actErr) {
    return jsonResponse({ error: actErr.message }, 500);
  }
  if (!activity) {
    return jsonResponse({ error: "Activity not found" }, 404);
  }
  if (activity.user_id !== user.id) {
    return jsonResponse({ error: "Forbidden" }, 403);
  }

  if (activity.validation_status === "reclassified") {
    return jsonResponse({
      validation_status: "reclassified",
      suggested_sport: null,
    });
  }

  const { data: points, error: ptsErr } = await admin
    .from("rute_points")
    .select("urutan, lat, lng, elevasi_m, kecepatan_ms, direkam_at")
    .eq("aktivitas_id", aktivitasId)
    .order("urutan", { ascending: true });

  if (ptsErr) {
    return jsonResponse({ error: ptsErr.message }, 500);
  }

  const routePts = (points ?? []) as RoutePointRow[];
  const metrics = analyzeSegments(routePts);
  const osrm = metrics.p90Kmh >= 15
    ? await queryOsrmRoadMatch(routePts)
    : { matched: false, highConfidenceRoad: false };

  const verdict = classifyServerVerdict({
    jenis: activity.jenis as SportType,
    cadenceSpm: activity.cadence_spm ?? null,
    avgKmh: metrics.avgKmh,
    p90Kmh: metrics.p90Kmh,
    sustained120sMaxKmh: metrics.sustained120sMaxKmh,
    gapAvgKmh: metrics.gapAvgKmh,
    gapP90Kmh: metrics.gapP90Kmh,
    maxUpGrade: metrics.maxUpGrade,
    totalDurationS: metrics.totalDurationS || Number(activity.durasi_s ?? 0),
    osrm,
  });

  const { error: updateErr } = await admin
    .from("aktivitas")
    .update({
      validation_status: verdict.validationStatus,
      validation_score: verdict.score,
      validation_reasons: verdict.reasons,
      suggested_sport: verdict.suggestedSport,
      validated_at: new Date().toISOString(),
    })
    .eq("id", aktivitasId);

  if (updateErr) {
    return jsonResponse({ error: updateErr.message }, 500);
  }

  if (
    verdict.validationStatus === "flagged_vehicle" ||
    verdict.validationStatus === "flagged_ride" ||
    verdict.validationStatus === "flagged_mismatch"
  ) {
    const { data: profile } = await admin
      .from("users")
      .select("language")
      .eq("id", user.id)
      .maybeSingle();
    const lang = (profile?.language as string | null) ?? "id";
    const en = lang.toLowerCase() === "en";
    const notifType =
      verdict.validationStatus === "flagged_vehicle"
        ? "vehicle_activity_flagged"
        : "sport_reclassification_suggested";

    let title: string;
    let bodyText: string;
    if (verdict.validationStatus === "flagged_vehicle") {
      title = en ? "Vehicle Speed Flagged" : "Terdeteksi Kecepatan Kendaraan";
      bodyText = en
        ? "A recent session matched motorized vehicle speeds and was excluded from challenges."
        : "Aktivitas terbaru terdeteksi memakai kendaraan bermotor dan dikecualikan dari tantangan.";
    } else {
      const targetName = verdict.suggestedSport
        ? sportLabel(verdict.suggestedSport, lang)
        : sportLabel(activity.jenis as SportType, lang);
      title = en
        ? `Check Activity Type: ${targetName}`
        : `Periksa Jenis Aktivitas: ${targetName}`;
      bodyText = en
        ? `Recorded signals look closer to ${targetName}. Open History to switch sport type.`
        : `Sinyal gerak lebih cocok dengan ${targetName}. Buka Riwayat untuk mengubah jenis aktivitas.`;
    }

    await admin.from("user_notifications").insert({
      user_id: user.id,
      type: notifType,
      title,
      body: bodyText,
    });
  }

  return jsonResponse({
    validation_status: verdict.validationStatus,
    suggested_sport: verdict.suggestedSport,
    score: verdict.score,
    reasons: verdict.reasons,
  });
});
