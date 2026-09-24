import 'package:flutter_test/flutter_test.dart';
import 'package:qrdify/features/notifications/domain/app_notification.dart';
import 'package:qrdify/features/parent/domain/parent_attendance.dart';
import 'package:qrdify/features/parent/domain/parent_child.dart';
import 'package:qrdify/features/parent/domain/parent_dashboard.dart';
import 'package:qrdify/features/student/domain/student_attendance.dart';
import 'package:qrdify/features/student/domain/student_dashboard.dart';
import 'package:qrdify/features/student/domain/student_schedule.dart';

void main() {
  test('parses the current Laravel attendance paginator', () {
    final result = StudentAttendanceResult.fromLegacyJson({
      'summary': {
        'total': 3,
        'present': 1,
        'absent': 1,
        'late': 1,
        'present_percentage': 33.3,
      },
      'history': {
        'current_page': 1,
        'last_page': 2,
        'total': 3,
        'data': [
          {
            'id': 8,
            'date': '2026-09-08T00:00:00.000000Z',
            'time_in': '08:01:00',
            'time_out': null,
            'status': 'Present',
            'remarks': null,
          },
        ],
      },
    });

    expect(result.summary.presentPercentage, 33.3);
    expect(result.lastPage, 2);
    expect(result.records.single.date, '2026-09-08');
    expect(result.records.single.status, 'present');
  });

  test('parses current Laravel schedules', () {
    final schedule = StudentSchedule.fromJson({
      'id': 12,
      'title': 'Review notes',
      'description': null,
      'date': '2026-09-09T00:00:00.000000Z',
      'start_time': '18:30:00',
      'end_time': null,
      'is_alarm': 1,
    });

    expect(schedule.date, '2026-09-09');
    expect(schedule.isAlarm, isTrue);
  });

  test('derives legacy dashboard late and excused totals from history', () {
    final dashboard = StudentDashboard.fromLegacyJson({
      'total_present': 2,
      'total_absent': 1,
      'today_status': 'Late',
      'history': [
        {'date': '2026-09-09T00:00:00.000000Z', 'status': 'Late'},
        {'date': '2026-09-08T00:00:00.000000Z', 'status': 'Excused'},
      ],
    }, month: '2026-09');

    expect(dashboard.totals.present, 2);
    expect(dashboard.totals.late, 1);
    expect(dashboard.totals.attended, 3);
    expect(dashboard.totals.absent, 1);
    expect(dashboard.totals.excused, 1);
    expect(dashboard.today.status, 'late');
  });

  test('parses Laravel notification data', () {
    final result = NotificationPageResult.fromJson({
      'current_page': 1,
      'last_page': 1,
      'data': [
        {
          'id': 'notification-id',
          'data': {
            'type': 'time_in',
            'title': 'Time In',
            'message': 'Attendance recorded.',
          },
          'read_at': null,
          'created_at': '2026-09-09T00:01:00Z',
        },
      ],
    });

    expect(result.items.single.type, 'time_in');
    expect(result.items.single.isRead, isFalse);
  });

  test('parses a linked child and its authorization settings', () {
    final child = ParentChild.fromJson({
      'id': 15,
      'name': 'Alex Student',
      'grade': 'Grade 6',
      'section': 'Rizal',
      'link': {
        'relationship': 'father',
        'can_view_location': false,
        'can_submit_excuses': true,
        'history_visible_from': '2026-06-01',
      },
    });

    expect(child.name, 'Alex Student');
    expect(child.classLabel, 'Grade 6 • Rizal');
    expect(child.canViewLocation, isFalse);
    expect(child.canSubmitExcuses, isTrue);
  });

  test('parses Parent dashboard totals', () {
    final dashboard = ParentChildDashboard.fromJson({
      'month': '2026-09',
      'summary_complete': false,
      'totals': {
        'present': 4,
        'late': 1,
        'attended': 5,
        'absent': 2,
        'excused': 1,
      },
      'today': {'status': 'early', 'time_in': '07:22:00'},
    });

    expect(dashboard.present, 4);
    expect(dashboard.attended, 5);
    expect(dashboard.absent, 2);
    expect(dashboard.todayStatus, 'early');
  });

  test('parses paginated Parent attendance', () {
    final result = ParentAttendanceResult.fromJson({
      'data': [
        {
          'id': 91,
          'date': '2026-09-07T00:00:00.000000Z',
          'status': 'Absent',
          'time_in': null,
          'time_out': null,
        },
      ],
      'meta': {
        'current_page': 1,
        'last_page': 1,
        'summary': {
          'total': 1,
          'present': 0,
          'absent': 1,
          'late': 0,
          'present_percentage': 0,
        },
      },
    });

    expect(result.records.single.date, '2026-09-07');
    expect(result.records.single.status, 'absent');
    expect(result.summary.absent, 1);
  });
}
