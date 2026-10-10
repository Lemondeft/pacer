import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pacer/src/chat/chat_model.dart';
import 'package:pacer/supabase.dart';

/// In-development team chat (DFD-external). No widgets.
///
/// Reads/writes one team's channel; RLS scopes reads to members (+ coach)
/// and inserts to the caller's own rows. Broadcasts arrive via a
/// postgres_changes subscription ([watchTeam]); call [dispose] to leave.
class ChatRepository {
  final SupabaseClient _client;
  RealtimeChannel? _channel;

  ChatRepository({SupabaseClient? client}) : _client = client ?? supa;

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('No signed-in user.');
    return id;
  }

  /// Latest messages, oldest first for list rendering (capped at [limit]).
  Future<List<ChatMessage>> fetchRecent(
    String teamId, {
    int limit = 100,
  }) async {
    final rows = await _client
        .from('chat_messages')
        .select('id, team_id, user_id, body, created_at, users!inner(nama)')
        .eq('team_id', teamId)
        .order('created_at', ascending: true)
        .limit(limit);
    return [
      for (final row in rows)
        ChatMessage.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  /// Sends one message as the caller. Throws [ArgumentError] on blank or
  /// over-long bodies (mirrors the DB check before the round trip).
  Future<ChatMessage> send(String teamId, String body) async {
    if (!isSendableBody(body)) {
      throw ArgumentError.value(body, 'body', 'must be 1..1000 chars');
    }
    final row = await _client
        .from('chat_messages')
        .insert({
          'team_id': teamId,
          'user_id': _requireUserId(),
          'body': body.trim(),
        })
        .select('id, team_id, user_id, body, created_at')
        .single();
    return ChatMessage.fromJson(Map<String, dynamic>.from(row));
  }

  /// Live inserts for one team. [onMessage] fires per new row; the caller
  /// still owns de-duplication against [fetchRecent] (by id).
  void watchTeam(String teamId, void Function(ChatMessage) onMessage) {
    dispose();
    _channel = _client
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
            onMessage(
              ChatMessage.fromJson(
                Map<String, dynamic>.from(payload.newRecord),
              ),
            );
          },
        )
        .subscribe();
  }

  void dispose() {
    _channel?.unsubscribe();
    _channel = null;
  }
}
