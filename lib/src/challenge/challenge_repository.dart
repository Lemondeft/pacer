import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pacer/supabase.dart';
import 'package:pacer/src/challenge/challenge_model.dart';

/// Backend-only challenge flow (DFD process 3.0 CHALLENGE). No widgets.
///
/// Reads public.challenge (RLS: all authenticated) and writes only the caller's
/// own partisipasi_challenge rows; challenge-table writes stay coach/admin-only
/// via is_coach_or_admin(), never through app-held secrets.
class ChallengeRepository {
  final SupabaseClient _client;

  ChallengeRepository({SupabaseClient? client}) : _client = client ?? supa;

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('No signed-in user.');
    return id;
  }

  /// Lists all challenges, newest first (RLS: readable by all authenticated).
  Future<List<Challenge>> listChallenges() async {
    final rows = await _client
        .from('challenge')
        .select()
        .order('created_at', ascending: false);
    return [
      for (final row in rows)
        Challenge.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Joins a challenge; idempotent — returns the existing row if already joined.
  Future<PartisipasiChallenge> joinChallenge(String challengeId) async {
    final userId = _requireUserId();
    final existing = await _client
        .from('partisipasi_challenge')
        .select()
        .eq('user_id', userId)
        .eq('challenge_id', challengeId)
        .maybeSingle();
    if (existing != null) {
      return PartisipasiChallenge.fromJson(Map<String, dynamic>.from(existing));
    }
    final row = await _client
        .from('partisipasi_challenge')
        .insert({'user_id': userId, 'challenge_id': challengeId})
        .select()
        .single();
    return PartisipasiChallenge.fromJson(Map<String, dynamic>.from(row));
  }

  /// Leaves a challenge by deleting the caller's own participation row.
  Future<void> leaveChallenge(String challengeId) async {
    await _client
        .from('partisipasi_challenge')
        .delete()
        .eq('user_id', _requireUserId())
        .eq('challenge_id', challengeId);
  }

  /// The caller's own participation rows, newest first (RLS: own or coach-read-all).
  Future<List<PartisipasiChallenge>> myParticipations() async {
    final rows = await _client
        .from('partisipasi_challenge')
        .select()
        .eq('user_id', _requireUserId())
        .order('created_at', ascending: false);
    return [
      for (final row in rows)
        PartisipasiChallenge.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Coach read: every participation in one challenge, newest first.
  /// Legal under partisipasi_select (coach read-all); students see own only.
  Future<List<PartisipasiChallenge>> participationsForChallenge(
    String challengeId,
  ) async {
    final rows = await _client
        .from('partisipasi_challenge')
        .select()
        .eq('challenge_id', challengeId)
        .order('created_at', ascending: false);
    return [
      for (final row in rows)
        PartisipasiChallenge.fromJson(Map<String, dynamic>.from(row)),
    ];
  }
}
