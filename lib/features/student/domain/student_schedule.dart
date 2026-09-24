class StudentSchedule {
  const StudentSchedule({
    required this.id,
    required this.title,
    required this.date,
    required this.startTime,
    required this.isAlarm,
    this.description,
    this.endTime,
  });

  factory StudentSchedule.fromJson(Map<String, dynamic> json) {
    return StudentSchedule(
      id: (json['id'] as num).toInt(),
      title: '${json['title'] ?? ''}',
      description: _optionalText(json['description']),
      date: '${json['date'] ?? ''}'.split('T').first,
      startTime: '${json['start_time'] ?? ''}',
      endTime: _optionalText(json['end_time']),
      isAlarm: json['is_alarm'] == true || json['is_alarm'] == 1,
    );
  }

  final int id;
  final String title;
  final String? description;
  final String date;
  final String startTime;
  final String? endTime;
  final bool isAlarm;
}

class StudentScheduleDraft {
  const StudentScheduleDraft({
    required this.title,
    required this.date,
    required this.startTime,
    required this.isAlarm,
    this.description,
    this.endTime,
  });

  final String title;
  final String? description;
  final String date;
  final String startTime;
  final String? endTime;
  final bool isAlarm;

  Map<String, Object?> toJson() => {
    'title': title,
    'description': description,
    'date': date,
    'start_time': startTime,
    'end_time': endTime,
    'is_alarm': isAlarm,
  };
}

String? _optionalText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
