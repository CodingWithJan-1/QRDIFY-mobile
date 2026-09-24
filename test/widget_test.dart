import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrdify/app/app_bootstrap.dart';
import 'package:qrdify/app/qrdify_app.dart';
import 'package:qrdify/core/network/api_exception.dart';
import 'package:qrdify/features/auth/domain/auth_repository.dart';
import 'package:qrdify/features/auth/domain/auth_session.dart';
import 'package:qrdify/features/auth/domain/auth_user.dart';
import 'package:qrdify/features/auth/presentation/controllers/auth_controller.dart';
import 'package:qrdify/features/notifications/domain/app_notification.dart';
import 'package:qrdify/features/notifications/domain/notification_repository.dart';
import 'package:qrdify/features/parent/domain/parent_attendance.dart';
import 'package:qrdify/features/parent/domain/parent_child.dart';
import 'package:qrdify/features/parent/domain/parent_dashboard.dart';
import 'package:qrdify/features/parent/domain/parent_enrollment_repository.dart';
import 'package:qrdify/features/parent/domain/parent_repository.dart';
import 'package:qrdify/features/student/domain/device_location_service.dart';
import 'package:qrdify/features/student/domain/excuse_letter.dart';
import 'package:qrdify/features/student/domain/excuse_letter_repository.dart';
import 'package:qrdify/features/student/domain/excuse_teacher.dart';
import 'package:qrdify/features/student/domain/student_attendance.dart';
import 'package:qrdify/features/student/domain/student_attendance_repository.dart';
import 'package:qrdify/features/student/domain/student_dashboard.dart';
import 'package:qrdify/features/student/domain/student_dashboard_repository.dart';
import 'package:qrdify/features/student/domain/student_location.dart';
import 'package:qrdify/features/student/domain/student_location_repository.dart';
import 'package:qrdify/features/student/domain/student_schedule.dart';
import 'package:qrdify/features/student/domain/student_schedule_repository.dart';

