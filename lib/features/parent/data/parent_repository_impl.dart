import '../../../core/network/api_client.dart';
import '../domain/parent_attendance.dart';
import '../domain/parent_child.dart';
import '../domain/parent_dashboard.dart';
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

  Map<String, dynamic> _map(Object? value, String message) {
    if (value is Map<String, dynamic>) return value;
    throw FormatException(message);
  }
}
