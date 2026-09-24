import '../../../core/network/api_client.dart';
import '../domain/student_attendance.dart';
import '../domain/student_attendance_repository.dart';

class StudentAttendanceRepositoryImpl implements StudentAttendanceRepository {
  const StudentAttendanceRepositoryImpl(this._apiClient, this._useMobileApi);

  final ApiClient _apiClient;
  final bool _useMobileApi;

  @override
  Future<StudentAttendanceResult> fetchAttendance({
    required String accessToken,
    int page = 1,
    int perPage = 20,
  }) async {
    final path = _useMobileApi
        ? 'student/attendance?page=$page&per_page=$perPage'
        : 'student/attendance-record?page=$page&per_page=$perPage';
    final response = await _apiClient.get(path, token: accessToken);
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid attendance response.');
    }

    return _useMobileApi
        ? StudentAttendanceResult.fromMobileJson(response)
        : StudentAttendanceResult.fromLegacyJson(response);
  }
}
