import 'package:flutter/material.dart';

import '../features/auth/domain/portal_role.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/notifications/domain/notification_repository.dart';
import '../features/parent/domain/parent_enrollment_repository.dart';
import '../features/parent/domain/parent_repository.dart';
import '../features/parent/presentation/pages/parent_enrollment_page.dart';
import '../features/parent/presentation/pages/parent_home_page.dart';
import '../features/student/domain/device_location_service.dart';
import '../features/student/domain/excuse_letter_repository.dart';
import '../features/student/domain/student_attendance_repository.dart';
import '../features/student/domain/student_dashboard_repository.dart';
import '../features/student/domain/student_location_repository.dart';
import '../features/student/domain/student_schedule_repository.dart';
import '../features/student/presentation/pages/student_home_page.dart';
import '../shared/presentation/school_brand.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    required this.controller,
    required this.studentDashboardRepository,
    required this.studentAttendanceRepository,
    required this.studentScheduleRepository,
    required this.studentLocationRepository,
    required this.deviceLocationService,
    required this.excuseLetterRepository,
    required this.notificationRepository,
    required this.parentRepository,
    required this.parentEnrollmentRepository,
    super.key,
  });

  final AuthController controller;
  final StudentDashboardRepository studentDashboardRepository;
  final StudentAttendanceRepository studentAttendanceRepository;
  final StudentScheduleRepository studentScheduleRepository;
  final StudentLocationRepository studentLocationRepository;
  final DeviceLocationService deviceLocationService;
  final ExcuseLetterRepository excuseLetterRepository;
  final NotificationRepository notificationRepository;
  final ParentRepository parentRepository;
  final ParentEnrollmentRepository parentEnrollmentRepository;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.status == AuthStatus.checking) {
          return const _StartupPage();
        }

        final session = controller.session;
        if (controller.status == AuthStatus.authenticated && session != null) {
          return switch (session.user.portalRole) {
            PortalRole.student => StudentHomePage(
              user: session.user,
              accessToken: session.accessToken,
              dashboardRepository: studentDashboardRepository,
              attendanceRepository: studentAttendanceRepository,
              scheduleRepository: studentScheduleRepository,
              locationRepository: studentLocationRepository,
              deviceLocationService: deviceLocationService,
              excuseLetterRepository: excuseLetterRepository,
              notificationRepository: notificationRepository,
              onLogout: controller.logout,
            ),
            PortalRole.parent => ParentHomePage(
              user: session.user,
              accessToken: session.accessToken,
              parentRepository: parentRepository,
              parentEnrollmentRepository: parentEnrollmentRepository,
              notificationRepository: notificationRepository,
              onLogout: controller.logout,
            ),
            null => _loginPage(context),
          };
        }

        return _loginPage(context);
      },
    );
  }

  Widget _loginPage(BuildContext context) => LoginPage(
    controller: controller,
    onParentInvitation: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ParentEnrollmentPage(repository: parentEnrollmentRepository),
      ),
    ),
  );
}

class _StartupPage extends StatelessWidget {
  const _StartupPage();

  @override
  Widget build(BuildContext context) {
    return const BrandedLoadingScreen();
  }
}
