import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/cache/pacer_cache.dart';
import 'package:pacer/src/challenge/challenge_model.dart';
import 'package:pacer/src/chat/chat_model.dart';
import 'package:pacer/src/local/local_models.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/sync/connectivity_service.dart';
import 'package:pacer/supabase.dart';

/// Immutable snapshot of offline/sync health shown to UI consumers.
class SyncStatus {
  final bool isOnline;
  final bool isSyncing;
  final bool needsReauth;
  final int pendingCount;
  final int failedCount;
  final DateTime? lastSyncedAt;
  final String? lastError;

  const SyncStatus({
    this.isOnline = true,
    this.isSyncing = false,
    this.needsReauth = false,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastSyncedAt,
    this.lastError,
  });

  bool get hasPendingWork => pendingCount > 0 || failedCount > 0;

  SyncStatus copyWith({
    bool? isOnline,
    bool? isSyncing,
    bool? needsReauth,
    int? pendingCount,
    int? failedCount,
    DateTime? lastSyncedAt,
    String? lastError,
    bool clearError = false,
  }) => SyncStatus(
    isOnline: isOnline ?? this.isOnline,
    isSyncing: isSyncing ?? this.isSyncing,
    needsReauth: needsReauth ?? this.needsReauth,
    pendingCount: pendingCount ?? this.pendingCount,
    failedCount: failedCount ?? this.failedCount,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    lastError: clearError ? null : (lastError ?? this.lastError),
  );
}

/// Abstract remote target for [SyncEngine] outbox draining so tests can mock
/// failures cleanly without touching live Supabase endpoints.
abstract class RemoteSyncGateway {
  String? get currentUserId;
  Future<bool> ensureValidSession();
  Future<void> upsertActivity(Activity activity);
  Future<void> upsertRoutePoints(String aktivitasId, List<RutePoint> points);
  Future<
    ({
      double jarakM,
      int waktuS,
      int streakBerjalan,
      DateTime? streakLast,
    })?
  >
  recomputeStatsRpc({
    required String periode,
    required DateTime weekStartUtc,
    required DateTime weekEndUtc,
    required String activityDay,
  });
  Future<void> fallbackApplyStatistikAndStreak({
    required String periode,
    required double jarakM,
    required int waktuS,
    required DateTime activityLocalDate,
  });
  Future<void> updateProfile(String userId, Map<String, dynamic> patch);
  Future<void> updateLanguage(String userId, String langCode);
  Future<void> joinChallenge(
    String userId,
    String challengeId, {
    String? id,
    DateTime? createdAt,
  });
  Future<void> leaveChallenge(String userId, String challengeId);
  Future<List<PartisipasiChallenge>?> recomputeChallengeProgressRpc();
  Future<List<PartisipasiChallenge>> fallbackSyncChallengeProgress(String userId);
  Future<ChatMessage> sendChatMessage({
    required String id,
    required String teamId,
    required String userId,
    required String body,
  });
}

/// Default Supabase implementation of [RemoteSyncGateway].
class SupabaseSyncGateway implements RemoteSyncGateway {
  final SupabaseClient? _clientOverride;

  const SupabaseSyncGateway([this._clientOverride]);

  SupabaseClient? get _client {
    if (_clientOverride != null) return _clientOverride;
    try {
      return supa;
    } catch (_) {
      return null;
    }
  }

  @override
  String? get currentUserId => _client?.auth.currentUser?.id;

  @override
  Future<bool> ensureValidSession() async {
    final c = _client;
    if (c == null) return false;
    final session = c.auth.currentSession;
    if (session == null) return false;
    final expiresAt = session.expiresAt;
    if (expiresAt != null) {
      final exp = DateTime.fromMillisecondsSinceEpoch(
        expiresAt * 1000,
        isUtc: true,
      );
      if (exp.isBefore(DateTime.now().toUtc().add(const Duration(seconds: 30)))) {
        await c.auth.refreshSession();
      }
    }
    return c.auth.currentUser != null;
  }

  @override
  Future<void> upsertActivity(Activity activity) async {
    final c = _client!;
    await c.from('aktivitas').upsert(activity.toJson(), onConflict: 'id');
  }

