/// Domain model for the in-development team chat.
/// Mirrors public.chat_messages (migration 20261011000000_pacer_chat.sql).
library;

/// One channel message (public.chat_messages). Append-only by design:
/// no update/delete policies exist server-side.
class ChatMessage {
  final String id;
  final String teamId;
  final String userId;
  final String userNama;
  final String body;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.teamId,
    required this.userId,
    this.userNama = '',
    required this.body,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final nested = json['users'];
    final candidate = nested is Map
        ? nested['nama']
        : (nested is List && nested.isNotEmpty
              ? (nested.first as Map)['nama']
              : null);
    return ChatMessage(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      userId: json['user_id'] as String,
      userNama: candidate is String ? candidate : '',
      body: json['body'] as String,
      createdAt: _parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'team_id': teamId,
    'user_id': userId,
    'body': body,
    'created_at': createdAt?.toUtc().toIso8601String(),
  };
}

/// Client mirror of the DB body guard (1..1000 chars): fail fast locally.
bool isSendableBody(String body) {
  final trimmed = body.trim();
  return trimmed.isNotEmpty && trimmed.length <= 1000;
}

DateTime? _parseDate(dynamic value) =>
    value == null ? null : DateTime.parse(value as String);
