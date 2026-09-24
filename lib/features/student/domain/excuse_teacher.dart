class ExcuseTeacher {
  const ExcuseTeacher({required this.id, required this.name});

  factory ExcuseTeacher.fromJson(Map<String, dynamic> json) {
    return ExcuseTeacher(
      id: (json['id'] as num).toInt(),
      name: '${json['name'] ?? ''}'.trim(),
    );
  }

  final int id;
  final String name;
}
