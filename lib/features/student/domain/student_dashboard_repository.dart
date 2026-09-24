import 'student_dashboard.dart';

abstract interface class StudentDashboardRepository {
  Future<StudentDashboard> fetchDashboard({
    required String accessToken,
    required DateTime month,
  });
}
