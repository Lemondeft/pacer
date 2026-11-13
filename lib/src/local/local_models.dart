import 'dart:convert';

import 'package:pacer/src/aktivitas/activity_model.dart';
import 'package:pacer/src/chat/chat_model.dart';

/// Sync lifecycle for locally persisted rows and outbox entries.
enum SyncState { synced, pending, failed }

/// Execution phase of a tracked activity in the local database.
enum RunStatus { draft, finished }

/// Operation types durable-queued in `sync_outbox`.
class OutboxOp {
  OutboxOp._();

  static const String syncActivity = 'sync_activity';
  static const String updateProfile = 'update_profile';
  static const String updateLanguage = 'update_language';
  static const String joinChallenge = 'join_challenge';
  static const String leaveChallenge = 'leave_challenge';
  static const String sendChat = 'send_chat';
}

/// Locally stored workout with lifecycle and sync state metadata.
class LocalActivity {
  final Activity activity;
  final RunStatus status;
  final SyncState syncState;
  final bool statistikApplied;
  final DateTime updatedAt;

  const LocalActivity({
    required this.activity,
    this.status = RunStatus.finished,
    this.syncState = SyncState.synced,
    this.statistikApplied = false,
    required this.updatedAt,
  });
}

/// Crash-recoverable mid-run draft persisted incrementally during tracking.
class ActiveDraftRun {
  final String id;
  final String userId;
  final String jenis;
  final DateTime mulaiAt;
  final int elapsedS;
  final double distanceM;
  final List<RutePoint> points;

  const ActiveDraftRun({
    required this.id,
    required this.userId,
    required this.jenis,
    required this.mulaiAt,
    required this.elapsedS,
    required this.distanceM,
    required this.points,
  });
}

/// Locally stored team chat message with optimistic sync badge state.
class LocalChatMessage {
  final ChatMessage message;
  final SyncState syncState;

  const LocalChatMessage({
    required this.message,
    this.syncState = SyncState.synced,
  });
}

/// Cached coach class board row for offline field inspection.
class LocalCoachRow {
  final String userId;
  final String nama;
  final int sessions;
  final double weekKm;
  final int streak;
  final double? progress;
  final bool? berhasil;

  const LocalCoachRow({
    required this.userId,
    required this.nama,
    required this.sessions,
    required this.weekKm,
    required this.streak,
    this.progress,
    this.berhasil,
  });

  factory LocalCoachRow.fromJson(Map<String, dynamic> json) => LocalCoachRow(
    userId: json['user_id'] as String? ?? '',
    nama: json['nama'] as String? ?? '',
    sessions: (json['sessions'] as num?)?.toInt() ?? 0,
    weekKm: (json['week_km'] as num?)?.toDouble() ?? 0,
    streak: (json['streak'] as num?)?.toInt() ?? 0,
    progress: (json['progress'] as num?)?.toDouble(),
    berhasil: json['berhasil'] as bool?,
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'nama': nama,
    'sessions': sessions,
    'week_km': weekKm,
    'streak': streak,
    'progress': progress,
    'berhasil': berhasil,
  };
}

/// Durable operation waiting in the offline outbox queue.
class OutboxItem {
  final int id;
  final String userId;
  final String opType;
  final String entityId;
  final Map<String, dynamic> payload;
  final SyncState status;
  final int attempts;
  final DateTime? nextRetryAt;
  final String? lastError;
  final DateTime createdAt;

  const OutboxItem({
    required this.id,
    required this.userId,
    required this.opType,
    required this.entityId,
    required this.payload,
    required this.status,
    required this.attempts,
    required this.nextRetryAt,
    required this.lastError,
    required this.createdAt,
  });

  String get encodedPayload => jsonEncode(payload);
}

/// Computes ISO week bounds matching client local date so server RPC rollups
/// stay aligned with [periodeKey].
({String periode, DateTime startUtc, DateTime endUtc, String activityDay})
isoWeekBounds(DateTime when) {
  final local = when.toLocal();
  final dayStartLocal = DateTime(local.year, local.month, local.day);
  final mondayLocal = dayStartLocal.subtract(
    Duration(days: dayStartLocal.weekday - 1),
  );
  final nextMondayLocal = mondayLocal.add(const Duration(days: 7));
  final activityDay =
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
  return (
    periode: periodeKey(local),
    startUtc: mondayLocal.toUtc(),
    endUtc: nextMondayLocal.toUtc(),
    activityDay: activityDay,
  );
}

SyncState parseSyncState(String? raw) {
  switch (raw) {
    case 'pending':
      return SyncState.pending;
    case 'failed':
      return SyncState.failed;
    case 'synced':
    default:
      return SyncState.synced;
  }
}

RunStatus parseRunStatus(String? raw) {
  switch (raw) {
    case 'draft':
      return RunStatus.draft;
    case 'finished':
    default:
      return RunStatus.finished;
  }
}
