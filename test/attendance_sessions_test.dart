import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrdify/features/parent/domain/parent_attendance.dart';
import 'package:qrdify/features/parent/domain/parent_child.dart';
import 'package:qrdify/features/parent/domain/parent_dashboard.dart';
import 'package:qrdify/features/parent/domain/parent_repository.dart';
import 'package:qrdify/features/parent/presentation/pages/parent_attendance_page.dart';
import 'package:qrdify/features/student/domain/student_attendance.dart';
import 'package:qrdify/features/student/domain/student_attendance_repository.dart';
import 'package:qrdify/features/student/domain/student_dashboard.dart';
import 'package:qrdify/features/student/presentation/pages/student_attendance_page.dart';
import 'package:qrdify/shared/domain/attendance_sessions.dart';

const afternoonOnly = {
  'id': 1,
  'date': '2026-10-23',
  'status': 'late',
  'time_in': '12:45:00',
  'am_status': 'Absent',
  'pm_status': 'Present',
};

void main() {
  test(
    'compatibility dashboard keeps afternoon sessions and counts half-days',
    () {
      final now = DateTime.now();
      final date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final dashboard = StudentDashboard.fromLegacyJson({
        'total_present': 1,
        'total_absent': 0,
        'today_status': 'Half_day',
        'history': [
          {
            ...afternoonOnly,
            'date': date,
            'status': 'half_day',
            'pm_status': 'late',
          },
        ],
      }, month: date.substring(0, 7));
      expect(dashboard.totals.halfDay, 1);
      expect(dashboard.totals.attended, 2);
      expect(dashboard.totals.expectedDays, 2);
      expect(dashboard.today.sessions.description, 'AM: Absent • PM: Late');
      expect(dashboard.today.status, 'half_day');
    },
  );

  test(
    'session labels distinguish half-days from pending or excused sessions',
    () {
      for (final attended in ['present', 'early', 'late']) {
        final morningOnly = AttendanceSessions(am: attended, pm: 'absent');
        final afternoonOnly = AttendanceSessions(am: 'absent', pm: attended);
        expect(morningOnly.dayStatus('present'), 'half_day');
        expect(afternoonOnly.dayStatus('late'), 'half_day');
        expect(afternoonOnly.description, contains('AM: Absent'));
        expect(
          afternoonOnly.description,
          contains('PM: ${attendanceStatusLabel(attended)}'),
        );
      }
      expect(
        const AttendanceSessions(am: 'present').dayStatus('present'),
        'present',
      );
      expect(
        const AttendanceSessions(am: 'present').description,
        'AM: Present • PM: Pending',
      );
      expect(
        const AttendanceSessions(
          am: 'excused',
          pm: 'present',
        ).dayStatus('excused'),
        'excused',
      );
      expect(const AttendanceSessions().hasDetails, isFalse);
      expect(const AttendanceSessions().dayStatus('Late'), 'late');
    },
  );

  test(
    'student and parent responses preserve server session results and totals',
    () {
      final student = StudentAttendanceRecord.fromJson(afternoonOnly);
      final parent = ParentAttendanceRecord.fromJson(afternoonOnly);
      expect(student.sessions.description, 'AM: Absent • PM: Present');
      expect(parent.sessions.description, student.sessions.description);
      final today = TodayAttendance.fromJson(afternoonOnly);
      final dashboard = ParentChildDashboard.fromJson({
        'today': afternoonOnly,
        'totals': {'half_day': 2},
      });
      expect(today.sessions.dayStatus(today.status), 'half_day');
      expect(
        dashboard.todaySessions.dayStatus(dashboard.todayStatus),
        'half_day',
      );
      expect(dashboard.halfDay, 2);
      expect(AttendanceTotals.fromJson({'half_day': 2}).halfDay, 2);
      expect(AttendanceRecordSummary.fromJson({'half_day': 2}).halfDay, 2);
      expect(ParentAttendanceSummary.fromJson({'half_day': 2}).halfDay, 2);
      expect(
        StudentAttendanceRecord.fromJson({'status': 'present'})
            .sessions
            .hasDetails,
        isFalse,
      );
      expect(
        ParentAttendanceRecord.fromJson({'status': 'late'}).sessions.hasDetails,
        isFalse,
      );
    },
  );

  for (final parent in [false, true]) {
    testWidgets(
      '${parent ? 'parent' : 'student'} attendance shows half-day sessions on a small phone',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: parent
                ? ParentAttendancePage(
                    accessToken: 'session',
                    repository: _ParentRepository(),
                    child: ParentChild.fromJson({'id': 42, 'name': 'Student'}),
                    onChangeChild: () {},
                  )
                : StudentAttendancePage(
                    accessToken: 'session',
                    repository: _StudentRepository(),
                  ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Half-day').last, 200);
        expect(find.textContaining('AM: Absent • PM: Present'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

class _StudentRepository implements StudentAttendanceRepository {
  @override
  Future<StudentAttendanceResult> fetchAttendance({
    required String accessToken,
    int page = 1,
    int perPage = 20,
  }) async => StudentAttendanceResult.fromLegacyJson({
    'summary': {'half_day': 1},
    'history': {
      'data': [afternoonOnly],
      'current_page': 1,
      'last_page': 1,
    },
  });
}

class _ParentRepository extends Fake implements ParentRepository {
  @override
  Future<ParentAttendanceResult> fetchAttendance({
    required String accessToken,
    required int childId,
    int page = 1,
    int perPage = 20,
    bool absencesOnly = false,
  }) async => ParentAttendanceResult.fromJson({
    'data': [afternoonOnly],
    'meta': {
      'summary': {'half_day': 1},
    },
  });
}
