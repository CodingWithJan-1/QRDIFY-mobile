class ParentChildDashboard {
  const ParentChildDashboard({
    required this.month,
    required this.summaryComplete,
    required this.present,
    required this.late,
    required this.attended,
    required this.absent,
    required this.excused,
    required this.todayStatus,
    required this.todayTimeIn,
  });

  factory ParentChildDashboard.fromJson(Map<String, dynamic> json) {
    final totals = _map(json['totals']);
    final today = _map(json['today']);
    int count(String key) => (totals[key] as num?)?.toInt() ?? 0;

    return ParentChildDashboard(
      month: '${json['month'] ?? ''}',
      summaryComplete: json['summary_complete'] == true,
      present: count('present'),
      late: count('late'),
      attended: count('attended'),
      absent: count('absent'),
      excused: count('excused'),
      todayStatus: '${today['status'] ?? 'pending'}'.toLowerCase(),
      todayTimeIn: _text(today['time_in']),
    );
  }

  final String month;
  final bool summaryComplete;
  final int present;
  final int late;
  final int attended;
  final int absent;
  final int excused;
  final String todayStatus;
  final String? todayTimeIn;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
