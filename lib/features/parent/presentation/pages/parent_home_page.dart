import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/presentation/animated_tab_stack.dart';
import '../../../auth/domain/auth_user.dart';
import '../../../notifications/domain/notification_repository.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../domain/parent_child.dart';
import '../../domain/parent_enrollment_repository.dart';
import '../../domain/parent_repository.dart';
import '../controllers/parent_home_controller.dart';
import 'parent_attendance_page.dart';
import 'parent_children_page.dart';
import 'parent_dashboard_page.dart';
import 'parent_enrollment_page.dart';
import 'parent_profile_page.dart';

class ParentHomePage extends StatefulWidget {
  const ParentHomePage({
    required this.user,
    required this.accessToken,
    required this.parentRepository,
    required this.parentEnrollmentRepository,
    required this.notificationRepository,
    required this.onLogout,
    required this.onUploadPhoto,
    required this.onRemovePhoto,
    super.key,
  });

  final AuthUser user;
  final String accessToken;
  final ParentRepository parentRepository;
  final ParentEnrollmentRepository parentEnrollmentRepository;
  final NotificationRepository notificationRepository;
  final Future<void> Function() onLogout;
  final Future<AuthUser> Function(List<int> bytes) onUploadPhoto;
  final Future<AuthUser> Function() onRemovePhoto;

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  late final ParentHomeController _controller;
  late final List<Widget?> _tabs;
  int _selectedTab = 0;
  bool _childWorkspaceOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = ParentHomeController(
      widget.parentRepository,
      widget.accessToken,
    )..addListener(_handleControllerChanged);
    _tabs = List<Widget?>.filled(4, null);
    unawaited(_loadInitialData());
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_childWorkspaceOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_childWorkspaceOpen) return;
        if (_selectedTab != 0) {
          _selectTab(0);
        } else {
          _returnToChildren();
        }
      },
      child: Scaffold(
        body: _childWorkspaceOpen
            ? AnimatedTabStack(
                index: _selectedTab,
                children: List.generate(
                  _tabs.length,
                  (index) => _tabs[index] ?? const SizedBox.shrink(),
                ),
              )
            : _buildChildren(),
        bottomNavigationBar: _childWorkspaceOpen
            ? NavigationBar(
                height: 82,
                selectedIndex: _selectedTab,
                onDestinationSelected: _selectTab,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Overview',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.fact_check_outlined),
                    selectedIcon: Icon(Icons.fact_check_rounded),
                    label: 'Attendance',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.event_busy_outlined),
                    selectedIcon: Icon(Icons.event_busy_rounded),
                    label: 'Absences',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.notifications_outlined),
                    selectedIcon: Icon(Icons.notifications_rounded),
                    label: 'Alerts',
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildChildren() => ParentChildrenPage(
    user: widget.user,
    controller: _controller,
    onChildSelected: (child) => unawaited(_selectChild(child)),
    onAddChild: () => unawaited(_openEnrollment()),
    onLogout: widget.onLogout,
    onProfile: () => Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ParentProfilePage(
          user: widget.user,
          onUploadPhoto: widget.onUploadPhoto,
          onRemovePhoto: widget.onRemovePhoto,
        ),
      ),
    ),
  );

  Widget _buildTab(int index) {
    final child = _controller.selectedChild;
    return switch (index) {
      0 => ParentDashboardPage(
        controller: _controller,
        onChangeChild: _returnToChildren,
      ),
      1 when child != null => ParentAttendancePage(
        key: ValueKey('attendance-${child.id}'),
        accessToken: widget.accessToken,
        repository: widget.parentRepository,
        child: child,
        onChangeChild: _returnToChildren,
      ),
      2 when child != null => ParentAttendancePage(
        key: ValueKey('absences-${child.id}'),
        accessToken: widget.accessToken,
        repository: widget.parentRepository,
        child: child,
        absencesOnly: true,
        onChangeChild: _returnToChildren,
      ),
      3 => NotificationsPage(
        accessToken: widget.accessToken,
        repository: widget.notificationRepository,
        parentStyle: true,
        child: child,
        onChangeChild: _returnToChildren,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  void _selectTab(int index) {
    if (!_childWorkspaceOpen || index == _selectedTab) return;
    setState(() {
      _tabs[index] ??= _buildTab(index);
      _selectedTab = index;
    });
  }

  Future<void> _selectChild(ParentChild child) async {
    await _controller.selectChild(child);
    if (!mounted) return;
    setState(() {
      _tabs.fillRange(0, _tabs.length, null);
      _selectedTab = 0;
      _tabs[0] = _buildTab(0);
      _childWorkspaceOpen = true;
    });
  }

  void _returnToChildren() {
    if (!_childWorkspaceOpen) return;
    setState(() {
      _childWorkspaceOpen = false;
      _selectedTab = 0;
    });
  }

  void _handleControllerChanged() {
    if (_childWorkspaceOpen && _controller.selectedChild == null && mounted) {
      _returnToChildren();
    }
  }

  Future<void> _loadInitialData() async {
    await _controller.load();
  }

  Future<void> _openEnrollment() async {
    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ParentEnrollmentPage(
          repository: widget.parentEnrollmentRepository,
          accessToken: widget.accessToken,
        ),
      ),
    );
    if (accepted != true) return;

    await _controller.load(refresh: true);
  }
}
