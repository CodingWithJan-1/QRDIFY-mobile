class ParentChild {
  const ParentChild({
    required this.id,
    required this.name,
    required this.relationship,
    required this.canViewLocation,
    required this.canSubmitExcuses,
    required this.historyVisibleFrom,
    this.photoUrl,
    this.grade,
    this.section,
  });

  factory ParentChild.fromJson(Map<String, dynamic> json) {
    final link = _map(json['link']);
    return ParentChild(
      id: (json['id'] as num).toInt(),
      name: '${json['name'] ?? 'Student'}',
      photoUrl: _text(json['photo_url']),
      grade: _text(json['grade']),
      section: _text(json['section']),
      relationship: '${link['relationship'] ?? 'guardian'}',
      canViewLocation: link['can_view_location'] == true,
      canSubmitExcuses: link['can_submit_excuses'] == true,
      historyVisibleFrom: '${link['history_visible_from'] ?? ''}',
    );
  }

  final int id;
  final String name;
  final String? photoUrl;
  final String? grade;
  final String? section;
  final String relationship;
  final bool canViewLocation;
  final bool canSubmitExcuses;
  final String historyVisibleFrom;

  String get classLabel => [
    grade,
    section,
  ].whereType<String>().where((value) => value.isNotEmpty).join(' • ');
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
