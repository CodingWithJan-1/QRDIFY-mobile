import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/parent_attendance.dart';
import '../domain/parent_child.dart';
import '../domain/parent_dashboard.dart';
import '../domain/parent_excuse_letter.dart';
import '../domain/parent_repository.dart';

class ParentRepositoryImpl implements ParentRepository {
  const ParentRepositoryImpl(this._apiClient, this._useMobileApi);

  final ApiClient _apiClient;
  final bool _useMobileApi;

  String get _basePath => _useMobileApi ? 'parent' : 'mobile/v1/parent';

  @override
  Future<List<ParentChild>> fetchChildren({required String accessToken}) async {
    final response = await _apiClient.get(
      '$_basePath/children?per_page=50',
      token: accessToken,
    );
    final json = _map(response, 'Invalid linked children response.');
    final data = json['data'];
    if (data is! List) {
      throw const FormatException('Missing linked children data.');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(ParentChild.fromJson)
        .toList();
  }

  @override
  Future<ParentChildDashboard> fetchDashboard({
    required String accessToken,
    required int childId,
    required DateTime month,
  }) async {
    final monthValue =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final response = await _apiClient.get(
      '$_basePath/children/$childId/dashboard?month=$monthValue',
      token: accessToken,
    );
    final json = _map(response, 'Invalid Parent dashboard response.');
    return ParentChildDashboard.fromJson(
      _map(json['data'], 'Missing Parent dashboard data.'),
    );
  }

  @override
  Future<ParentAttendanceResult> fetchAttendance({
    required String accessToken,
    required int childId,
    int page = 1,
    int perPage = 20,
    bool absencesOnly = false,
  }) async {
    final route = absencesOnly ? 'absences' : 'attendance';
    final response = await _apiClient.get(
      '$_basePath/children/$childId/$route?page=$page&per_page=$perPage',
      token: accessToken,
    );
    return ParentAttendanceResult.fromJson(
      _map(response, 'Invalid Parent attendance response.'),
    );
  }

  @override
  Future<List<ParentExcuseLetter>> fetchExcuseLetters({
    required String accessToken,
    required int childId,
  }) async {
    final letters = <int, ParentExcuseLetter>{};
    for (var page = 1; page <= 20; page++) {
      final response = await _apiClient.get(
        '$_basePath/children/$childId/excuse-letters?page=$page&per_page=50',
        token: accessToken,
      );
      final json = _map(response, 'Invalid excuse letters response.');
      final data = json['data'];
      if (data is! List || data.length > 50) {
        throw const FormatException('Invalid excuse letters page.');
      }
      for (final value in data) {
        final letter = ParentExcuseLetter.fromJson(
          _map(value, 'Invalid excuse letter.'),
        );
        letters.putIfAbsent(letter.id, () => letter);
      }
      // Older API implementations may omit pagination metadata.
      if (json['meta'] == null) return letters.values.toList();
      final meta = _map(json['meta'], 'Invalid excuse letters pagination.');
      final current = meta['current_page'];
      final last = meta['last_page'];
      if (current != page || last is! int || last < 1) {
        throw const FormatException('Invalid excuse letters pagination.');
      }
      if (last > 20) {
        throw const ApiException(
          message: 'Too many excuse letters to load on this phone. Contact the school office.',
          code: 'excuse_history_too_large',
        );
      }
      if (page >= last) return letters.values.toList();
    }
    throw const FormatException('Excuse letters pagination did not finish.');
  }

  @override
  Future<ParentExcuseLetter> submitExcuseLetter({
    required String accessToken,
    required int childId,
    required String title,
    required DateTime absentDate,
    required String reason,
    List<int>? attachmentBytes,
    String? attachmentName,
  }) async {
    final response = await _apiClient.postMultipart(
      '$_basePath/children/$childId/excuse-letters',
      token: accessToken,
      fields: {
        'title': title,
        'absent_date':
            '${absentDate.year}-${absentDate.month.toString().padLeft(2, '0')}-${absentDate.day.toString().padLeft(2, '0')}',
        'reason': reason,
      },
      fileField: attachmentBytes == null ? null : 'attachment',
      fileBytes: attachmentBytes,
      fileName: attachmentName,
    );
    final json = _map(response, 'Invalid excuse letter response.');
    return ParentExcuseLetter.fromJson(
      _map(json['letter'], 'Missing submitted excuse letter.'),
    );
  }

  Map<String, dynamic> _map(Object? value, String message) {
    if (value is Map<String, dynamic>) return value;
    throw FormatException(message);
  }
}
