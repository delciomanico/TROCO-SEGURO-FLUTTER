class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type = '',
    required this.isRead,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: (json['title'] ?? json['subject'] ?? '').toString(),
      body: (json['body'] ?? json['message'] ?? json['content'] ?? '')
          .toString(),
      type: (json['type'] ?? '').toString(),
      isRead: json['isRead'] == true || json['read'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}

class NotificationsResult {
  final List<AppNotification> notifications;
  final int unreadCount;

  const NotificationsResult({
    required this.notifications,
    required this.unreadCount,
  });

  factory NotificationsResult.fromJson(
      Map<String, dynamic> json, List<dynamic> rawList) {
    final list = rawList
        .whereType<Map>()
        .map((m) => AppNotification.fromJson(m.cast<String, dynamic>()))
        .toList();
    final unread = json['unreadCount'] as int? ??
        json['unread'] as int? ??
        list.where((n) => !n.isRead).length;
    return NotificationsResult(notifications: list, unreadCount: unread);
  }
}
