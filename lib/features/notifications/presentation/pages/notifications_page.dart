import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/app_notification.dart';
import '../../domain/notification_repository.dart';
import '../controllers/notification_controller.dart';

enum _NotificationFilter { all, unread }

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    required this.accessToken,
    required this.repository,
    this.parentStyle = false,
    super.key,
  });

  final String accessToken;
  final NotificationRepository repository;
  final bool parentStyle;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final NotificationController _controller;
  _NotificationFilter _filter = _NotificationFilter.all;

  @override
  void initState() {
    super.initState();
    _controller = NotificationController(widget.repository, widget.accessToken)
      ..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.parentStyle ? const Color(0xFFF6FAFE) : null,
      appBar: AppBar(
        toolbarHeight: widget.parentStyle ? 82 : null,
        title: Text(
          'Notifications',
          style: widget.parentStyle
              ? const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)
              : null,
        ),
        actions: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => TextButton(
              onPressed: _controller.unreadCount == 0 || _controller.isWorking
                  ? null
                  : _markAllRead,
              child: const Text('Read all'),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isLoading && _controller.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_controller.items.isEmpty && _controller.errorMessage != null) {
            return _NotificationMessage(
              icon: Icons.cloud_off_outlined,
              message: _controller.errorMessage!,
              onRetry: () => _controller.load(refresh: true),
            );
          }

          final visibleItems = _filter == _NotificationFilter.all
              ? _controller.items
              : _controller.items.where((item) => !item.isRead).toList();
          return RefreshIndicator(
            onRefresh: () => _controller.load(refresh: true),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SegmentedButton<_NotificationFilter>(
                  style: widget.parentStyle
                      ? ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? const Color(0xFFE1EEFF)
                                : Colors.white,
                          ),
                          foregroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? AppColors.blue
                                : const Color(0xFF08142B),
                          ),
                          textStyle: const WidgetStatePropertyAll(
                            TextStyle(fontWeight: FontWeight.w800),
                          ),
                        )
                      : null,
                  segments: [
                    ButtonSegment(
                      value: _NotificationFilter.all,
                      label: Text('All (${_controller.items.length})'),
                    ),
                    ButtonSegment(
                      value: _NotificationFilter.unread,
                      label: Text('Unread (${_controller.unreadCount})'),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (selection) {
                    setState(() => _filter = selection.first);
                  },
                ),
                if (_controller.errorMessage case final message?) ...[
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (visibleItems.isEmpty)
                  _NotificationMessage(
                    icon: Icons.notifications_none,
                    title: widget.parentStyle ? "You're all caught up" : null,
                    message: widget.parentStyle
                        ? 'New attendance and school updates will appear here.'
                        : 'No notifications to show.',
                  )
                else
                  ...visibleItems.map(
                    (item) => _NotificationCard(
                      item: item,
                      onTap: () => _openNotification(item),
                      onDelete: _controller.supportsDeletion
                          ? () => _deleteNotification(item)
                          : null,
                    ),
                  ),
                if (_controller.hasMore) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _controller.isWorking
                        ? null
                        : _controller.loadMore,
                    child: _controller.isWorking
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Load more'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openNotification(AppNotification item) async {
    await _controller.markRead(item);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: Text(item.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAllRead() async {
    final success = await _controller.markAllRead();
    if (!success && mounted) _showError();
  }

  Future<void> _deleteNotification(AppNotification item) async {
    final deleted = await _controller.delete(item);
    if (!deleted && mounted) _showError();
  }

  void _showError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _controller.errorMessage ?? 'Could not update notification.',
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.onTap,
    this.onDelete,
  });

  final AppNotification item;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: item.isRead
          ? null
          : Theme.of(context).colorScheme.primaryContainer
                .withValues(alpha: 0.5),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(child: Icon(_iconFor(item.type))),
        title: Text(
          item.title,
          style: TextStyle(
            fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w900,
          ),
        ),
        subtitle: Text(
          '${item.message}\n${_relativeTime(item.createdAt)}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: onDelete == null
            ? null
            : IconButton(
                tooltip: 'Delete notification',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
      ),
    );
  }
}

class _NotificationMessage extends StatelessWidget {
  const _NotificationMessage({
    required this.icon,
    required this.message,
    this.title,
    this.onRetry,
  });

  final IconData icon;
  final String? title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 94,
              height: 94,
              decoration: const BoxDecoration(
                color: Color(0xFFF0F6FD),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 52, color: const Color(0xFF08142B)),
            ),
            const SizedBox(height: 20),
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF08142B),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(String type) {
  final normalized = type.toLowerCase();
  if (normalized.contains('time_in')) return Icons.login;
  if (normalized.contains('time_out')) return Icons.logout;
  if (normalized.contains('excuse')) return Icons.description_outlined;
  if (normalized.contains('alarm')) return Icons.alarm_outlined;
  return Icons.notifications_outlined;
}

String _relativeTime(DateTime? date) {
  if (date == null) return '';
  final difference = DateTime.now().difference(date.toLocal());
  if (difference.isNegative) return 'Just now';
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return '${date.toLocal().year}-${date.toLocal().month.toString().padLeft(2, '0')}-'
      '${date.toLocal().day.toString().padLeft(2, '0')}';
}
