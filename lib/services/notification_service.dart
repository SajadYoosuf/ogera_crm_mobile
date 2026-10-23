/// Notification service.
///
/// WHAT IT DOES:
///   Wraps:
///     GET  /notifications          — list the current user's inbox
///     POST /notifications/read-all — mark all read
///     POST /notifications/{id}/read — mark one read
///
/// BACKEND CONTRACT:
///   GET /notifications returns:
///     { items: [...], unread_count: int }
///   Each item:
///     { id, type, title, message, entity_type, entity_id, is_read, created_at }
library;

import '../core/network/api_client.dart';
import '../core/utils/formatters.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.entityType,
    this.entityId,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final String type;
  final String title;
  final String message;
  final String? entityType;
  final int? entityId;
  final bool isRead;
  final DateTime createdAt;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    type: type,
    title: title,
    message: message,
    entityType: entityType,
    entityId: entityId,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: asInt(json['id']) ?? 0,
        type: asText(json['type']) ?? '',
        title: asText(json['title']) ?? '',
        message: asText(json['message']) ?? '',
        entityType: asText(json['entity_type']),
        entityId: asInt(json['entity_id']),
        isRead: json['is_read'] == true,
        createdAt: DateTime.tryParse(asText(json['created_at']) ?? '') ??
            DateTime.now(),
      );
}

class NotificationService {
  NotificationService(this._api);

  final ApiClient _api;

  /// Fetches the notification inbox. Returns items and unread count.
  Future<({List<AppNotification> items, int unreadCount})> list({
    int skip = 0,
    int limit = 30,
  }) async {
    final data = asMap(
      await _api.get('/notifications', query: {'skip': skip, 'limit': limit}),
    );
    final items = asList(data['items'])
        .map(AppNotification.fromJson)
        .toList();
    final unreadCount = asInt(data['unread_count']) ?? 0;
    return (items: items, unreadCount: unreadCount);
  }

  /// Marks all notifications as read.
  Future<void> markAllRead() async {
    await _api.post('/notifications/read-all');
  }

  /// Marks one notification as read by id.
  Future<void> markRead(int id) async {
    await _api.post('/notifications/$id/read');
  }
}
