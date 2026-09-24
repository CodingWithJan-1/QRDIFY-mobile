import '../../../core/network/api_client.dart';
import '../domain/app_notification.dart';
import '../domain/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  const NotificationRepositoryImpl(this._apiClient, this._useMobileApi);

  final ApiClient _apiClient;
  final bool _useMobileApi;

  @override
  bool get supportsDeletion => !_useMobileApi;

  @override
  Future<NotificationPageResult> fetchNotifications({
    required String accessToken,
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _apiClient.get(
      'notifications?page=$page&per_page=$perPage',
      token: accessToken,
    );
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid notification response.');
    }
    return NotificationPageResult.fromJson(response);
  }

  @override
  Future<void> markRead({
    required String accessToken,
    required String id,
  }) async {
    await _apiClient.post(
      _useMobileApi
          ? 'notifications/$id/read'
          : 'notifications/$id/mark-as-read',
      token: accessToken,
    );
  }

  @override
  Future<void> markAllRead({required String accessToken}) async {
    await _apiClient.post(
      _useMobileApi ? 'notifications/read-all' : 'notifications/mark-as-read',
      token: accessToken,
    );
  }

  @override
  Future<void> deleteNotification({
    required String accessToken,
    required String id,
  }) async {
    if (!supportsDeletion) {
      throw UnsupportedError(
        'Notification deletion is unavailable on this API version.',
      );
    }
    await _apiClient.delete('notifications/$id', token: accessToken);
  }
}
