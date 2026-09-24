class ParentAttendanceResult {
  const ParentAttendanceResult({
    required this.records,
    required this.summary,
    required this.currentPage,
    required this.lastPage,
  });

  factory ParentAttendanceResult.fromJson(Map<String, dynamic> json) {
    final meta = _map(json['meta']);
    final data = json['data'];
    return ParentAttendanceResult(
      records: data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(ParentAttendanceRecord.fromJson)
                .toList()
          : const [],
      summary: ParentAttendanceSummary.fromJson(_map(meta['summary'])),
      currentPage: (meta['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
    );
  }

  final List<ParentAttendanceRecord> records;
  final ParentAttendanceSummary summary;
  final int currentPage;
  final int lastPage;
}

class ParentAttendanceSummary {
  const ParentAttendanceSummary({
    required this.total,
    required this.present,
    required this.absent,
    required this.late,
    required this.presentPercentage,
  });

  factory ParentAttendanceSummary.fromJson(Map<String, dynamic> json) {
    return ParentAttendanceSummary(
      total: (json['total'] as num?)?.toInt() ?? 0,
      present: (json['present'] as num?)?.toInt() ?? 0,
      absent: (json['absent'] as num?)?.toInt() ?? 0,
      late: (json['late'] as num?)?.toInt() ?? 0,
      presentPercentage: (json['present_percentage'] as num?)?.toDouble() ?? 0,
    );
  }

  final int total;
  final int present;
  final int absent;
  final int late;
  final double presentPercentage;
}

class ParentAttendanceRecord {
  const ParentAttendanceRecord({
    required this.id,
    required this.date,
    required this.status,
    this.timeIn,
    this.timeOut,
    this.remarks,
  });

  factory ParentAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return ParentAttendanceRecord(
      id: (json['id'] as num?)?.toInt(),
      date: '${json['date'] ?? ''}'.split('T').first,
      status: '${json['status'] ?? 'unknown'}'.toLowerCase(),
      timeIn: _text(json['time_in']),
      timeOut: _text(json['time_out']),
      remarks: _text(json['remarks']),
    );
  }

  final int? id;
  final String date;
  final String status;
  final String? timeIn;
  final String? timeOut;
  final String? remarks;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
