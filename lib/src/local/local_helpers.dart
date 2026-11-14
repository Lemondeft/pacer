import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/auth/user_model.dart';
import 'package:pacer/src/challenge/challenge_model.dart';
import 'package:pacer/src/local/local_models.dart';

/// Pure aggregation helpers shared by [SqliteLocalStore] and
/// [MemoryLocalStore] to guarantee identical offline rollup semantics.
({double jarakM, int waktuS})? computeEffectiveStatistik({
  required ({double jarakM, int waktuS})? baseline,
  required List<LocalActivity> activities,
  required String periode,
}) {
  var foundAny = baseline != null;
  var totalJarak = baseline?.jarakM ?? 0.0;
  var totalWaktu = baseline?.waktuS ?? 0;

  for (final item in activities) {
    if (item.status != RunStatus.finished) continue;
    final mulai = item.activity.mulaiAt;
    if (mulai == null || periodeKey(mulai.toLocal()) != periode) continue;

    if (baseline == null) {
      foundAny = true;
      totalJarak += item.activity.jarakM ?? 0;
      totalWaktu += item.activity.durasiS ?? 0;
    } else if (item.syncState != SyncState.synced && !item.statistikApplied) {
      foundAny = true;
      totalJarak += item.activity.jarakM ?? 0;
      totalWaktu += item.activity.durasiS ?? 0;
    }
  }

  return foundAny ? (jarakM: totalJarak, waktuS: totalWaktu) : null;
}

/// Computes current effective streak from server baseline + queued offline runs.
({int berjalan, DateTime? terakhir})? computeEffectiveStreak({
  required ({int berjalan, DateTime? terakhir})? baseline,
  required List<LocalActivity> activities,
}) {
  var count = baseline?.berjalan ?? 0;
  var last = baseline?.terakhir;

  final pending =
      activities
          .where(
            (a) =>
                a.status == RunStatus.finished &&
                a.syncState != SyncState.synced &&
                a.activity.mulaiAt != null,
          )
          .toList()
        ..sort((a, b) => a.activity.mulaiAt!.compareTo(b.activity.mulaiAt!));

  for (final item in pending) {
    final dayLocal = item.activity.mulaiAt!.toLocal();
    final dayDate = DateTime.utc(dayLocal.year, dayLocal.month, dayLocal.day);
    final lastDate = last == null
        ? null
        : DateTime.utc(last.year, last.month, last.day);
    if (lastDate != null && !dayDate.isAfter(lastDate)) {
      continue;
    }
    count = streakNext(terakhirTgl: last, today: dayLocal, current: count);
    last = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
  }

  if (baseline == null && last == null) return null;
  return (berjalan: count, terakhir: last);
}

/// Applies a partial Supabase profile patch (including explicit `null` clears)
/// onto a [UserProfile] instance.
UserProfile applyProfilePatch(
  UserProfile? existing,
  String userId,
  Map<String, dynamic> patch,
) {
  final base = (existing ?? UserProfile(id: userId)).toJson();
  for (final entry in patch.entries) {
    base[entry.key] = entry.value;
  }
  base['id'] = userId;
  return UserProfile.fromJson(base);
}

/// Computes current effective challenge participations from stored baselines
/// plus queued offline finished workouts (`syncState != synced`).
List<PartisipasiChallenge> computeEffectiveParticipations({
  required List<PartisipasiChallenge> baselines,
  required List<Challenge> challenges,
  required List<LocalActivity> activities,
}) {
  final challengeById = <String, Challenge>{
    for (final c in challenges) c.id: c,
  };
  final pendingFinished = activities
      .where(
        (a) =>
            a.status == RunStatus.finished && a.syncState != SyncState.synced,
      )
      .toList(growable: false);

  return [
    for (final p in baselines)
      _effectiveOneParticipation(p, challengeById[p.challengeId], pendingFinished),
  ];
}

PartisipasiChallenge _effectiveOneParticipation(
  PartisipasiChallenge baseline,
  Challenge? challenge,
  List<LocalActivity> pendingFinished,
) {
  if (challenge == null || pendingFinished.isEmpty) return baseline;
  var delta = 0.0;
  for (final item in pendingFinished) {
    delta += challengeActivityDelta(
      challenge: challenge,
      participation: baseline,
      activity: item.activity,
    );
  }
  if (delta <= 0) return baseline;
  final total = baseline.progressNilai + delta;
  return PartisipasiChallenge(
    id: baseline.id,
    challengeId: baseline.challengeId,
    userId: baseline.userId,
    progressNilai: total,
    berhasil:
        baseline.berhasil ||
        (challenge.targetNilai > 0 && total >= challenge.targetNilai),
    createdAt: baseline.createdAt,
  );
}

/// Adjusts stored participation baselines by a single [activity]
/// ([sign] = 1 on sync without server snapshot, [sign] = -1 when deleting
/// an already-synced activity locally).
PartisipasiChallenge applyActivityDeltaToBaseline({
  required PartisipasiChallenge baseline,
  required Challenge? challenge,
  required Activity activity,
  int sign = 1,
}) {
  if (challenge == null) return baseline;
  final delta = challengeActivityDelta(
    challenge: challenge,
    participation: baseline,
    activity: activity,
  );
  if (delta <= 0) return baseline;
  final rawTotal = baseline.progressNilai + (delta * sign);
  final total = rawTotal < 0 ? 0.0 : rawTotal;
  final achieved = sign < 0
      ? (challenge.targetNilai > 0 && total >= challenge.targetNilai)
      : (baseline.berhasil ||
          (challenge.targetNilai > 0 && total >= challenge.targetNilai));
  return PartisipasiChallenge(
    id: baseline.id,
    challengeId: baseline.challengeId,
    userId: baseline.userId,
    progressNilai: total,
    berhasil: achieved,
    createdAt: baseline.createdAt,
  );
}