  @override
  Future<void> upsertRoutePoints(
    String aktivitasId,
    List<RutePoint> points,
  ) async {
    if (points.isEmpty) return;
    final c = _client!;
    const batchSize = 500;
    for (var i = 0; i < points.length; i += batchSize) {
      final end = (i + batchSize < points.length) ? i + batchSize : points.length;
      final chunk = [
        for (final pt in points.sublist(i, end))
          {...pt.toJson(), 'aktivitas_id': aktivitasId},
      ];
      await c
          .from('rute_points')
          .upsert(chunk, onConflict: 'aktivitas_id,urutan');
    }
  }

  @override
  Future<
    ({
      double jarakM,
      int waktuS,
      int streakBerjalan,
      DateTime? streakLast,
    })?
  >
  recomputeStatsRpc({
    required String periode,
    required DateTime weekStartUtc,
    required DateTime weekEndUtc,
    required String activityDay,
  }) async {
    final c = _client!;
    try {
      final raw = await c.rpc(
        'sync_recompute_user_stats',
        params: {
          'p_periode': periode,
          'p_week_start': weekStartUtc.toUtc().toIso8601String(),
          'p_week_end': weekEndUtc.toUtc().toIso8601String(),
          'p_activity_day': activityDay,
        },
      );
      final list = raw is List ? raw : [raw];
      if (list.isEmpty || list.first == null) return null;
      final row = Map<String, dynamic>.from(list.first as Map);
      final tgl = row['terakhir_olahraga_tgl'] as String?;
      return (
        jarakM: jsonToDouble(row['total_jarak_m']) ?? 0,
        waktuS: (row['total_waktu_s'] as num?)?.toInt() ?? 0,
        streakBerjalan: (row['streak_berjalan'] as num?)?.toInt() ?? 0,
        streakLast: tgl == null ? null : DateTime.parse(tgl),
      );
    } on PostgrestException catch (e) {
      final code = (e.code ?? '').toUpperCase();
      if (code == 'PGRST202' || code == '42883') {
        // Migration not applied on target Supabase yet -> allow safe fallback.
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> fallbackApplyStatistikAndStreak({
    required String periode,
    required double jarakM,
    required int waktuS,
    required DateTime activityLocalDate,
  }) async {
    final c = _client!;
    final uid = c.auth.currentUser?.id;
    if (uid == null) throw const AuthException('Not signed in');

    final existingStat = await c
        .from('statistik')
        .select('id, total_jarak_m, total_waktu_s')
        .eq('user_id', uid)
        .eq('periode', periode)
        .maybeSingle();
    if (existingStat == null) {
      await c.from('statistik').insert({
        'user_id': uid,
        'periode': periode,
        'total_jarak_m': jarakM,
        'total_waktu_s': waktuS,
      });
    } else {
      await c
          .from('statistik')
          .update({
            'total_jarak_m':
                (jsonToDouble(existingStat['total_jarak_m']) ?? 0) + jarakM,
            'total_waktu_s':
                ((existingStat['total_waktu_s'] as num?)?.toInt() ?? 0) + waktuS,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', existingStat['id'] as String);
    }

    final streakRow = await c
        .from('streak')
        .select('streak_berjalan, terakhir_olahraga_tgl')
        .eq('user_id', uid)
        .maybeSingle();
    final terakhirRaw = streakRow?['terakhir_olahraga_tgl'] as String?;
    final last = terakhirRaw == null ? null : DateTime.parse(terakhirRaw);
    final actDay = DateTime.utc(
      activityLocalDate.year,
      activityLocalDate.month,
      activityLocalDate.day,
    );
    final lastDay = last == null
        ? null
        : DateTime.utc(last.year, last.month, last.day);
    if (lastDay != null && !actDay.isAfter(lastDay)) return;

    final next = streakNext(
      terakhirTgl: last,
      today: activityLocalDate,
      current: (streakRow?['streak_berjalan'] as num?)?.toInt() ?? 0,
    );
    final dayStr =
        '${activityLocalDate.year.toString().padLeft(4, '0')}-'
        '${activityLocalDate.month.toString().padLeft(2, '0')}-'
        '${activityLocalDate.day.toString().padLeft(2, '0')}';
    final payload = {
      'streak_berjalan': next,
      'terakhir_olahraga_tgl': dayStr,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (streakRow == null) {
      await c.from('streak').insert({...payload, 'user_id': uid});
    } else {
      await c.from('streak').update(payload).eq('user_id', uid);
    }
  }

  @override
  Future<void> updateProfile(String userId, Map<String, dynamic> patch) async {
    await _client!.from('users').update(patch).eq('id', userId);
  }

  @override
  Future<void> updateLanguage(String userId, String langCode) async {
    await _client!.from('users').update({'language': langCode}).eq('id', userId);
  }

  @override
  Future<void> joinChallenge(
    String userId,
    String challengeId, {
    String? id,
    DateTime? createdAt,
  }) async {
    final c = _client!;
    final existing = await c
        .from('partisipasi_challenge')
        .select('id')
        .eq('user_id', userId)
        .eq('challenge_id', challengeId)
        .maybeSingle();
    if (existing != null) return;
    try {
      await c.from('partisipasi_challenge').insert({
        if (id != null && id.isNotEmpty) 'id': id,
        'user_id': userId,
        'challenge_id': challengeId,
        if (createdAt != null) 'created_at': createdAt.toUtc().toIso8601String(),
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
  }

  @override
  Future<void> leaveChallenge(String userId, String challengeId) async {
    await _client!
        .from('partisipasi_challenge')
        .delete()
        .eq('user_id', userId)
        .eq('challenge_id', challengeId);
  }

  @override
  Future<List<PartisipasiChallenge>?> recomputeChallengeProgressRpc() async {
    final c = _client!;
    try {
      final raw = await c.rpc('sync_recompute_challenge_progress');
      final rows = raw is List ? raw : (raw == null ? const [] : [raw]);
      return [
        for (final row in rows)
          PartisipasiChallenge.fromJson(Map<String, dynamic>.from(row as Map)),
      ];
    } on PostgrestException catch (e) {
      final code = (e.code ?? '').toUpperCase();
      if (code == 'PGRST202' || code == '42883') {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<List<PartisipasiChallenge>> fallbackSyncChallengeProgress(
    String userId,
  ) async {
    final c = _client!;
    final partRows = await c
        .from('partisipasi_challenge')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    final parts = [
      for (final row in partRows)
        PartisipasiChallenge.fromJson(Map<String, dynamic>.from(row)),
    ];
    if (parts.isEmpty) return const [];

    final chalRows = await c.from('challenge').select();
    final challenges = {
      for (final row in chalRows)
        row['id'] as String: Challenge.fromJson(Map<String, dynamic>.from(row)),
    };
    final actRows = await c
        .from('aktivitas')
        .select()
        .eq('user_id', userId)
        .not('selesai_at', 'is', null);
    final acts = [
      for (final row in actRows)
        Activity.fromJson(Map<String, dynamic>.from(row)),
    ];

    final updated = <PartisipasiChallenge>[];
    for (final p in parts) {
      final ch = challenges[p.challengeId];
      if (ch == null) {
        updated.add(p);
        continue;
      }
      final eval = evaluateChallengeProgress(
        challenge: ch,
        participation: p,
        activities: acts,
      );
      if (eval.progressNilai != p.progressNilai || eval.berhasil != p.berhasil) {
        await c
            .from('partisipasi_challenge')
            .update({
              'progress_nilai': eval.progressNilai,
              'berhasil': eval.berhasil,
            })
            .eq('id', p.id);
      }
      updated.add(eval);
    }
    return updated;
  }

  @override
  Future<ChatMessage> sendChatMessage({
    required String id,
    required String teamId,
    required String userId,
    required String body,
  }) async {
    final c = _client!;
    try {
      final row = await c
          .from('chat_messages')
          .insert({
            'id': id,
            'team_id': teamId,
            'user_id': userId,
            'body': body,
          })
          .select('id, team_id, user_id, body, created_at')
          .single();
      return ChatMessage.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        final existing = await c
            .from('chat_messages')
            .select('id, team_id, user_id, body, created_at')
            .eq('id', id)
            .single();
        return ChatMessage.fromJson(Map<String, dynamic>.from(existing));
      }
      rethrow;
    }
  }
}

/// Coordinates outbox draining across connectivity transitions, app lifecycle
/// resumes, local mutations, and explicit user refresh actions.
class SyncEngine extends ChangeNotifier {
  static final SyncEngine instance = SyncEngine();

  final LocalStore Function() _storeProvider;
  final ConnectivityService _connectivity;
  final RemoteSyncGateway _gateway;
  final DateTime Function() _now;

  SyncStatus _status = const SyncStatus();
  Future<void>? _inFlight;
  bool _rerunRequested = false;
  Timer? _retryTimer;

  SyncEngine({
    LocalStore Function()? storeProvider,
    ConnectivityService? connectivity,
    RemoteSyncGateway? gateway,
    DateTime Function()? clock,
  }) : _storeProvider = storeProvider ?? (() => LocalStore.instance),
       _connectivity = connectivity ?? ConnectivityService.instance,
       _gateway = gateway ?? const SupabaseSyncGateway(),
       _now = clock ?? DateTime.now;

  LocalStore get _store => _storeProvider();
  SyncStatus get status => _status;

  static Duration backoffForAttempt(int attempts) {
    const seconds = [5, 15, 60, 300];
    final idx = attempts.clamp(0, seconds.length - 1);
    return Duration(seconds: seconds[idx]);
  }

  /// Starts connectivity observation and syncs any pending items on boot.
  Future<void> init() async {
    await _connectivity.init(onReconnect: () => triggerSync());
    _connectivity.isOnline.removeListener(_onConnectivityChange);
    _connectivity.isOnline.addListener(_onConnectivityChange);
    await refreshCounts();
    if (_connectivity.value) {
      await triggerSync();
    }
  }

  void _onConnectivityChange() {
    final online = _connectivity.value;
    if (_status.isOnline != online) {
      _status = _status.copyWith(isOnline: online);
      notifyListeners();
    }
    if (online) {
      triggerSync();
    }
  }

  /// Refreshes outbox pending/failed counters without requiring network.
  Future<void> refreshCounts({String? userId}) async {
    final uid = userId ?? _gateway.currentUserId ?? await _store.getLastUserId();
    if (uid == null) {
      _status = SyncStatus(isOnline: _connectivity.value);
      notifyListeners();
      return;
    }
    final items = await _store.getAllOutboxItems(uid);
    final pending = items.where((o) => o.status == SyncState.pending).length;
    final failed = items.where((o) => o.status == SyncState.failed).length;
    _status = _status.copyWith(
      isOnline: _connectivity.value,
      pendingCount: pending,
      failedCount: failed,
    );
    notifyListeners();
  }

  /// Non-blocking fire-and-forget trigger safe after local writes.
  Future<void> triggerSync({String? userId, bool retryFailed = false}) {
    return syncNow(userId: userId, retryFailed: retryFailed);
  }

  /// Drains due outbox mutations serially in chronological order.
  Future<void> syncNow({String? userId, bool retryFailed = false}) async {
    if (_inFlight != null) {
      _rerunRequested = true;
      return _inFlight!;
    }
    final completer = Completer<void>();
    _inFlight = completer.future;
    try {
      do {
        _rerunRequested = false;
        await _drainOnce(userId: userId, retryFailed: retryFailed);
        retryFailed = false;
      } while (_rerunRequested);
    } finally {
      _inFlight = null;
      completer.complete();
    }
  }

  Future<void> _drainOnce({String? userId, required bool retryFailed}) async {
    final uid = userId ?? _gateway.currentUserId ?? await _store.getLastUserId();
    if (uid == null) {
      await refreshCounts(userId: null);
      return;
    }

    if (retryFailed) {
      await _store.retryFailedOutboxItems(uid);
    }

    final allBefore = await _store.getAllOutboxItems(uid);
    final due = await _store.getDueOutboxItems(uid, _now());

    if (!_connectivity.value) {
      _status = _status.copyWith(
        isOnline: false,
        isSyncing: false,
        pendingCount: allBefore.where((o) => o.status == SyncState.pending).length,
        failedCount: allBefore.where((o) => o.status == SyncState.failed).length,
      );
      notifyListeners();
      return;
    }

    if (due.isEmpty) {
      _status = _status.copyWith(
        isOnline: true,
        isSyncing: false,
        pendingCount: allBefore.where((o) => o.status == SyncState.pending).length,
        failedCount: allBefore.where((o) => o.status == SyncState.failed).length,
      );
      notifyListeners();
      return;
    }

    _status = _status.copyWith(
      isOnline: true,
      isSyncing: true,
      clearError: true,
      pendingCount: allBefore.where((o) => o.status == SyncState.pending).length,
      failedCount: allBefore.where((o) => o.status == SyncState.failed).length,
    );
    notifyListeners();

    var syncedAny = false;
    DateTime? earliestRetry;

    try {
      final sessionOk = await _gateway.ensureValidSession();
      if (!sessionOk) {
        _status = _status.copyWith(isSyncing: false, needsReauth: true);
        notifyListeners();
        return;
      }

      for (final item in due) {
        try {
          await _processItem(item);
          syncedAny = true;
          _status = _status.copyWith(
            isOnline: true,
            needsReauth: false,
            lastSyncedAt: _now(),
            clearError: true,
          );
        } catch (err) {
          if (isAuthSessionError(err)) {
            _status = _status.copyWith(
              isSyncing: false,
              needsReauth: true,
              lastError: err.toString(),
            );
            notifyListeners();
            return;
          }
          if (isTransientNetworkError(err)) {
            final attempts = item.attempts + 1;
            final delay = backoffForAttempt(item.attempts);
            final retryAt = _now().add(delay);
            if (earliestRetry == null || retryAt.isBefore(earliestRetry)) {
              earliestRetry = retryAt;
            }
            await _store.markOutboxRetry(
              item.id,
              attempts: attempts,
              nextRetryAt: retryAt,
              error: err.toString(),
            );
            _status = _status.copyWith(
              isOnline: false,
              lastError: err.toString(),
            );
            // Transport broke mid-drain; stop further calls this pass.
            break;
          }
          // Non-transient validation/RLS error -> mark failed so healthy rows proceed.
          await _store.markOutboxFailed(
            item.id,
            error: err.toString(),
            entityActivityId:
                item.opType == OutboxOp.syncActivity ? item.entityId : null,
            entityUserId: item.userId,
            entityChatId:
                item.opType == OutboxOp.sendChat ? item.entityId : null,
          );
          _status = _status.copyWith(lastError: err.toString());
        }
      }
    } catch (err) {
      if (isAuthSessionError(err)) {
        _status = _status.copyWith(needsReauth: true, lastError: err.toString());
      } else if (isTransientNetworkError(err)) {
        _status = _status.copyWith(isOnline: false, lastError: err.toString());
      } else {
        _status = _status.copyWith(lastError: err.toString());
      }
    }

    if (syncedAny) {
      PacerCache.instance.clear();
    }

    final remaining = await _store.getAllOutboxItems(uid);
    _status = _status.copyWith(
      isSyncing: false,
      pendingCount: remaining.where((o) => o.status == SyncState.pending).length,
      failedCount: remaining.where((o) => o.status == SyncState.failed).length,
    );
    _scheduleRetry(earliestRetry, uid);
    notifyListeners();
  }

  void _scheduleRetry(DateTime? retryAt, String uid) {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (retryAt == null) return;
    final delay = retryAt.difference(_now());
    final wait = delay.isNegative ? const Duration(seconds: 1) : delay;
    _retryTimer = Timer(wait, () => triggerSync(userId: uid));
  }

  Future<void> _processItem(OutboxItem item) async {
    switch (item.opType) {
      case OutboxOp.syncActivity:
        await _syncActivityItem(item);
      case OutboxOp.updateProfile:
        await _gateway.updateProfile(item.userId, item.payload);
        await _store.markOutboxSynced(item.id);
      case OutboxOp.updateLanguage:
        await _gateway.updateLanguage(
          item.userId,
          item.payload['language'] as String? ?? 'id',
        );
        await _store.markOutboxSynced(item.id);
      case OutboxOp.joinChallenge:
        final createdRaw = item.payload['created_at'] as String?;
        await _gateway.joinChallenge(
          item.userId,
          item.entityId,
          id: item.payload['id'] as String?,
          createdAt: createdRaw == null ? null : DateTime.parse(createdRaw),
        );
        await _store.markOutboxSynced(item.id);
      case OutboxOp.leaveChallenge:
        await _gateway.leaveChallenge(item.userId, item.entityId);
        await _store.markOutboxSynced(item.id);
      case OutboxOp.sendChat:
        final serverMsg = await _gateway.sendChatMessage(
          id: item.entityId,
          teamId: item.payload['team_id'] as String,
          userId: item.userId,
          body: item.payload['body'] as String,
        );
        await _store.markChatMessageSynced(
          item.userId,
          item.entityId,
          serverMsg,
        );
        await _store.markOutboxSynced(item.id);
    }
  }

  Future<void> _syncActivityItem(OutboxItem item) async {
    final activity = Activity.fromJson(item.payload);
    final points = await _store.getRoutePoints(activity.id);

    await _gateway.upsertActivity(activity);
    if (points.isNotEmpty) {
      await _gateway.upsertRoutePoints(activity.id, points);
    }

    final mulai = activity.mulaiAt ?? _now();
    final bounds = isoWeekBounds(mulai);
    final rpcResult = await _gateway.recomputeStatsRpc(
      periode: bounds.periode,
      weekStartUtc: bounds.startUtc,
      weekEndUtc: bounds.endUtc,
      activityDay: bounds.activityDay,
    );

    if (rpcResult != null) {
      await _store.markOutboxSynced(
        item.id,
        syncedActivityId: activity.id,
        periode: bounds.periode,
        baselineJarakM: rpcResult.jarakM,
        baselineWaktuS: rpcResult.waktuS,
        baselineStreak: rpcResult.streakBerjalan,
        baselineStreakLast: rpcResult.streakLast,
      );
      await _syncChallengeProgressAfterActivity(item.userId, activity);
      return;
    }

    // Fallback path when migration RPC is not deployed on the backend: check
    // local statistikApplied flag so delta add can happen at most once.
    final effStreak = await _store.getStreakEffective(item.userId);
    final localList = await _store.listActivities(item.userId, limit: 200);
    final match = localList.where((a) => a.activity.id == activity.id);
    final alreadyApplied = match.isNotEmpty && match.first.statistikApplied;
    if (!alreadyApplied) {
      await _gateway.fallbackApplyStatistikAndStreak(
        periode: bounds.periode,
        jarakM: activity.jarakM ?? 0,
        waktuS: activity.durasiS ?? 0,
        activityLocalDate: mulai.toLocal(),
      );
      await _store.markOutboxSynced(
        item.id,
        syncedActivityId: activity.id,
        periode: bounds.periode,
        markStatistikAppliedOnly: true,
        deltaJarakM: activity.jarakM ?? 0,
        deltaWaktuS: activity.durasiS ?? 0,
      );
    }
    await _store.markOutboxSynced(
      item.id,
      syncedActivityId: activity.id,
      baselineStreak: effStreak?.berjalan,
      baselineStreakLast: effStreak?.terakhir,
    );
    await _syncChallengeProgressAfterActivity(item.userId, activity);
  }

  Future<void> _syncChallengeProgressAfterActivity(
    String userId,
    Activity activity,
  ) async {
    final rpcParts = await _gateway.recomputeChallengeProgressRpc();
    if (rpcParts != null) {
      await _store.saveParticipations(userId, rpcParts);
      return;
    }
    final fallbackParts = await _gateway.fallbackSyncChallengeProgress(userId);
    if (fallbackParts.isNotEmpty) {
      await _store.saveParticipations(userId, fallbackParts);
    } else {
      await _store.applySyncedActivityChallengeDelta(userId, activity);
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _connectivity.isOnline.removeListener(_onConnectivityChange);
    super.dispose();
  }
}
