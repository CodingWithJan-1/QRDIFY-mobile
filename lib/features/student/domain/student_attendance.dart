class StudentAttendanceResult {
  const StudentAttendanceResult({
    required this.summary,
    required this.records,
    required this.currentPage,
    required this.lastPage,
    required this.totalRecords,
  });

  factory StudentAttendanceResult.fromLegacyJson(Map<String, dynamic> json) {
    final history = _map(json['history']);
    return StudentAttendanceResult(
      summary: AttendanceRecordSummary.fromJson(_map(json['summary'])),
      records: _list(history['data'])
          .map((item) => StudentAttendanceRecord.fromJson(_map(item)))
          .toList(),
      currentPage: _integer(history['current_page'], fallback: 1),
      lastPage: _integer(history['last_page'], fallback: 1),
      totalRecords: _integer(history['total']),
    );
  }

  factory StudentAttendanceResult.fromMobileJson(Map<String, dynamic> json) {
    final meta = _map(json['meta']);
    final records = _list(json['data'])
        .map((item) => StudentAttendanceRecord.fromJson(_map(item)))
        .toList();
    return StudentAttendanceResult(
      summary: AttendanceRecordSummary.fromJson(_map(meta['summary'])),
      records: records,
      currentPage: _integer(meta['current_page'], fallback: 1),
      lastPage: _integer(meta['last_page'], fallback: 1),
      totalRecords: _integer(meta['total'], fallback: records.length),
    );
  }

  final AttendanceRecordSummary summary;
  final List<StudentAttendanceRecord> records;
  final int currentPage;
  final int lastPage;
  final int totalRecords;
}

class AttendanceRecordSummary {
  const AttendanceRecordSummary({
    required this.total,
    required this.present,
    required this.absent,
    required this.late,
    required this.presentPercentage,
  });

  factory AttendanceRecordSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordSummary(
      total: _integer(json['total']),
      present: _integer(json['present']),
      absent: _integer(json['absent']),
      late: _integer(json['late']),
      presentPercentage: _decimal(json['present_percentage']),
    );
  }

  final int total;
  final int present;
  final int absent;
  final int late;
  final double presentPercentage;
}

class StudentAttendanceRecord {
  const StudentAttendanceRecord({
    required this.id,
    required this.date,
    required this.status,
    this.timeIn,
    this.timeOut,
    this.remarks,
  });

  factory StudentAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return StudentAttendanceRecord(
      id: (json['id'] as num?)?.toInt(),
      date: '${json['date'] ?? ''}'.split('T').first,
      status: '${json['status'] ?? 'unknown'}'.toLowerCase(),
      timeIn: _optionalText(json['time_in']),
      timeOut: _optionalText(json['time_out']),
      remarks: _optionalText(json['remarks']),
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

List<Object?> _list(Object? value) => value is List ? value : const [];

int _integer(Object? value, {int fallback = 0}) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

double _decimal(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

String? _optionalText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
