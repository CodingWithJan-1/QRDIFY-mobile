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
import '../widgets/parent_design.dart';

class ParentHomePage extends StatefulWidget {
  const ParentHomePage({
    required this.user,
    required this.accessToken,
    required this.parentRepository,
    required this.parentEnrollmentRepository,
    required this.notificationRepository,
    required this.onLogout,
    super.key,
  });

  final AuthUser user;
  final String accessToken;
  final ParentRepository parentRepository;
  final ParentEnrollmentRepository parentEnrollmentRepository;
  final NotificationRepository notificationRepository;
  final Future<void> Function() onLogout;

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  late final ParentHomeController _controller;
  late final List<Widget?> _tabs;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _controller = ParentHomeController(
      widget.parentRepository,
      widget.accessToken,
    );
    _tabs = List<Widget?>.filled(5, null);
    _tabs[0] = _buildChildren();
    unawaited(_loadInitialData());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedTab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedTab != 0) _selectTab(0);
      },
      child: Scaffold(
        body: AnimatedTabStack(
          index: _selectedTab,
          children: List.generate(
            _tabs.length,
            (index) => _tabs[index] ?? const SizedBox.shrink(),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          height: 82,
          selectedIndex: _selectedTab,
          onDestinationSelected: _selectTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.family_restroom_outlined),
              selectedIcon: Icon(Icons.family_restroom_rounded),
              label: 'Children',
            ),
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
        ),
      ),
    );
  }

  Widget _buildChildren() => ParentChildrenPage(
    user: widget.user,
    controller: _controller,
    onChildSelected: (child) => unawaited(_selectChild(child)),
    onAddChild: () => unawaited(_openEnrollment()),
    onLogout: widget.onLogout,
  );

  Widget _buildTab(int index) {
    final child = _controller.selectedChild;
    return switch (index) {
      0 => _buildChildren(),
      1 => ParentDashboardPage(controller: _controller),
      2 when child != null => ParentAttendancePage(
        key: ValueKey('attendance-${child.id}'),
        accessToken: widget.accessToken,
        repository: widget.parentRepository,
        child: child,
      ),
      3 when child != null => ParentAttendancePage(
        key: ValueKey('absences-${child.id}'),
        accessToken: widget.accessToken,
        repository: widget.parentRepository,
        child: child,
        absencesOnly: true,
      ),
      2 || 3 => const _ChooseChildPage(),
      4 => NotificationsPage(
        accessToken: widget.accessToken,
        repository: widget.notificationRepository,
        parentStyle: true,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  void _selectTab(int index) {
    if (index == _selectedTab) return;
    setState(() {
      _tabs[index] ??= _buildTab(index);
      _selectedTab = index;
    });
  }

  Future<void> _selectChild(ParentChild child) async {
    await _controller.selectChild(child);
    if (!mounted) return;
    setState(() {
      _tabs[1] = _buildTab(1);
      _tabs[2] = null;
      _tabs[3] = null;
      _selectedTab = 1;
    });
  }

  Future<void> _loadInitialData() async {
    await _controller.load();
    if (!mounted) return;
    setState(() {
      _tabs[1] = null;
      _tabs[2] = null;
      _tabs[3] = null;
    });
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
    if (!mounted) return;
    setState(() {
      _tabs[1] = null;
      _tabs[2] = null;
      _tabs[3] = null;
    });
  }
}

class _ChooseChildPage extends StatelessWidget {
  const _ChooseChildPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParentDesign.background,
      appBar: const ParentPageHeader(title: 'Child records'),
      body: const ParentEmptyState(
        icon: Icons.family_restroom_outlined,
        title: 'Choose a child first',
        message: 'Select a linked child from the Children tab.',
      ),
    );
  }
}
