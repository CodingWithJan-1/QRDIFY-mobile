import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/notification_repository.dart';
import '../../domain/notification_signals.dart';

class NotificationBadge extends StatefulWidget {
  const NotificationBadge({
    required this.repository,
    required this.accessToken,
    required this.child,
    this.childId,
    super.key,
  });

  final NotificationRepository repository;
  final String accessToken;
  final int? childId;
  final Widget child;

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge>
    with WidgetsBindingObserver {
  Timer? _poll;
  int _epoch = 0;
  bool _unread = false;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationSignals.refresh.addListener(_refresh);
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
    _refresh();
  }

  @override
  void didUpdateWidget(covariant NotificationBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accessToken != widget.accessToken ||
        oldWidget.childId != widget.childId ||
        oldWidget.repository != widget.repository) {
      ++_epoch;
      _unread = false;
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (!_resumed) return;
    final epoch = ++_epoch;
    try {
      final result = await widget.repository.fetchNotifications(
        accessToken: widget.accessToken,
        childId: widget.childId,
        perPage: 1,
        unreadOnly: true,
      );
      if (!mounted || epoch != _epoch) return;
      setState(
        () => _unread = result.unreadCount == null
            ? result.items.any((item) => !item.isRead)
            : result.unreadCount! > 0,
      );
    } on ApiException catch (error) {
      if (mounted &&
          epoch == _epoch &&
          [401, 403, 404].contains(error.statusCode)) {
        setState(() => _unread = false);
      }
    } catch (_) {
      // Keep the last confirmed unread state during a temporary connection failure.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    NotificationSignals.refresh.removeListener(_refresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: _unread ? 'Unread notifications' : 'Notifications',
    child: Badge(
      isLabelVisible: _unread,
      backgroundColor: AppColors.danger,
      smallSize: 9,
      child: widget.child,
    ),
  );
}
