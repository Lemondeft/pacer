import 'package:uuid/uuid.dart';

import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/auth/user_model.dart';
import 'package:pacer/src/challenge/challenge_model.dart';
import 'package:pacer/src/chat/chat_model.dart';
import 'package:pacer/src/leaderboard/leaderboard_model.dart';
import 'package:pacer/src/local/local_helpers.dart';
import 'package:pacer/src/local/local_models.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/teams/team_model.dart';

/// In-memory [LocalStore] fallback used before disk initialization and in
/// widget tests that pump screens without opening SQLite.
class MemoryLocalStore implements LocalStore {
  String? _lastUserId;
  final Map<String, DateTime> _syncMeta = {};
  final Map<String, UserProfile> _profiles = {};
  final Map<String, String> _languages = {};
  final Map<String, String> _emails = {};
  final Map<String, LocalActivity> _activities = {};
  final Map<String, List<RutePoint>> _routes = {};
  final Map<String, ({double jarakM, int waktuS})> _stats = {};
  final Map<String, ({int berjalan, DateTime? terakhir})> _streaks = {};
  final Map<String, Map<String, ({Team team, bool isMine})>> _teams = {};
  final Map<String, List<({String userId, String nama, String peran, String appPeran})>>
  _rosters = {};
  final Map<String, List<LocalCoachRow>> _coachRows = {};
  final Map<String, List<Challenge>> _challenges = {};
  final Map<String, Map<String, PartisipasiChallenge>> _participations = {};
  final Map<String, List<Leaderboard>> _leaderboards = {};
  final Map<String, List<({Peringkat entry, String nama})>> _lbEntries = {};
  final Map<String, Set<String>> _lbScopes = {};
  final Map<String, Map<String, LocalChatMessage>> _chats = {};
  final List<OutboxItem> _outbox = [];
  int _nextOutboxId = 1;

  @override
  Future<void> close() async {}

  @override
  Future<String?> getLastUserId() async => _lastUserId;

  @override
  Future<void> setLastUserId(String? userId) async {
    _lastUserId = userId;
  }

  @override
  Future<void> setSyncTimestamp(String key, DateTime at) async {
    _syncMeta[key] = at;
  }

  @override
  Future<DateTime?> getSyncTimestamp(String key) async => _syncMeta[key];

  @override
  Future<UserProfile?> getProfile(String userId) async => _profiles[userId];

  @override
  Future<String?> getLanguage(String userId) async => _languages[userId];

  @override
  Future<String?> getEmail(String userId) async => _emails[userId];

  @override
  Future<void> upsertProfile(
    UserProfile profile, {
    String? language,
    String? email,
  }) async {
    _profiles[profile.id] = profile;
    if (language != null) _languages[profile.id] = language;
    if (email != null) _emails[profile.id] = email;
  }

  @override
  Future<void> queueProfileUpdate(
    String userId,
    Map<String, dynamic> patch,
  ) async {
    _profiles[userId] = applyProfilePatch(_profiles[userId], userId, patch);
    final idx = _outbox.indexWhere(
      (o) =>
          o.userId == userId &&
          o.opType == OutboxOp.updateProfile &&
          o.status == SyncState.pending,
    );
    if (idx >= 0) {
      final merged = {..._outbox[idx].payload, ...patch};
      final old = _outbox[idx];
      _outbox[idx] = OutboxItem(
        id: old.id,
        userId: userId,
        opType: old.opType,
        entityId: old.entityId,
        payload: merged,
        status: SyncState.pending,
        attempts: 0,
        nextRetryAt: null,
        lastError: null,
        createdAt: old.createdAt,
      );
      return;
    }
    _enqueue(
      userId: userId,
      opType: OutboxOp.updateProfile,
      entityId: userId,
      payload: Map<String, dynamic>.from(patch),
    );
  }

  @override
  Future<void> queueLanguageUpdate(String userId, String langCode) async {
    _languages[userId] = langCode;
    _outbox.removeWhere(
      (o) =>
          o.userId == userId &&
          o.opType == OutboxOp.updateLanguage &&
          o.status == SyncState.pending,
    );
    _enqueue(
      userId: userId,
      opType: OutboxOp.updateLanguage,
      entityId: userId,
      payload: {'language': langCode},
    );
  }

