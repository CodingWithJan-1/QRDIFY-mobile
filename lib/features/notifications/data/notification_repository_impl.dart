import '../../../core/network/api_client.dart';
import '../domain/app_notification.dart';
import '../domain/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  const NotificationRepositoryImpl(this._apiClient, this._useMobileApi);

  final ApiClient _apiClient;
  final bool _useMobileApi;

  @override
  bool get supportsDeletion => !_useMobileApi;

  String get _base => 'notifications';

  @override
  Future<NotificationPageResult> fetchNotifications({
    required String accessToken,
    int page = 1,
    int perPage = 20,
    int? childId,
    bool unreadOnly = false,
  }) async {
    final response = await _apiClient.get(
      '$_base?page=$page&per_page=$perPage${childId == null ? '' : '&student_id=$childId'}${unreadOnly ? '&unread=1' : ''}',
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
          ? '$_base/${Uri.encodeComponent(id)}/read'
          : '$_base/${Uri.encodeComponent(id)}/mark-as-read',
      token: accessToken,
    );
  }

  @override
  Future<void> markAllRead({required String accessToken, int? childId}) async {
    await _apiClient.post(
      _useMobileApi ? '$_base/read-all' : '$_base/mark-as-read',
      token: accessToken,
      body: childId == null ? null : {'student_id': childId},
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
    await _apiClient.delete(
      '$_base/${Uri.encodeComponent(id)}',
      token: accessToken,
    );
  }
}
