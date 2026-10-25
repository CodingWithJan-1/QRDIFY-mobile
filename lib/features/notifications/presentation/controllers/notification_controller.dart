import '../../../../core/state/safe_change_notifier.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/app_notification.dart';
import '../../domain/notification_repository.dart';
import '../../domain/notification_signals.dart';

class NotificationController extends SafeChangeNotifier {
  NotificationController(this._repository, this._accessToken, {this.childId});

  final NotificationRepository _repository;
  final String _accessToken;
  final int? childId;
  bool unreadOnly = false;
  int _epoch = 0;
  int? _serverUnreadCount;
  int? _totalCount;

  List<AppNotification> items = const [];
  bool isLoading = false;
  bool isWorking = false;
  String? errorMessage;
  int _currentPage = 0;
  int _lastPage = 1;

  bool get hasMore => _currentPage < _lastPage;
  bool get supportsDeletion => _repository.supportsDeletion;
  int get unreadCount =>
      _serverUnreadCount ?? items.where((item) => !item.isRead).length;
  int get totalCount => _totalCount ?? items.length;

  Future<void> setUnreadOnly(bool value) async {
    if (isLoading || isWorking || value == unreadOnly) return;
    unreadOnly = value;
    await load(refresh: true);
  }

  Future<void> load({bool refresh = false}) async {
    if (isLoading || isWorking) return;
    if (!refresh && items.isNotEmpty) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    final epoch = ++_epoch;
    try {
      final result = await _repository.fetchNotifications(
        accessToken: _accessToken,
        childId: childId,
        unreadOnly: unreadOnly,
      );
      if (epoch != _epoch) return;
      items = result.items;
      _serverUnreadCount = result.unreadCount;
      _totalCount = result.totalCount;
      _currentPage = result.currentPage;
      _lastPage = result.lastPage;
    } catch (error) {
      if (epoch == _epoch) {
        errorMessage = _messageFor(error);
        if (error is ApiException &&
            [401, 403, 404].contains(error.statusCode)) {
          items = [];
          _serverUnreadCount = 0;
          _totalCount = 0;
          _currentPage = 1;
          _lastPage = 1;
        }
      }
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
        childId: childId,
        unreadOnly: unreadOnly,
      );
      items = {
        for (final item in [...items, ...result.items]) item.id: item,
      }.values.toList();
      _serverUnreadCount = result.unreadCount;
      _totalCount = result.totalCount;
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
    if (isWorking) return false;
    isWorking = true;
    errorMessage = null;
    ++_epoch;
    notifyListeners();
    try {
      await _repository.markRead(
        accessToken: _accessToken,
        id: notification.id,
      );
      final count = unreadCount;
      items = [
        for (final item in items)
          if (item.id != notification.id || !unreadOnly)
            if (item.id == notification.id) item.markRead() else item,
      ];
      _serverUnreadCount = count > 0 ? count - 1 : 0;
      NotificationSignals.changed();
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = _messageFor(error);
      notifyListeners();
      return false;
    } finally {
      isWorking = false;
      notifyListeners();
    }
  }

  Future<bool> markAllRead() async {
    if (unreadCount == 0 || isWorking) return true;
    isWorking = true;
    ++_epoch;
    errorMessage = null;
    notifyListeners();
    try {
      await _repository.markAllRead(
        accessToken: _accessToken,
        childId: childId,
      );
      items = unreadOnly ? [] : items.map((item) => item.markRead()).toList();
      _serverUnreadCount = 0;
      NotificationSignals.changed();
      if (unreadOnly) {
        _currentPage = 1;
        _lastPage = 1;
      }
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
    ++_epoch;
    errorMessage = null;
    notifyListeners();
    try {
      await _repository.deleteNotification(
        accessToken: _accessToken,
        id: notification.id,
      );
      final count = unreadCount;
      items = items.where((item) => item.id != notification.id).toList();
      if (!notification.isRead) _serverUnreadCount = count > 0 ? count - 1 : 0;
      if (_totalCount != null && _totalCount! > 0) {
        _totalCount = _totalCount! - 1;
      }
      NotificationSignals.changed();
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
