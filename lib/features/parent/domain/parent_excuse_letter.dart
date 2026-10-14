class ParentExcuseLetter {
  const ParentExcuseLetter({
    required this.id,
    required this.title,
    required this.absentDate,
    required this.reason,
    required this.status,
    this.teacherName,
    this.submittedByName,
    this.attachmentPath,
  });

  factory ParentExcuseLetter.fromJson(Map<String, dynamic> json) {
    final teacher = json['teacher'];
    final parent = json['submitted_by_parent'];
    return ParentExcuseLetter(
      id: (json['id'] as num).toInt(),
      title: '${json['title'] ?? 'Excuse letter'}',
      absentDate: '${json['absent_date'] ?? ''}'.split('T').first,
      reason: '${json['reason'] ?? ''}',
      status: '${json['status'] ?? 'pending'}'.toLowerCase(),
      teacherName: teacher is Map<String, dynamic>
          ? teacher['name']?.toString()
          : null,
      submittedByName: parent is Map<String, dynamic>
          ? parent['name']?.toString()
          : null,
      attachmentPath: json['attachment_path']?.toString(),
    );
  }

  final int id;
  final String title;
  final String absentDate;
  final String reason;
  final String status;
  final String? teacherName;
  final String? submittedByName;
  final String? attachmentPath;
}
