import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pacer/supabase.dart';
import 'package:pacer/src/leaderboard/leaderboard_model.dart';

/// Backend-only leaderboard reads (DFD process 4.0 LEADERBOARD & PERINGKAT). No widgets.
///
/// RLS: all authenticated users read leaderboard/peringkat; writes are
/// coach/admin only (is_coach_or_admin), so this repository is read-only.
class LeaderboardRepository {
  final SupabaseClient _client;

  LeaderboardRepository({SupabaseClient? client}) : _client = client ?? supa;

  /// Lists leaderboard boards, newest first.
  Future<List<Leaderboard>> listLeaderboards({int limit = 20}) async {
    final rows = await _client
        .from('leaderboard')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return [
      for (final row in rows)
        Leaderboard.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Standings of one board ordered by nilai desc (best first), capped at [limit].
  Future<List<Peringkat>> getPeringkatList(
    String leaderboardId, {
    int limit = 50,
  }) async {
    final rows = await _client
        .from('peringkat')
        .select()
        .eq('leaderboard_id', leaderboardId)
        .order('nilai', ascending: false)
        .limit(limit);
    return [
      for (final row in rows)
        Peringkat.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// The caller's own ranked entries across all boards, newest update first.
  Future<List<Peringkat>> myPeringkat() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('No signed-in user.');
    final rows = await _client
        .from('peringkat')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    return [
      for (final row in rows)
        Peringkat.fromJson(Map<String, dynamic>.from(row)),
    ];
  }
}
