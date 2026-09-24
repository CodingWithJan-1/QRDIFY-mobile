class NotificationPageResult {
  const NotificationPageResult({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });

  factory NotificationPageResult.fromJson(Map<String, dynamic> json) {
    final meta = _map(json['meta']);
    final values = json['data'];
    final items = values is List
        ? values.map((item) => AppNotification.fromJson(_map(item))).toList()
        : const <AppNotification>[];
    return NotificationPageResult(
      items: items,
      currentPage: _integer(
        meta['current_page'] ?? json['current_page'],
        fallback: 1,
      ),
      lastPage: _integer(meta['last_page'] ?? json['last_page'], fallback: 1),
    );
  }

  final List<AppNotification> items;
  final int currentPage;
  final int lastPage;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final data = _map(json['data']);
    return AppNotification(
      id: '${json['id'] ?? ''}',
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

  bool get isRead => readAt != null;

  AppNotification markRead() => AppNotification(
    id: id,
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
