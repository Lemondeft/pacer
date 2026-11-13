import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:pacer/src/chat/chat_model.dart';
import 'package:pacer/src/local/local_models.dart';
import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/swr_helper.dart';
import 'package:pacer/src/sync/connectivity_service.dart';
import 'package:pacer/src/sync/sync_engine.dart';

/// Offline-first team chat repository.
///
/// Caches recent messages per team locally and queues outbound messages via
/// client UUIDs so chats can be composed offline and delivered on reconnect.
class ChatRepository {
  final SupabaseClient? _clientOverride;
  final LocalStore? _storeOverride;
  final SyncEngine? _syncOverride;
  RealtimeChannel? _channel;

  ChatRepository({
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

  /// Latest messages including locally queued pending messages (oldest first).
  Future<List<LocalChatMessage>> fetchRecentLocal(
    String teamId, {
    int limit = 100,
    bool forceRefresh = false,
  }) async {
    final userId = await _requireUserId();
    final c = _client;
    return offlineRead<List<LocalChatMessage>>(
      store: _store,
      syncKey: 'chat_${userId}_$teamId',
      forceRefresh: forceRefresh,
      hasBackend: c != null && c.auth.currentUser != null,
      staleAfter: const Duration(seconds: 20),
      readLocal: () => _store.getChatMessages(userId, teamId, limit: limit),
      fetchRemote: () async {
        final rows = await c!
            .from('chat_messages')
            .select('id, team_id, user_id, body, created_at, users!inner(nama)')
            .eq('team_id', teamId)
            .order('created_at', ascending: true)
            .limit(limit);
        final list = [
          for (final row in rows)
            ChatMessage.fromJson(Map<String, dynamic>.from(row as Map)),
        ];
        await _store.mergeChatMessages(userId, teamId, list);
        return _store.getChatMessages(userId, teamId, limit: limit);
      },
      writeLocal: (_) async {},
      isEmpty: (list) => list.isEmpty,
    );
  }

  Future<List<ChatMessage>> fetchRecent(
    String teamId, {
    int limit = 100,
    bool forceRefresh = false,
  }) async {
    final list = await fetchRecentLocal(
      teamId,
      limit: limit,
      forceRefresh: forceRefresh,
    );
    return [for (final m in list) m.message];
  }

  /// Writes message optimistically into local storage and queues outbox sync.
  Future<LocalChatMessage> sendLocal(
    String teamId,
    String body, {
    String userNama = '',
  }) async {
    if (!isSendableBody(body)) {
      throw ArgumentError.value(body, 'body', 'must be 1..1000 chars');
    }
    final userId = await _requireUserId();
    final id = const Uuid().v4();
    final profile = await _store.getProfile(userId);
    final resolvedName = userNama.isNotEmpty
        ? userNama
        : (profile?.nama ?? '');
    final localMsg = await _store.queueChatMessage(
      id: id,
      teamId: teamId,
      userId: userId,
      userNama: resolvedName,
      body: body.trim(),
    );
    await _sync.refreshCounts(userId: userId);
    unawaited(_sync.triggerSync(userId: userId));
    return localMsg;
  }

  Future<ChatMessage> send(String teamId, String body) async {
    final msg = await sendLocal(teamId, body);
    return msg.message;
  }

  /// Live inserts for one team when connected; safely no-ops offline.
  void watchTeam(String teamId, void Function(ChatMessage) onMessage) {
    dispose();
    final c = _client;
    if (c == null ||
        c.auth.currentUser == null ||
        !ConnectivityService.instance.value) {
      return;
    }
    final ownerId = c.auth.currentUser!.id;
    _channel = c
        .channel('chat:$teamId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'team_id',
            value: teamId,
          ),
          callback: (payload) {
            final msg = ChatMessage.fromJson(
              Map<String, dynamic>.from(payload.newRecord),
            );
            unawaited(_store.mergeChatMessages(ownerId, teamId, [msg]));
            onMessage(msg);
          },
        )
        .subscribe();
  }

  void dispose() {
    _channel?.unsubscribe();
    _channel = null;
  }
}