  @override
  Future<void> saveDraftStart({
    required String id,
    required String userId,
    required String jenis,
    required DateTime mulaiAt,
  }) async {
    _activities[id] = LocalActivity(
      activity: Activity(
        id: id,
        userId: userId,
        jenis: jenis,
        mulaiAt: mulaiAt,
        durasiS: 0,
        jarakM: 0,
      ),
      status: RunStatus.draft,
      syncState: SyncState.pending,
      updatedAt: DateTime.now().toUtc(),
    );
    _routes[id] = [];
  }

  @override
  Future<void> checkpointDraft({
    required String id,
    required int elapsedS,
    required double distanceM,
    required List<RutePoint> newPoints,
  }) async {
    final existing = _activities[id];
    if (existing == null || existing.status != RunStatus.draft) return;
    _activities[id] = LocalActivity(
      activity: Activity(
        id: id,
        userId: existing.activity.userId,
        jenis: existing.activity.jenis,
        mulaiAt: existing.activity.mulaiAt,
        durasiS: elapsedS,
        jarakM: distanceM,
      ),
      status: RunStatus.draft,
      syncState: SyncState.pending,
      updatedAt: DateTime.now().toUtc(),
    );
    if (newPoints.isNotEmpty) {
      final list = List<RutePoint>.from(_routes[id] ?? const []);
      for (final p in newPoints) {
        final existingIdx = list.indexWhere((e) => e.urutan == p.urutan);
        if (existingIdx >= 0) {
          list[existingIdx] = p;
        } else {
          list.add(p);
        }
      }
      _routes[id] = list..sort((a, b) => a.urutan.compareTo(b.urutan));
    }
  }

