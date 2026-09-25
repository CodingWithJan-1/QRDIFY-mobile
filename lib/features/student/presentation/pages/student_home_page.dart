import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/presentation/animated_tab_stack.dart';
import '../../../../shared/presentation/module_home_scaffold.dart';
import '../../../auth/domain/auth_user.dart';
import '../../../notifications/domain/notification_repository.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../domain/device_location_service.dart';
import '../../domain/excuse_letter_repository.dart';
import '../../domain/student_attendance_repository.dart';
import '../../domain/student_dashboard.dart';
import '../../domain/student_dashboard_repository.dart';
import '../../domain/student_location_repository.dart';
import '../../domain/student_schedule_repository.dart';
import '../controllers/student_dashboard_controller.dart';
import '../controllers/student_location_controller.dart';
import 'excuse_letters_page.dart';
import 'student_attendance_page.dart';
import 'student_location_page.dart';
import 'student_schedules_page.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({
    required this.user,
    required this.accessToken,
    required this.dashboardRepository,
    required this.attendanceRepository,
    required this.scheduleRepository,
    required this.locationRepository,
    required this.deviceLocationService,
    required this.excuseLetterRepository,
    required this.notificationRepository,
    required this.onLogout,
    super.key,
  });

  final AuthUser user;
  final String accessToken;
  final StudentDashboardRepository dashboardRepository;
  final StudentAttendanceRepository attendanceRepository;
  final StudentScheduleRepository scheduleRepository;
  final StudentLocationRepository locationRepository;
  final DeviceLocationService deviceLocationService;
  final ExcuseLetterRepository excuseLetterRepository;
  final NotificationRepository notificationRepository;
  final Future<void> Function() onLogout;

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage>
    with WidgetsBindingObserver {
  late final StudentDashboardController _controller;
  late final StudentLocationController _locationController;
  late final List<Widget?> _tabs;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = StudentDashboardController(
      widget.dashboardRepository,
      widget.accessToken,
    );
    _locationController = StudentLocationController(
      widget.locationRepository,
      widget.deviceLocationService,
      widget.accessToken,
    )..loadConsent();
    _tabs = List<Widget?>.filled(5, null);
    _tabs[0] = _buildDashboard();
    _controller.load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_locationController.resumeFromBackground());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_locationController.pauseForBackground());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationController.dispose();
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
          selectedIndex: _selectedTab,
          onDestinationSelected: _selectTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.fact_check_outlined),
              selectedIcon: Icon(Icons.fact_check_rounded),
              label: 'Attendance',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Schedule',
            ),
            NavigationDestination(
              icon: Icon(Icons.description_outlined),
              selectedIcon: Icon(Icons.description_rounded),
              label: 'Excuses',
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

  Widget _buildDashboard() {
    return ModuleHomeScaffold(
      title: 'Student',
      userName: widget.user.name,
      userIdentifier: widget.user.displayIdentifier,
      description: 'View your attendance and school activity.',
      onLogout: widget.onLogout,
      onLocationPrivacy: () =>
          _open(StudentLocationPage(controller: _locationController)),
      overview: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) => _DashboardOverview(controller: _controller),
      ),
    );
  }

  Widget _buildTab(int index) => switch (index) {
    0 => _buildDashboard(),
    1 => StudentAttendancePage(
      accessToken: widget.accessToken,
      repository: widget.attendanceRepository,
    ),
    2 => StudentSchedulesPage(
      accessToken: widget.accessToken,
      repository: widget.scheduleRepository,
    ),
    3 => ExcuseLettersPage(
      accessToken: widget.accessToken,
      repository: widget.excuseLetterRepository,
    ),
    4 => NotificationsPage(
      accessToken: widget.accessToken,
      repository: widget.notificationRepository,
    ),
    _ => const SizedBox.shrink(),
  };

  void _selectTab(int index) {
    if (index == _selectedTab) return;
    setState(() {
      _tabs[index] ??= _buildTab(index);
      _selectedTab = index;
    });
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _DashboardOverview extends StatelessWidget {
  const _DashboardOverview({required this.controller});

  final StudentDashboardController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.dashboard == null && controller.isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final dashboard = controller.dashboard;
    if (dashboard == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_outlined, size: 36),
              const SizedBox(height: 12),
              Text(
                controller.errorMessage ?? 'Dashboard data is unavailable.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: controller.load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TodayCard(
          attendance: dashboard.today,
          onRefresh: () => controller.load(refresh: true),
          isRefreshing: controller.isLoading,
        ),
        const SizedBox(height: 12),
        if (!dashboard.summaryComplete) ...[
          const _IncompleteSummaryNotice(),
          const SizedBox(height: 12),
        ],
        _TotalsGrid(totals: dashboard.totals),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.attendance,
    required this.onRefresh,
    required this.isRefreshing,
  });

  final TodayAttendance attendance;
  final VoidCallback onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final status = _sentenceCase(attendance.status);
    final statusColor = switch (attendance.status.toLowerCase()) {
      'present' || 'early' => const Color(0xFF10B981),
      'late' => const Color(0xFFF59E0B),
      'absent' => AppColors.danger,
      _ => const Color(0xFF94A3B8),
    };

    return Card(
      color: statusColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Stack(
        children: [
          Positioned(
            right: -14,
            top: -16,
            child: Icon(
              Icons.schedule_rounded,
              color: Colors.white.withValues(alpha: 0.16),
              size: 112,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "TODAY'S STATUS",
                        style: TextStyle(
                          color: Color(0xD9FFFFFF),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (attendance.timeIn != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Time in: ${_shortTime(attendance.timeIn!)}',
                          style: const TextStyle(
                            color: Color(0xE6FFFFFF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh dashboard',
                  onPressed: isRefreshing ? null : onRefresh,
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    disabledForegroundColor: Colors.white70,
                  ),
                  icon: isRefreshing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsGrid extends StatelessWidget {
  const _TotalsGrid({required this.totals});

  final AttendanceTotals totals;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Days Present',
        totals.present,
        Icons.calendar_month_outlined,
        const Color(0xFF10B981),
      ),
      (
        'Days Absent',
        totals.absent,
        Icons.event_busy_outlined,
        AppColors.danger,
      ),
      ('Late', totals.late, Icons.schedule_outlined, const Color(0xFFF59E0B)),
      (
        'Excused',
        totals.excused,
        Icons.assignment_turned_in_outlined,
        AppColors.blue,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _TotalCard(
                  label: item.$1,
                  value: item.$2,
                  icon: item.$3,
                  color: item.$4,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Positioned(
              right: -4,
              top: -4,
              child: Icon(icon, color: color.withValues(alpha: 0.14), size: 48),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$value',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IncompleteSummaryNotice extends StatelessWidget {
  const _IncompleteSummaryNotice();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Some attendance totals are unavailable until the school '
                'calendar is complete.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _sentenceCase(String value) {
  if (value.isEmpty) return 'Unknown';
  return '${value[0].toUpperCase()}${value.substring(1).replaceAll('_', ' ')}';
}

String _shortTime(String value) {
  final parts = value.split(':');
  return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : value;
}
