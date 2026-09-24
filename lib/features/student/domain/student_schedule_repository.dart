import 'student_schedule.dart';

abstract interface class StudentScheduleRepository {
  Future<List<StudentSchedule>> fetchSchedules({required String accessToken});

  Future<StudentSchedule> createSchedule({
    required String accessToken,
    required StudentScheduleDraft draft,
  });

  Future<StudentSchedule> updateSchedule({
    required String accessToken,
    required int id,
    required StudentScheduleDraft draft,
  });

  Future<void> deleteSchedule({required String accessToken, required int id});
}