  @override
  Future<ActiveDraftRun?> loadActiveDraft(String userId) async {
    final drafts =
        _activities.values
            .where(
              (a) =>
                  a.activity.userId == userId && a.status == RunStatus.draft,
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (drafts.isEmpty) return null;
    final item = drafts.first;
    final pts = List<RutePoint>.from(_routes[item.activity.id] ?? const []);
    return ActiveDraftRun(
      id: item.activity.id,
      userId: userId,
      jenis: item.activity.jenis,
      mulaiAt: item.activity.mulaiAt ?? DateTime.now().toUtc(),
      elapsedS: item.activity.durasiS ?? 0,
      distanceM: item.activity.jarakM ?? 0,
      points: pts,
    );
  }

  @override
  Future<void> discardDraft(String id) async {
    _activities.remove(id);
    _routes.remove(id);
    _outbox.removeWhere(
      (o) => o.opType == OutboxOp.syncActivity && o.entityId == id,
    );
  }

  @override
  Future<Activity> finalizeRunAtomic({
    required String id,
    required String userId,
    required String jenis,
    required DateTime mulaiAt,
    required DateTime selesaiAt,
    required int durasiS,
    required double jarakM,
    required List<RutePoint> allPoints,
  }) async {
    final activity = Activity(
      id: id,
      userId: userId,
      jenis: jenis,
      mulaiAt: mulaiAt.toUtc(),
      selesaiAt: selesaiAt.toUtc(),
      durasiS: durasiS,
      jarakM: jarakM,
    );
    _activities[id] = LocalActivity(
      activity: activity,
      status: RunStatus.finished,
      syncState: SyncState.pending,
      statistikApplied: false,
      updatedAt: DateTime.now().toUtc(),
    );
    _routes[id] = List<RutePoint>.from(allPoints);
    _outbox.removeWhere(
      (o) => o.opType == OutboxOp.syncActivity && o.entityId == id,
    );
    _enqueue(
      userId: userId,
      opType: OutboxOp.syncActivity,
      entityId: id,
      payload: activity.toJson(),
    );
    return activity;
  }

  @override
  Future<List<LocalActivity>> listActivities(
    String userId, {
    int limit = 50,
  }) async {
    final list =
        _activities.values
            .where(
              (a) =>
                  a.activity.userId == userId && a.status == RunStatus.finished,
            )
            .toList()
          ..sort((a, b) {
            final am = a.activity.mulaiAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bm = b.activity.mulaiAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bm.compareTo(am);
          });
    if (list.length <= limit) return list;
    return list.sublist(0, limit);
  }

  @override
  Future<void> mergeRemoteActivities(
    String userId,
    List<Activity> remote,
  ) async {
    for (final a in remote) {
      final existing = _activities[a.id];
      if (existing != null &&
          (existing.syncState != SyncState.synced ||
              existing.status == RunStatus.draft)) {
        continue;
      }
      _activities[a.id] = LocalActivity(
        activity: a,
        status: a.selesaiAt == null && existing?.status == RunStatus.draft
            ? RunStatus.draft
            : RunStatus.finished,
        syncState: SyncState.synced,
        statistikApplied: true,
        updatedAt: DateTime.now().toUtc(),
      );
    }
  }

  @override
  Future<void> deleteActivityLocal(String id) async {
    _activities.remove(id);
    _routes.remove(id);
    _outbox.removeWhere(
      (o) => o.opType == OutboxOp.syncActivity && o.entityId == id,
    );
  }

  @override
  Future<List<RutePoint>> getRoutePoints(String aktivitasId) async =>
      List<RutePoint>.from(_routes[aktivitasId] ?? const []);

  @override
  Future<void> saveRoutePoints(
    String aktivitasId,
    List<RutePoint> points,
  ) async {
    _routes[aktivitasId] = List<RutePoint>.from(points);
  }

  @override
  Future<void> saveStatistikBaseline(
    String userId,
    String periode,
    double jarakM,
    int waktuS,
  ) async {
    _stats['${userId}_$periode'] = (jarakM: jarakM, waktuS: waktuS);
  }

  @override
  Future<({double jarakM, int waktuS})?> getStatistikEffective(
    String userId,
    String periode,
  ) async {
    return computeEffectiveStatistik(
      baseline: _stats['${userId}_$periode'],
      activities: _activities.values
          .where((a) => a.activity.userId == userId)
          .toList(),
      periode: periode,
    );
  }

  @override
  Future<void> saveStreakBaseline(
    String userId,
    int berjalan,
    DateTime? terakhir,
  ) async {
    _streaks[userId] = (berjalan: berjalan, terakhir: terakhir);
  }

  @override
  Future<({int berjalan, DateTime? terakhir})?> getStreakEffective(
    String userId,
  ) async {
    return computeEffectiveStreak(
      baseline: _streaks[userId],
      activities: _activities.values
          .where((a) => a.activity.userId == userId)
          .toList(),
    );
  }

  @override
  Future<void> saveTeams(
    String userId,
    List<Team> teams, {
    required bool isMine,
  }) async {
    final map = _teams.putIfAbsent(userId, () => {});
    if (isMine) {
      final mineIds = teams.map((t) => t.id).toSet();
      for (final entry in map.entries.toList()) {
        if (!mineIds.contains(entry.key) && entry.value.isMine) {
          map[entry.key] = (team: entry.value.team, isMine: false);
        }
      }
    }
    for (final t in teams) {
      final prevMine = map[t.id]?.isMine ?? false;
      map[t.id] = (team: t, isMine: isMine || prevMine);
    }
  }

  @override
  Future<List<Team>> getTeams(String userId, {bool mineOnly = false}) async {
    final entries = (_teams[userId]?.values ?? const [])
        .where((e) => !mineOnly || e.isMine)
        .map((e) => e.team)
        .toList()
      ..sort(
        (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
          a.createdAt ?? DateTime(0),
        ),
      );
    return entries;
  }

  @override
  Future<Team?> getTeam(String userId, String teamId) async =>
      _teams[userId]?[teamId]?.team;

  @override
  Future<void> saveTeamRoster(
    String userId,
    String teamId,
    List<({String userId, String nama, String peran, String appPeran})> roster,
  ) async {
    _rosters['${userId}_$teamId'] = List.of(roster);
  }

  @override
  Future<List<({String userId, String nama, String peran, String appPeran})>>
  getTeamRoster(String userId, String teamId) async =>
      List.of(_rosters['${userId}_$teamId'] ?? const []);

  @override
  Future<void> saveCoachRows(
    String userId,
    String teamId,
    String? challengeId,
    List<LocalCoachRow> rows,
  ) async {
    _coachRows['${userId}_${teamId}_${challengeId ?? ''}'] = List.of(rows);
  }

  @override
  Future<List<LocalCoachRow>?> getCoachRows(
    String userId,
    String teamId,
    String? challengeId,
  ) async {
    final hit = _coachRows['${userId}_${teamId}_${challengeId ?? ''}'];
    return hit == null ? null : List.of(hit);
  }

  @override
  Future<void> saveChallenges(String userId, List<Challenge> challenges) async {
    _challenges[userId] = List.of(challenges);
  }

  @override
  Future<List<Challenge>> getChallenges(String userId) async =>
      List.of(_challenges[userId] ?? const []);

  @override
  Future<void> saveParticipations(
    String userId,
    List<PartisipasiChallenge> list,
  ) async {
    final map = <String, PartisipasiChallenge>{
      for (final p in list) p.challengeId: p,
    };
    for (final o in _outbox) {
      if (o.userId != userId) continue;
      if (o.opType == OutboxOp.joinChallenge) {
        map.putIfAbsent(
          o.entityId,
          () => PartisipasiChallenge(
            id: o.payload['id'] as String? ?? o.entityId,
            challengeId: o.entityId,
            userId: userId,
            createdAt: o.createdAt,
          ),
        );
      } else if (o.opType == OutboxOp.leaveChallenge) {
        map.remove(o.entityId);
      }
    }
    _participations[userId] = map;
  }

  @override
  Future<List<PartisipasiChallenge>> getParticipations(String userId) async =>
      (_participations[userId]?.values.toList() ?? const [])
        ..sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );

