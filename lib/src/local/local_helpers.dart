import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/auth/user_model.dart';
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
