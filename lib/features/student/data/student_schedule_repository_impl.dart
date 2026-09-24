import '../../../core/network/api_client.dart';
import '../domain/student_schedule.dart';
import '../domain/student_schedule_repository.dart';

class StudentScheduleRepositoryImpl implements StudentScheduleRepository {
  const StudentScheduleRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<StudentSchedule>> fetchSchedules({
    required String accessToken,
  }) async {
    final response = await _apiClient.get(
      'student/schedules',
      token: accessToken,
    );
    if (response is! List) {
      throw const FormatException('Invalid schedule response.');
    }
    return response
        .map((item) => StudentSchedule.fromJson(_asMap(item)))
        .toList();
  }

  @override
  Future<StudentSchedule> createSchedule({
    required String accessToken,
    required StudentScheduleDraft draft,
  }) async {
    final response = await _apiClient.post(
      'student/schedules',
      token: accessToken,
      body: draft.toJson(),
    );
    return StudentSchedule.fromJson(_scheduleFrom(response));
  }

  @override
  Future<StudentSchedule> updateSchedule({
    required String accessToken,
    required int id,
    required StudentScheduleDraft draft,
  }) async {
    final response = await _apiClient.put(
      'student/schedules/$id',
      token: accessToken,
      body: draft.toJson(),
    );
    return StudentSchedule.fromJson(_scheduleFrom(response));
  }

  @override
  Future<void> deleteSchedule({
    required String accessToken,
    required int id,
  }) async {
    await _apiClient.delete('student/schedules/$id', token: accessToken);
  }

  Map<String, dynamic> _scheduleFrom(Object? response) {
    final json = _asMap(response);
    return _asMap(json['schedule'] ?? json['data']);
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    throw const FormatException('QRDify returned an invalid schedule.');
  }
}