  @override
  Future<PartisipasiChallenge> queueJoinChallenge(
    String userId,
    String challengeId,
  ) async {
    final p = PartisipasiChallenge(
      id: const Uuid().v4(),
      challengeId: challengeId,
      userId: userId,
      createdAt: DateTime.now().toUtc(),
    );
    _participations.putIfAbsent(userId, () => {})[challengeId] = p;
    _outbox.removeWhere(
      (o) =>
          o.userId == userId &&
          (o.opType == OutboxOp.leaveChallenge ||
              o.opType == OutboxOp.joinChallenge) &&
          o.entityId == challengeId &&
          o.status == SyncState.pending,
    );
    _enqueue(
      userId: userId,
      opType: OutboxOp.joinChallenge,
      entityId: challengeId,
      payload: {'id': p.id, 'challenge_id': challengeId},
    );
    return p;
  }

  @override
  Future<void> queueLeaveChallenge(String userId, String challengeId) async {
    _participations[userId]?.remove(challengeId);
    final hadPendingJoin = _outbox.any(
      (o) =>
          o.userId == userId &&
          o.opType == OutboxOp.joinChallenge &&
          o.entityId == challengeId &&
          o.status == SyncState.pending,
    );
    _outbox.removeWhere(
      (o) =>
          o.userId == userId &&
          (o.opType == OutboxOp.joinChallenge ||
              o.opType == OutboxOp.leaveChallenge) &&
          o.entityId == challengeId &&
          o.status == SyncState.pending,
    );
    if (!hadPendingJoin) {
      _enqueue(
        userId: userId,
        opType: OutboxOp.leaveChallenge,
        entityId: challengeId,
        payload: {'challenge_id': challengeId},
      );
    }
  }

  @override
  Future<void> saveLeaderboards(
    String userId,
    List<Leaderboard> boards,
  ) async {
    _leaderboards[userId] = List.of(boards);
  }

  @override
  Future<List<Leaderboard>> getLeaderboards(String userId) async =>
      List.of(_leaderboards[userId] ?? const []);

  @override
  Future<void> saveLeaderboardEntries(
    String userId,
    String leaderboardId,
    List<({Peringkat entry, String nama})> entries,
  ) async {
    _lbEntries['${userId}_$leaderboardId'] = List.of(entries);
  }

  @override
  Future<List<({Peringkat entry, String nama})>> getLeaderboardEntries(
    String userId,
    String leaderboardId,
  ) async => List.of(_lbEntries['${userId}_$leaderboardId'] ?? const []);

  @override
  Future<void> saveLeaderboardScope(
    String userId,
    String scope,
    Set<String> userIds,
  ) async {
    _lbScopes['${userId}_$scope'] = Set.of(userIds);
  }

