import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/app_notification.dart';
import '../../domain/notification_repository.dart';

class NotificationController extends ChangeNotifier {
  NotificationController(this._repository, this._accessToken);

  final NotificationRepository _repository;
  final String _accessToken;

  List<AppNotification> items = const [];
  bool isLoading = false;
  bool isWorking = false;
  String? errorMessage;
  int _currentPage = 0;
  int _lastPage = 1;

  bool get hasMore => _currentPage < _lastPage;
  bool get supportsDeletion => _repository.supportsDeletion;
  int get unreadCount => items.where((item) => !item.isRead).length;

  Future<void> load({bool refresh = false}) async {
    if (isLoading) return;
    if (!refresh && items.isNotEmpty) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _repository.fetchNotifications(
        accessToken: _accessToken,
      );
      items = result.items;
      _currentPage = result.currentPage;
      _lastPage = result.lastPage;
    } catch (error) {
      errorMessage = _messageFor(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || isLoading || isWorking) return;
    isWorking = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _repository.fetchNotifications(
        accessToken: _accessToken,
        page: _currentPage + 1,
      );
      items = [...items, ...result.items];
      _currentPage = result.currentPage;
      _lastPage = result.lastPage;
    } catch (error) {
      errorMessage = _messageFor(error);
    } finally {
      isWorking = false;
      notifyListeners();
    }
  }

  Future<bool> markRead(AppNotification notification) async {
    if (notification.isRead) return true;
    try {
      await _repository.markRead(
        accessToken: _accessToken,
        id: notification.id,
      );
      items = [
        for (final item in items)
          if (item.id == notification.id) item.markRead() else item,
      ];
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = _messageFor(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> markAllRead() async {
    if (unreadCount == 0 || isWorking) return true;
    isWorking = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _repository.markAllRead(accessToken: _accessToken);
      items = items.map((item) => item.markRead()).toList();
      return true;
    } catch (error) {
      errorMessage = _messageFor(error);
      return false;
    } finally {
      isWorking = false;
      notifyListeners();
    }
  }

  Future<bool> delete(AppNotification notification) async {
    if (isWorking || !supportsDeletion) return false;
    isWorking = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _repository.deleteNotification(
        accessToken: _accessToken,
        id: notification.id,
      );
      items = items.where((item) => item.id != notification.id).toList();
      return true;
    } catch (error) {
      errorMessage = _messageFor(error);
      return false;
    } finally {
      isWorking = false;
      notifyListeners();
    }
  }

  String _messageFor(Object error) => switch (error) {
    ApiException exception => exception.message,
    FormatException _ => 'QRDify returned notifications in an unknown format.',
    _ => 'Unable to update notifications. Please try again.',
  };
}
