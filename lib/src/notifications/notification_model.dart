/// In-app member notification row (public.user_notifications).
class AppNotification {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final String? challengeId;
  final String? teamId;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.challengeId,
    this.teamId,
    this.isRead = false,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        userId: json['user_id'] as String? ?? '',
        type: json['type'] as String? ?? 'team_challenge_assigned',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        challengeId: json['challenge_id'] as String?,
        teamId: json['team_id'] as String?,
        isRead: json['is_read'] is int
            ? (json['is_read'] as int) == 1
            : (json['is_read'] as bool? ?? false),
        createdAt: json['created_at'] == null
            ? null
            : DateTime.tryParse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'type': type,
    'title': title,
    'body': body,
    'challenge_id': challengeId,
    'team_id': teamId,
    'is_read': isRead,
    'created_at': createdAt?.toUtc().toIso8601String(),
  };

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    userId: userId,
    type: type,
    title: title,
    body: body,
    challengeId: challengeId,
    teamId: teamId,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );
}
