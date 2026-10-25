class AttendanceSessions {
  const AttendanceSessions({this.am, this.pm});

  factory AttendanceSessions.fromJson(Map<String, dynamic> json) =>
      AttendanceSessions(
        am: _status(json['am_status']),
        pm: _status(json['pm_status']),
      );

  final String? am;
  final String? pm;

  bool get hasDetails => am != null || pm != null;

  String dayStatus(String fallback) {
    const attended = {'present', 'early', 'late'};
    if ((am == 'absent' && attended.contains(pm)) ||
        (pm == 'absent' && attended.contains(am))) {
      return 'half_day';
    }
    return fallback.toLowerCase();
  }

  String get description =>
      'AM: ${attendanceStatusLabel(am ?? 'pending')} • '
      'PM: ${attendanceStatusLabel(pm ?? 'pending')}';
}

String attendanceStatusLabel(String status) {
  if (status == 'half_day') return 'Half-day';
  if (status.isEmpty) return 'Unknown';
  return '${status[0].toUpperCase()}${status.substring(1).replaceAll('_', ' ')}';
}

String? _status(Object? value) {
  final status = value?.toString().trim().toLowerCase();
  return status == null || status.isEmpty ? null : status;
}
