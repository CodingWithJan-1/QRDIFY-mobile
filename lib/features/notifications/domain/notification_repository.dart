import 'app_notification.dart';

abstract interface class NotificationRepository {
  bool get supportsDeletion;

  Future<NotificationPageResult> fetchNotifications({
    required String accessToken,
    int page = 1,
    int perPage = 20,
  });

  Future<void> markRead({required String accessToken, required String id});

  Future<void> markAllRead({required String accessToken});

  Future<void> deleteNotification({
    required String accessToken,
    required String id,
  });
}
