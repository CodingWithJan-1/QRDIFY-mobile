import 'parent_attendance.dart';
import 'parent_child.dart';
import 'parent_dashboard.dart';

abstract interface class ParentRepository {
  Future<List<ParentChild>> fetchChildren({required String accessToken});

  Future<ParentChildDashboard> fetchDashboard({
    required String accessToken,
    required int childId,
    required DateTime month,
  });

  Future<ParentAttendanceResult> fetchAttendance({
    required String accessToken,
    required int childId,
    int page = 1,
    int perPage = 20,
    bool absencesOnly = false,
  });
}
