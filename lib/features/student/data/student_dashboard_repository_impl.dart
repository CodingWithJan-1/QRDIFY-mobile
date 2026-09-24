import '../../../core/network/api_client.dart';
import '../domain/student_dashboard.dart';
import '../domain/student_dashboard_repository.dart';

class StudentDashboardRepositoryImpl implements StudentDashboardRepository {
  const StudentDashboardRepositoryImpl(this._apiClient, this._useMobileApi);

  final ApiClient _apiClient;
  final bool _useMobileApi;

  @override
  Future<StudentDashboard> fetchDashboard({
    required String accessToken,
    required DateTime month,
  }) async {
    final monthValue =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final response = await _apiClient.get(
      'student/dashboard?month=$monthValue',
      token: accessToken,
    );

    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid student dashboard response.');
    }

    if (_useMobileApi) {
      final data = response['data'];
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Missing student dashboard data.');
      }
      return StudentDashboard.fromJson(data);
    }

    return StudentDashboard.fromLegacyJson(response, month: monthValue);
  }
}
