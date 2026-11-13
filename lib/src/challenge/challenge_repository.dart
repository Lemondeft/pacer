import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pacer/src/challenge/challenge_model.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/swr_helper.dart';
import 'package:pacer/src/sync/sync_engine.dart';

/// Offline-first challenge repository (DFD process 3.0 CHALLENGE).
///
/// Challenge catalog and participations are cached locally via SWR; joining or
/// leaving a challenge writes locally first and queues outbox synchronization.
class ChallengeRepository {
  final SupabaseClient? _clientOverride;
  final LocalStore? _storeOverride;
  final SyncEngine? _syncOverride;

  ChallengeRepository({
    SupabaseClient? client,
    LocalStore? store,
    SyncEngine? sync,
  }) : _clientOverride = client,
       _storeOverride = store,
       _syncOverride = sync;

  SupabaseClient? get _client => safeSupabaseClient(_clientOverride);
  LocalStore get _store => _storeOverride ?? LocalStore.instance;
  SyncEngine get _sync => _syncOverride ?? SyncEngine.instance;

  Future<String> _requireUserId() async {
    final id = await resolveActiveUserId(client: _client, store: _store);
    if (id == null) throw StateError('No signed-in user.');
    return id;
  }

  /// Lists all challenges, newest first (offline-first SWR).
  Future<List<Challenge>> listChallenges({bool forceRefresh = false}) async {
    final userId = await _requireUserId();
    final c = _client;
    return offlineRead<List<Challenge>>(
      store: _store,
      syncKey: 'challenges_$userId',
      forceRefresh: forceRefresh,
      hasBackend: c != null && c.auth.currentUser != null,
      staleAfter: const Duration(minutes: 3),
      readLocal: () => _store.getChallenges(userId),
      fetchRemote: () async {
        final rows = await c!
            .from('challenge')
            .select()
            .order('created_at', ascending: false);
        final list = [
          for (final row in rows)
            Challenge.fromJson(Map<String, dynamic>.from(row)),
        ];
        await _store.saveChallenges(userId, list);
        return list;
      },
      writeLocal: (_) async {},
      isEmpty: (list) => list.isEmpty,
    );
  }

  /// Joins a challenge optimistically locally and queues remote outbox sync.
  Future<PartisipasiChallenge> joinChallenge(String challengeId) async {
    final userId = await _requireUserId();
    final joined = await _store.queueJoinChallenge(userId, challengeId);
    await _sync.refreshCounts(userId: userId);
    unawaited(_sync.triggerSync(userId: userId));
    return joined;
  }

  /// Leaves a challenge locally immediately and queues remote delete sync.
  Future<void> leaveChallenge(String challengeId) async {
    final userId = await _requireUserId();
    await _store.queueLeaveChallenge(userId, challengeId);
    await _sync.refreshCounts(userId: userId);
    unawaited(_sync.triggerSync(userId: userId));
  }

  /// The caller's own participation rows (remote merged with pending ops).
  Future<List<PartisipasiChallenge>> myParticipations({
    bool forceRefresh = false,
  }) async {
    final userId = await _requireUserId();
    final c = _client;
    return offlineRead<List<PartisipasiChallenge>>(
      store: _store,
      syncKey: 'challenge_parts_$userId',
      forceRefresh: forceRefresh,
      hasBackend: c != null && c.auth.currentUser != null,
      staleAfter: const Duration(minutes: 2),
      readLocal: () => _store.getParticipations(userId),
      fetchRemote: () async {
        final rows = await c!
            .from('partisipasi_challenge')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);
        final list = [
          for (final row in rows)
            PartisipasiChallenge.fromJson(Map<String, dynamic>.from(row)),
        ];
        await _store.saveParticipations(userId, list);
        return _store.getParticipations(userId);
      },
      writeLocal: (_) async {},
      isEmpty: (list) => list.isEmpty,
    );
  }

  Future<Challenge> createChallenge({
    required String jenis,
    required double targetNilai,
    required String targetSatuan,
    DateTime? waktuMulai,
    DateTime? waktuSelesai,
  }) async {
    if (targetNilai <= 0) {
      throw ArgumentError.value(targetNilai, 'targetNilai', 'must be > 0');
    }
    if (!targetSatuanOpsi.contains(targetSatuan)) {
      throw ArgumentError.value(
        targetSatuan,
        'targetSatuan',
        'must be one of $targetSatuanOpsi',
      );
    }
    final c = _client;
    if (c == null) throw StateError('No backend configured.');
    final uid = c.auth.currentUser?.id;
    if (uid == null) throw StateError('No signed-in user.');
    final row = await c
        .from('challenge')
        .insert({
          'dibuat_oleh': uid,
          'jenis': jenis,
          'target_nilai': targetNilai,
          'target_satuan': targetSatuan,
          'waktu_mulai': waktuMulai?.toUtc().toIso8601String(),
          'waktu_selesai': waktuSelesai?.toUtc().toIso8601String(),
          'diumumkan': true,
        })
        .select()
        .single();
    return Challenge.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<PartisipasiChallenge>> participationsForChallenge(
    String challengeId,
  ) async {
    final c = _client;
    if (c == null) throw StateError('No backend configured.');
    final rows = await c
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