  @override
  Future<Set<String>?> getLeaderboardScope(String userId, String scope) async {
    final hit = _lbScopes['${userId}_$scope'];
    return hit == null ? null : Set.of(hit);
  }

  @override
  Future<void> mergeChatMessages(
    String userId,
    String teamId,
    List<ChatMessage> remote,
  ) async {
    final key = '${userId}_$teamId';
    final map = _chats.putIfAbsent(key, () => {});
    for (final m in remote) {
      map[m.id] = LocalChatMessage(message: m, syncState: SyncState.synced);
    }
  }

  @override
  Future<List<LocalChatMessage>> getChatMessages(
    String userId,
    String teamId, {
    int limit = 100,
  }) async {
    final list = (_chats['${userId}_$teamId']?.values.toList() ?? const [])
      ..sort(
        (a, b) => (a.message.createdAt ?? DateTime(0)).compareTo(
          b.message.createdAt ?? DateTime(0),
        ),
      );
    if (list.length <= limit) return list;
    return list.sublist(list.length - limit);
  }

  @override
  Future<LocalChatMessage> queueChatMessage({
    required String id,
    required String teamId,
    required String userId,
    required String userNama,
    required String body,
    DateTime? createdAt,
  }) async {
    final msg = LocalChatMessage(
      message: ChatMessage(
        id: id,
        teamId: teamId,
        userId: userId,
        userNama: userNama,
        body: body.trim(),
        createdAt: (createdAt ?? DateTime.now()).toUtc(),
      ),
      syncState: SyncState.pending,
    );
    _chats.putIfAbsent('${userId}_$teamId', () => {})[id] = msg;
    _enqueue(
      userId: userId,
      opType: OutboxOp.sendChat,
      entityId: id,
      payload: {'id': id, 'team_id': teamId, 'body': body.trim()},
    );
    return msg;
  }

  @override
  Future<void> markChatMessageSynced(
    String userId,
    String tempId,
    ChatMessage serverMsg,
  ) async {
    final map = _chats['${userId}_${serverMsg.teamId}'];
    if (map != null) {
      final old = map.remove(tempId);
      map[serverMsg.id] = LocalChatMessage(
        message: ChatMessage(
          id: serverMsg.id,
          teamId: serverMsg.teamId,
          userId: serverMsg.userId,
          userNama: serverMsg.userNama.isNotEmpty
              ? serverMsg.userNama
              : (old?.message.userNama ?? ''),
          body: serverMsg.body,
          createdAt: serverMsg.createdAt,
        ),
        syncState: SyncState.synced,
      );
    }
  }

