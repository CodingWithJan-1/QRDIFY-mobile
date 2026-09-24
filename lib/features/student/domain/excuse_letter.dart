class ExcuseLetter {
  const ExcuseLetter({
    required this.id,
    required this.title,
    required this.absentDate,
    required this.reason,
    required this.status,
    this.teacherName,
    this.reviewNote,
    this.createdAt,
    this.attachmentPath,
  });

  factory ExcuseLetter.fromJson(Map<String, dynamic> json) {
    final teacher = json['teacher'];
    final teacherJson = teacher is Map<String, dynamic>
        ? teacher
        : const <String, dynamic>{};
    return ExcuseLetter(
      id: (json['id'] as num).toInt(),
      title: '${json['title'] ?? 'Excuse letter'}',
      absentDate: '${json['absent_date'] ?? ''}'.split('T').first,
      reason: '${json['reason'] ?? ''}',
      status: '${json['status'] ?? 'pending'}'.toLowerCase(),
      teacherName: _optionalText(teacherJson['name']),
      reviewNote: _optionalText(json['review_note']),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      attachmentPath: _optionalText(json['attachment_path']),
    );
  }

  final int id;
  final String title;
  final String absentDate;
  final String reason;
  final String status;
  final String? teacherName;
  final String? reviewNote;
  final DateTime? createdAt;
  final String? attachmentPath;
}

String? _optionalText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
