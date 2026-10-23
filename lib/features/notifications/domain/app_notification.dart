class NotificationPageResult {
  const NotificationPageResult({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    this.totalCount,
    this.unreadCount,
  });

  factory NotificationPageResult.fromJson(Map<String, dynamic> json) {
    final meta = _map(json['meta']);
    final values = json['data'];
    if (values is! List) {
      throw const FormatException('Missing notifications list.');
    }
    final items = values
        .map((item) => AppNotification.fromJson(_map(item)))
        .toList();
    return NotificationPageResult(
      items: items,
      currentPage: _integer(
        meta['current_page'] ?? json['current_page'],
        fallback: 1,
      ),
      lastPage: _integer(meta['last_page'] ?? json['last_page'], fallback: 1),
      totalCount:
          (json['total_count'] as num?)?.toInt() ??
          (json['total'] as num?)?.toInt(),
      unreadCount: (json['unread_count'] as num?)?.toInt(),
    );
  }

  final List<AppNotification> items;
  final int currentPage;
  final int lastPage;
  final int? totalCount;
  final int? unreadCount;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.readAt,
    this.childId,
    this.childName,
    this.occurredAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final data = _map(json['data']);
    return AppNotification(
      id: '${json['id'] ?? ''}',
      childId: (data['student_id'] as num?)?.toInt(),
      childName: data['student_name'] as String?,
      occurredAt: DateTime.tryParse('${data['occurred_at'] ?? ''}'),
      type: '${data['type'] ?? json['type'] ?? 'general'}',
      title: '${data['title'] ?? json['title'] ?? 'Notification'}',
      message:
          '${data['message'] ?? json['message'] ?? 'You have a new update.'}',
      createdAt: DateTime.tryParse(
        '${json['created_at'] ?? json['occurred_at'] ?? ''}',
      ),
      readAt: DateTime.tryParse('${json['read_at'] ?? ''}'),
    );
  }

  final String id;
  final String type;
  final String title;
  final String message;
  final DateTime? createdAt;
  final DateTime? readAt;
  final int? childId;
  final String? childName;
  final DateTime? occurredAt;

  bool get isRead => readAt != null;

  AppNotification markRead() => AppNotification(
    id: id,
    childId: childId,
    childName: childName,
    occurredAt: occurredAt,
    type: type,
    title: title,
    message: message,
    createdAt: createdAt,
    readAt: readAt ?? DateTime.now(),
  );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

int _integer(Object? value, {required int fallback}) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