  @override
  Future<List<OutboxItem>> getDueOutboxItems(
    String userId,
    DateTime now,
  ) async {
    return _outbox
        .where(
          (o) =>
              o.userId == userId &&
              o.status == SyncState.pending &&
              (o.nextRetryAt == null || !o.nextRetryAt!.isAfter(now)),
        )
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  @override
  Future<List<OutboxItem>> getAllOutboxItems(String userId) async =>
      _outbox.where((o) => o.userId == userId).toList()
        ..sort((a, b) => a.id.compareTo(b.id));

  @override
  Future<int> getPendingOutboxCount(String userId) async => _outbox
      .where((o) => o.userId == userId && o.status != SyncState.synced)
      .length;

  @override
  Future<void> markOutboxSynced(
    int outboxId, {
    String? syncedActivityId,
    String? periode,
    double? baselineJarakM,
    int? baselineWaktuS,
    int? baselineStreak,
    DateTime? baselineStreakLast,
    bool markStatistikAppliedOnly = false,
    double? deltaJarakM,
    int? deltaWaktuS,
  }) async {
    final idx = _outbox.indexWhere((o) => o.id == outboxId);
    final item = idx >= 0 ? _outbox[idx] : null;
    if (syncedActivityId != null && _activities.containsKey(syncedActivityId)) {
      final old = _activities[syncedActivityId]!;
      if (markStatistikAppliedOnly) {
        _activities[syncedActivityId] = LocalActivity(
          activity: old.activity,
          status: old.status,
          syncState: SyncState.pending,
          statistikApplied: true,
          updatedAt: DateTime.now().toUtc(),
        );
        if (periode != null && item != null) {
          final key = '${item.userId}_$periode';
          final cur = _stats[key] ?? (jarakM: 0.0, waktuS: 0);
          _stats[key] = (
            jarakM: cur.jarakM + (deltaJarakM ?? 0),
            waktuS: cur.waktuS + (deltaWaktuS ?? 0),
          );
        }
        return;
      }
      _activities[syncedActivityId] = LocalActivity(
        activity: old.activity,
        status: old.status,
        syncState: SyncState.synced,
        statistikApplied: true,
        updatedAt: DateTime.now().toUtc(),
      );
      if (periode != null &&
          baselineJarakM != null &&
          baselineWaktuS != null) {
        _stats['${old.activity.userId}_$periode'] = (
          jarakM: baselineJarakM,
          waktuS: baselineWaktuS,
        );
      }
      if (baselineStreak != null) {
        _streaks[old.activity.userId] = (
          berjalan: baselineStreak,
          terakhir: baselineStreakLast,
        );
      }
    }
    if (idx >= 0) _outbox.removeAt(idx);
  }

  @override
  Future<void> markOutboxRetry(
    int outboxId, {
    required int attempts,
    required DateTime nextRetryAt,
    required String error,
  }) async {
    final idx = _outbox.indexWhere((o) => o.id == outboxId);
    if (idx < 0) return;
    final old = _outbox[idx];
    _outbox[idx] = OutboxItem(
      id: old.id,
      userId: old.userId,
      opType: old.opType,
      entityId: old.entityId,
      payload: old.payload,
      status: SyncState.pending,
      attempts: attempts,
      nextRetryAt: nextRetryAt,
      lastError: error,
      createdAt: old.createdAt,
    );
  }

  @override
  Future<void> markOutboxFailed(
    int outboxId, {
    required String error,
    String? entityActivityId,
    String? entityUserId,
    String? entityChatId,
  }) async {
    final idx = _outbox.indexWhere((o) => o.id == outboxId);
    if (idx >= 0) {
      final old = _outbox[idx];
      _outbox[idx] = OutboxItem(
        id: old.id,
        userId: old.userId,
        opType: old.opType,
        entityId: old.entityId,
        payload: old.payload,
        status: SyncState.failed,
        attempts: old.attempts + 1,
        nextRetryAt: null,
        lastError: error,
        createdAt: old.createdAt,
      );
    }
    if (entityActivityId != null && _activities.containsKey(entityActivityId)) {
      final old = _activities[entityActivityId]!;
      _activities[entityActivityId] = LocalActivity(
        activity: old.activity,
        status: old.status,
        syncState: SyncState.failed,
        statistikApplied: old.statistikApplied,
        updatedAt: DateTime.now().toUtc(),
      );
    }
    if (entityChatId != null && entityUserId != null) {
      for (final map in _chats.values) {
        if (map.containsKey(entityChatId)) {
          final old = map[entityChatId]!;
          map[entityChatId] = LocalChatMessage(
            message: old.message,
            syncState: SyncState.failed,
          );
        }
      }
    }
  }

  @override
  Future<void> retryFailedOutboxItems(String userId) async {
    for (var i = 0; i < _outbox.length; i++) {
      final o = _outbox[i];
      if (o.userId == userId && o.status == SyncState.failed) {
        _outbox[i] = OutboxItem(
          id: o.id,
          userId: o.userId,
          opType: o.opType,
          entityId: o.entityId,
          payload: o.payload,
          status: SyncState.pending,
          attempts: 0,
          nextRetryAt: null,
          lastError: null,
          createdAt: o.createdAt,
        );
        if (o.opType == OutboxOp.syncActivity &&
            _activities.containsKey(o.entityId)) {
          final old = _activities[o.entityId]!;
          _activities[o.entityId] = LocalActivity(
            activity: old.activity,
            status: old.status,
            syncState: SyncState.pending,
            statistikApplied: old.statistikApplied,
            updatedAt: DateTime.now().toUtc(),
          );
        }
      }
    }
  }

  void _enqueue({
    required String userId,
    required String opType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) {
    _outbox.add(
      OutboxItem(
        id: _nextOutboxId++,
        userId: userId,
        opType: opType,
        entityId: entityId,
        payload: payload,
        status: SyncState.pending,
        attempts: 0,
        nextRetryAt: null,
        lastError: null,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }
}
