import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/auth/user_model.dart';
import 'package:pacer/src/challenge/challenge_model.dart';
import 'package:pacer/src/chat/chat_model.dart';
import 'package:pacer/src/leaderboard/leaderboard_model.dart';
import 'package:pacer/src/local/local_models.dart';
import 'package:pacer/src/local/memory_local_store.dart';
import 'package:pacer/src/local/store_factory_stub.dart'
    if (dart.library.io) 'package:pacer/src/local/store_factory_io.dart'
    as platform_store;
import 'package:pacer/src/teams/team_model.dart';

/// Offline-first persistence contract (SSOT across UI and repositories).
///
/// Production uses SQLite on IO platforms (`SqliteLocalStore`) and
/// `SharedPreferences`-backed storage on Web; unit and widget tests default
/// safely to [MemoryLocalStore] or an in-memory SQLite instance.
abstract class LocalStore {
  static LocalStore instance = MemoryLocalStore();

  /// Initializes the platform store on app launch without throwing.
  static Future<void> init() async {
    try {
      instance = await platform_store.openPlatformLocalStore();
    } catch (_) {
      // Keep MemoryLocalStore if disk initialization fails.
    }
  }

  Future<void> close() async {}

  // ---- Identity & Sync Meta ----
  Future<String?> getLastUserId();
  Future<void> setLastUserId(String? userId);
  Future<void> setSyncTimestamp(String key, DateTime at);
  Future<DateTime?> getSyncTimestamp(String key);

  // ---- Profiles & Preferences ----
  Future<UserProfile?> getProfile(String userId);
  Future<String?> getLanguage(String userId);
  Future<String?> getEmail(String userId);
  Future<void> upsertProfile(
    UserProfile profile, {
    String? language,
    String? email,
  });
  Future<void> queueProfileUpdate(String userId, Map<String, dynamic> patch);
  Future<void> queueLanguageUpdate(String userId, String langCode);

  // ---- Run Drafts & Atomic Activity Finalization ----
  Future<void> saveDraftStart({
    required String id,
    required String userId,
    required String jenis,
    required DateTime mulaiAt,
  });
  Future<void> checkpointDraft({
    required String id,
    required int elapsedS,
    required double distanceM,
    required List<RutePoint> newPoints,
  });
  Future<ActiveDraftRun?> loadActiveDraft(String userId);
  Future<void> discardDraft(String id);
  Future<Activity> finalizeRunAtomic({
    required String id,
    required String userId,
    required String jenis,
    required DateTime mulaiAt,
    required DateTime selesaiAt,
    required int durasiS,
    required double jarakM,
    required List<RutePoint> allPoints,
  });

  // ---- Activities, Routes, Statistik & Streaks ----
  Future<List<LocalActivity>> listActivities(String userId, {int limit = 50});
  Future<void> mergeRemoteActivities(String userId, List<Activity> remote);
  Future<void> deleteActivityLocal(String id);
  Future<List<RutePoint>> getRoutePoints(String aktivitasId);
  Future<void> saveRoutePoints(String aktivitasId, List<RutePoint> points);

  Future<void> saveStatistikBaseline(
    String userId,
    String periode,
    double jarakM,
    int waktuS,
  );
  Future<({double jarakM, int waktuS})?> getStatistikEffective(
    String userId,
    String periode,
  );
  Future<void> saveStreakBaseline(
    String userId,
    int berjalan,
    DateTime? terakhir,
  );
  Future<({int berjalan, DateTime? terakhir})?> getStreakEffective(
    String userId,
  );

  // ---- Teams & Coach Board ----
  Future<void> saveTeams(
    String userId,
    List<Team> teams, {
    required bool isMine,
  });
  Future<List<Team>> getTeams(String userId, {bool mineOnly = false});
  Future<Team?> getTeam(String userId, String teamId);
  Future<void> saveTeamRoster(
    String userId,
    String teamId,
    List<({String userId, String nama, String peran, String appPeran})> roster,
  );
  Future<List<({String userId, String nama, String peran, String appPeran})>>
  getTeamRoster(String userId, String teamId);
  Future<void> saveCoachRows(
    String userId,
    String teamId,
    String? challengeId,
    List<LocalCoachRow> rows,
  );
  Future<List<LocalCoachRow>?> getCoachRows(
    String userId,
    String teamId,
    String? challengeId,
  );

  // ---- Challenges & Participations ----
  Future<void> saveChallenges(String userId, List<Challenge> challenges);
  Future<List<Challenge>> getChallenges(String userId);
  Future<void> saveParticipations(
    String userId,
    List<PartisipasiChallenge> list,
  );
  Future<List<PartisipasiChallenge>> getParticipations(String userId);
  Future<PartisipasiChallenge> queueJoinChallenge(
    String userId,
    String challengeId,
  );
  Future<void> queueLeaveChallenge(String userId, String challengeId);
  Future<void> applySyncedActivityChallengeDelta(
    String userId,
    Activity activity,
  );

  // ---- Leaderboards ----
  Future<void> saveLeaderboards(String userId, List<Leaderboard> boards);
  Future<List<Leaderboard>> getLeaderboards(String userId);
  Future<void> saveLeaderboardEntries(
    String userId,
    String leaderboardId,
    List<({Peringkat entry, String nama})> entries,
  );
  Future<List<({Peringkat entry, String nama})>> getLeaderboardEntries(
    String userId,
    String leaderboardId,
  );
  Future<void> saveLeaderboardScope(
    String userId,
    String scope,
    Set<String> userIds,
  );
  Future<Set<String>?> getLeaderboardScope(String userId, String scope);

  // ---- Team Chat ----
  Future<void> mergeChatMessages(
    String userId,
    String teamId,
    List<ChatMessage> remote,
  );
  Future<List<LocalChatMessage>> getChatMessages(
    String userId,
    String teamId, {
    int limit = 100,
  });
  Future<LocalChatMessage> queueChatMessage({
    required String id,
    required String teamId,
    required String userId,
    required String userNama,
    required String body,
    DateTime? createdAt,
  });
  Future<void> markChatMessageSynced(
    String userId,
    String tempId,
    ChatMessage serverMsg,
  );

  // ---- Outbox ----
  Future<List<OutboxItem>> getDueOutboxItems(String userId, DateTime now);
  Future<List<OutboxItem>> getAllOutboxItems(String userId);
  Future<int> getPendingOutboxCount(String userId);
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
  });
  Future<void> markOutboxRetry(
    int outboxId, {
    required int attempts,
    required DateTime nextRetryAt,
    required String error,
  });
  Future<void> markOutboxFailed(
    int outboxId, {
    required String error,
    String? entityActivityId,
    String? entityUserId,
    String? entityChatId,
  });
  Future<void> retryFailedOutboxItems(String userId);
}
