class StudentDashboard {
  const StudentDashboard({
    required this.month,
    required this.timezone,
    required this.summaryComplete,
    required this.totals,
    required this.today,
    required this.unreadNotifications,
  });

  factory StudentDashboard.fromJson(Map<String, dynamic> json) {
    return StudentDashboard(
      month: json['month'] as String? ?? '',
      timezone: json['timezone'] as String? ?? 'Asia/Manila',
      summaryComplete: json['summary_complete'] as bool? ?? false,
      totals: AttendanceTotals.fromJson(_map(json['totals'])),
      today: TodayAttendance.fromJson(_map(json['today'])),
      unreadNotifications: (json['unread_notifications'] as num?)?.toInt() ?? 0,
    );
  }

  factory StudentDashboard.fromLegacyJson(
    Map<String, dynamic> json, {
    required String month,
  }) {
    final present = (json['total_present'] as num?)?.toInt() ?? 0;
    final absent = (json['total_absent'] as num?)?.toInt() ?? 0;
    final history = json['history'];
    Map<String, dynamic>? todayRecord;
    var late = 0;
    var excused = 0;
    if (history is List) {
      for (final item in history) {
        if (item is Map<String, dynamic>) {
          final status = '${item['status'] ?? ''}'.toLowerCase();
          if (status == 'late') late++;
          if (status == 'excused') excused++;
          if ('${item['date'] ?? ''}'.split('T').first == _todayDate()) {
            todayRecord = item;
          }
        }
      }
    }

    return StudentDashboard(
      month: month,
      timezone: 'Asia/Manila',
      summaryComplete: false,
      totals: AttendanceTotals(
        expectedDays: present + late + absent + excused,
        present: present,
        late: late,
        attended: present + late,
        absent: absent,
        excused: excused,
        pending: 0,
      ),
      today: TodayAttendance(
        date: _todayDate(),
        status: (json['today_status'] as String? ?? 'pending').toLowerCase(),
        attendanceId: (todayRecord?['id'] as num?)?.toInt(),
        timeIn: todayRecord?['time_in'] as String?,
        timeOut: todayRecord?['time_out'] as String?,
      ),
      unreadNotifications: 0,
    );
  }

  final String month;
  final String timezone;
  final bool summaryComplete;
  final AttendanceTotals totals;
  final TodayAttendance today;
  final int unreadNotifications;
}

class AttendanceTotals {
  const AttendanceTotals({
    required this.expectedDays,
    required this.present,
    required this.late,
    required this.attended,
    required this.absent,
    required this.excused,
    required this.pending,
  });

  factory AttendanceTotals.fromJson(Map<String, dynamic> json) {
    int value(String key) => (json[key] as num?)?.toInt() ?? 0;

    return AttendanceTotals(
      expectedDays: value('expected_days'),
      present: value('present'),
      late: value('late'),
      attended: value('attended'),
      absent: value('absent'),
      excused: value('excused'),
      pending: value('pending'),
    );
  }

  final int expectedDays;
  final int present;
  final int late;
  final int attended;
  final int absent;
  final int excused;
  final int pending;
}

class TodayAttendance {
  const TodayAttendance({
    required this.date,
    required this.status,
    this.attendanceId,
    this.timeIn,
    this.timeOut,
  });

  factory TodayAttendance.fromJson(Map<String, dynamic> json) {
    return TodayAttendance(
      date: json['date'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      attendanceId: (json['attendance_id'] as num?)?.toInt(),
      timeIn: json['time_in'] as String?,
      timeOut: json['time_out'] as String?,
    );
  }

  final String date;
  final String status;
  final int? attendanceId;
  final String? timeIn;
  final String? timeOut;
}

Map<String, dynamic> _map(Object? value) {
  return value is Map<String, dynamic> ? value : const <String, dynamic>{};
}

String _todayDate() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}