void main() {
  testWidgets('signs in and opens the student module', (tester) async {
    final repository = _FakeAuthRepository(loginSession: _studentSession);
    final controller = AuthController(repository);

    await tester.pumpWidget(QrdifyApp(dependencies: _dependencies(controller)));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back!'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'student@example.test',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Welcome, Sample Student.'), findsOneWidget);
    expect(find.text('Campus location'), findsNothing);
    expect(find.text('DAYS PRESENT'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byTooltip('Account menu'));
    await tester.pumpAndSettle();
    expect(find.text('Location & privacy'), findsOneWidget);
    await tester.tap(find.text('Location & privacy'));
    await tester.pumpAndSettle();
    expect(find.text('Campus location'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Attendance'));
    await tester.pumpAndSettle();

    expect(find.text('Recorded attendance rate'), findsOneWidget);
    expect(find.text('Sep 7, 2026'), findsOneWidget);

    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    expect(find.text('Add schedule'), findsOneWidget);

    await tester.tap(find.text('Add schedule'));
    await tester.pumpAndSettle();
    expect(find.text('Description (optional)'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Excuses'));
    await tester.pumpAndSettle();
    expect(find.text('Create'), findsOneWidget);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Create Excuse Letter'), findsOneWidget);
    expect(find.text('Reason for absence'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle();
    expect(find.text('No notifications to show.'), findsOneWidget);
  });

  testWidgets('restores a parent session', (tester) async {
    final repository = _FakeAuthRepository(restoredSession: _parentSession);
    final controller = AuthController(repository);

    await tester.pumpWidget(QrdifyApp(dependencies: _dependencies(controller)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sample Parent'), findsOneWidget);
    expect(find.text('1 linked'), findsOneWidget);
    expect(find.text('Sample Child'), findsOneWidget);
    expect(find.text('Add approved child'), findsOneWidget);

    await tester.tap(find.text('Sample Child'));
    await tester.pumpAndSettle();
    expect(find.text('Child overview'), findsOneWidget);
    expect(find.text('Present'), findsWidgets);

    await tester.tap(find.text('Attendance'));
    await tester.pumpAndSettle();
    expect(find.text('RECORDED ATTENDANCE'), findsOneWidget);
    expect(find.text('Sep 7, 2026'), findsOneWidget);

    await tester.tap(find.text('Absences'));
    await tester.pumpAndSettle();
    expect(find.text('No absences recorded'), findsOneWidget);

    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle();
    expect(find.text("You're all caught up"), findsOneWidget);
  });

  testWidgets('accepts a Parent invitation from the sign-in screen', (
    tester,
  ) async {
    final controller = AuthController(_FakeAuthRepository());
    await tester.pumpWidget(QrdifyApp(dependencies: _dependencies(controller)));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Use a Parent invitation'));
    await tester.tap(find.text('Use a Parent invitation'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'invitation-token');
    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '123456');
    await tester.enterText(find.byType(TextFormField).at(1), 'Sample Parent');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'StrongPassword123!',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Parent account created'), findsOneWidget);
    expect(find.text('Return to sign in'), findsOneWidget);
  });

  testWidgets('briefly confirms that the Parent verification code was sent', (
    tester,
  ) async {
    final controller = AuthController(_FakeAuthRepository());
    await tester.pumpWidget(QrdifyApp(dependencies: _dependencies(controller)));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Use a Parent invitation'));
    await tester.tap(find.text('Use a Parent invitation'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'invitation-token');
    await tester.tap(find.text('Send verification code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Verification code sent'), findsOneWidget);
    expect(
      find.textContaining('Open Gmail or your email inbox'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Verification code sent'), findsNothing);
    expect(find.text('Verify your email'), findsOneWidget);
  });

  testWidgets('directs an existing invited Parent to sign in', (tester) async {
    final controller = AuthController(_FakeAuthRepository());
    final enrollmentRepository = _FakeParentEnrollmentRepository(
      acceptError: const ApiException(
        statusCode: 409,
        code: 'sign_in_required',
        message: 'Sign in required.',
      ),
    );
    await tester.pumpWidget(
      QrdifyApp(
        dependencies: _dependencies(
          controller,
          parentEnrollmentRepository: enrollmentRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Use a Parent invitation'));
    await tester.tap(find.text('Use a Parent invitation'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'invitation-token');
    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '123456');
    await tester.enterText(find.byType(TextFormField).at(1), 'Sample Parent');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'StrongPassword123!',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Parent account found'), findsOneWidget);
    expect(find.text('Sign in required.'), findsNothing);
    await tester.tap(find.text('Return to sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back!'), findsOneWidget);
  });
}

AppDependencies _dependencies(
  AuthController controller, {
  ParentEnrollmentRepository? parentEnrollmentRepository,
}) {
  return AppDependencies(
    authController: controller,
    studentDashboardRepository: _FakeStudentDashboardRepository(),
    studentAttendanceRepository: _FakeStudentAttendanceRepository(),
    studentScheduleRepository: _FakeStudentScheduleRepository(),
    studentLocationRepository: _FakeStudentLocationRepository(),
    deviceLocationService: _FakeDeviceLocationService(),
    excuseLetterRepository: _FakeExcuseLetterRepository(),
    notificationRepository: _FakeNotificationRepository(),
    parentRepository: _FakeParentRepository(),
    parentEnrollmentRepository:
        parentEnrollmentRepository ?? _FakeParentEnrollmentRepository(),
  );
}

const _studentSession = AuthSession(
  accessToken: 'student-token',
  user: AuthUser(
    id: 15,
    name: 'Sample Student',
    email: 'student@example.test',
    roles: ['student'],
    needsPasswordChange: false,
  ),
);

const _parentSession = AuthSession(
  accessToken: 'parent-token',
  user: AuthUser(
    id: 201,
    name: 'Sample Parent',
    email: 'parent@example.test',
    roles: ['parent'],
    needsPasswordChange: false,
  ),
);

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.restoredSession, this.loginSession});

  final AuthSession? restoredSession;
  final AuthSession? loginSession;

  @override
  Future<AuthSession?> restoreSession() async => restoredSession;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return loginSession!;
  }

  @override
  Future<void> logout() async {}

  @override
  void close() {}
}

class _FakeStudentDashboardRepository implements StudentDashboardRepository {
  @override
  Future<StudentDashboard> fetchDashboard({
    required String accessToken,
    required DateTime month,
  }) async {
    return const StudentDashboard(
      month: '2026-09',
      timezone: 'Asia/Manila',
      summaryComplete: true,
      totals: AttendanceTotals(
        expectedDays: 5,
        present: 2,
        late: 1,
        attended: 3,
        absent: 1,
        excused: 1,
        pending: 0,
      ),
      today: TodayAttendance(
        date: '2026-09-07',
        status: 'late',
        attendanceId: 501,
        timeIn: '08:05:00',
      ),
      unreadNotifications: 2,
    );
  }
}

class _FakeStudentAttendanceRepository implements StudentAttendanceRepository {
  @override
  Future<StudentAttendanceResult> fetchAttendance({
    required String accessToken,
    int page = 1,
    int perPage = 20,
  }) async {
    return const StudentAttendanceResult(
      summary: AttendanceRecordSummary(
        total: 2,
        present: 1,
        absent: 0,
        late: 1,
        presentPercentage: 50,
      ),
      records: [
        StudentAttendanceRecord(
          id: 501,
          date: '2026-09-07',
          status: 'late',
          timeIn: '08:05:00',
        ),
      ],
      currentPage: 1,
      lastPage: 1,
      totalRecords: 1,
    );
  }
}

class _FakeStudentScheduleRepository implements StudentScheduleRepository {
  @override
  Future<List<StudentSchedule>> fetchSchedules({
    required String accessToken,
  }) async => const [];

  @override
  Future<StudentSchedule> createSchedule({
    required String accessToken,
    required StudentScheduleDraft draft,
  }) => throw UnimplementedError();

  @override
  Future<StudentSchedule> updateSchedule({
    required String accessToken,
    required int id,
    required StudentScheduleDraft draft,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteSchedule({
    required String accessToken,
    required int id,
  }) async {}
}

class _FakeExcuseLetterRepository implements ExcuseLetterRepository {
  @override
  Future<List<ExcuseLetter>> fetchLetters({
    required String accessToken,
  }) async => const [];

  @override
  Future<List<ExcuseTeacher>> fetchTeachers({
    required String accessToken,
  }) async => const [ExcuseTeacher(id: 8, name: 'Teacher Demo')];

  @override
  Future<ExcuseLetter> submitLetter({
    required String accessToken,
    required String title,
    required DateTime absentDate,
    required String reason,
    required int teacherId,
    List<int>? attachmentBytes,
    String? attachmentName,
  }) async => ExcuseLetter(
    id: 1,
    title: title,
    absentDate: absentDate.toIso8601String().split('T').first,
    reason: reason,
    status: 'pending',
    teacherName: 'Teacher Demo',
  );

  @override
  Future<void> deleteLetter({
    required String accessToken,
    required int letterId,
  }) async {}
}

class _FakeStudentLocationRepository implements StudentLocationRepository {
  @override
  Future<StudentLocationConsent> fetchConsent({
    required String accessToken,
  }) async => const StudentLocationConsent(
    enabled: false,
    policyVersion: 'test-policy',
  );

  @override
  Future<StudentLocationConsent> updateConsent({
    required String accessToken,
    required bool enabled,
    required String policyVersion,
  }) async =>
      StudentLocationConsent(enabled: enabled, policyVersion: policyVersion);

  @override
  Future<StudentGeofencePolicy> fetchGeofencePolicy({
    required String accessToken,
  }) async => const StudentGeofencePolicy(
    enabled: false,
    polygon: [],
    boundaryBufferMeters: 15,
    maxAccuracyMeters: 100,
    outsideConfirmations: 2,
    insideConfirmations: 2,
    confirmationWindow: Duration(minutes: 5),
    trackingWindowActive: false,
    activeBreach: false,
  );

  @override
  Future<StudentLocationReport> reportLocation({
    required String accessToken,
    required StudentLocationSample sample,
  }) async {
    return const StudentLocationReport(
      accepted: true,
      boundaryState: BoundaryState.unknown,
    );
  }
}

class _FakeDeviceLocationService implements DeviceLocationService {
  @override
  Future<DeviceLocationPermission> checkPermission() async =>
      DeviceLocationPermission.whileInUse;

  @override
  Future<DeviceLocation> getCurrentLocation() {
    throw UnimplementedError();
  }

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<void> startBackgroundTracking(Duration interval) async {}

  @override
  Future<void> stopBackgroundTracking() async {}

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<DeviceLocationPermission> requestPermission() async =>
      DeviceLocationPermission.whileInUse;
}

class _FakeNotificationRepository implements NotificationRepository {
  @override
  bool get supportsDeletion => true;

  @override
  Future<NotificationPageResult> fetchNotifications({
    required String accessToken,
    int page = 1,
    int perPage = 20,
  }) async =>
      const NotificationPageResult(items: [], currentPage: 1, lastPage: 1);

  @override
  Future<void> markRead({
    required String accessToken,
    required String id,
  }) async {}

  @override
  Future<void> markAllRead({required String accessToken}) async {}

  @override
  Future<void> deleteNotification({
    required String accessToken,
    required String id,
  }) async {}
}

class _FakeParentRepository implements ParentRepository {
  static const child = ParentChild(
    id: 15,
    name: 'Sample Child',
    relationship: 'mother',
    canViewLocation: false,
    canSubmitExcuses: true,
    historyVisibleFrom: '2026-06-01',
    grade: 'Grade 6',
    section: 'Rizal',
  );

  @override
  Future<List<ParentChild>> fetchChildren({
    required String accessToken,
  }) async => const [child];

  @override
  Future<ParentChildDashboard> fetchDashboard({
    required String accessToken,
    required int childId,
    required DateTime month,
  }) async => const ParentChildDashboard(
    month: '2026-09',
    summaryComplete: false,
    present: 2,
    late: 1,
    attended: 3,
    absent: 1,
    excused: 0,
    todayStatus: 'present',
    todayTimeIn: '07:31:00',
  );

  @override
  Future<ParentAttendanceResult> fetchAttendance({
    required String accessToken,
    required int childId,
    int page = 1,
    int perPage = 20,
    bool absencesOnly = false,
  }) async => ParentAttendanceResult(
    records: absencesOnly
        ? const []
        : const [
            ParentAttendanceRecord(
              id: 91,
              date: '2026-09-07',
              status: 'present',
              timeIn: '07:31:00',
            ),
          ],
    summary: const ParentAttendanceSummary(
      total: 1,
      present: 1,
      absent: 0,
      late: 0,
      presentPercentage: 100,
    ),
    currentPage: 1,
    lastPage: 1,
  );
}

class _FakeParentEnrollmentRepository implements ParentEnrollmentRepository {
  _FakeParentEnrollmentRepository({this.acceptError});

  final Object? acceptError;

  @override
  Future<String> requestVerification({required String invitationToken}) async =>
      'verification-id';

  @override
  Future<ParentEnrollmentResult> acceptInvitation({
    required String invitationToken,
    required String verificationId,
    required String code,
    String? name,
    String? password,
    String? accessToken,
  }) async {
    if (acceptError case final error?) throw error;
    return const ParentEnrollmentResult(parentUserId: 201, studentId: 15);
  }
}
