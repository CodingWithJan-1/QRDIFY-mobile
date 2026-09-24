import 'student_attendance.dart';

abstract interface class StudentAttendanceRepository {
  Future<StudentAttendanceResult> fetchAttendance({
    required String accessToken,
    int page = 1,
    int perPage = 20,
  });
}
