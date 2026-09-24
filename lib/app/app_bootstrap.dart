import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_session_store.dart';
import '../features/auth/data/auth_remote_data_source.dart';
import '../features/auth/data/auth_repository_impl.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/notifications/data/notification_repository_impl.dart';
import '../features/notifications/domain/notification_repository.dart';
import '../features/parent/data/parent_enrollment_repository_impl.dart';
import '../features/parent/data/parent_repository_impl.dart';
import '../features/parent/domain/parent_enrollment_repository.dart';
import '../features/parent/domain/parent_repository.dart';
import '../features/student/data/excuse_letter_repository_impl.dart';
import '../features/student/data/geolocator_location_service.dart';
import '../features/student/data/student_attendance_repository_impl.dart';
import '../features/student/data/student_dashboard_repository_impl.dart';
import '../features/student/data/student_location_repository_impl.dart';
import '../features/student/data/student_schedule_repository_impl.dart';
import '../features/student/domain/device_location_service.dart';
import '../features/student/domain/excuse_letter_repository.dart';
import '../features/student/domain/student_attendance_repository.dart';
import '../features/student/domain/student_dashboard_repository.dart';
import '../features/student/domain/student_location_repository.dart';
import '../features/student/domain/student_schedule_repository.dart';

abstract final class AppBootstrap {
  static AppDependencies create() {
    final config = AppConfig.fromEnvironment();
    final apiClient = ApiClient(baseUrl: config.apiBaseUrl);
    final sessionStore = SecureSessionStore();
    final remoteDataSource = AuthRemoteDataSource(
      apiClient,
      config.useMobileApi,
    );
    final repository = AuthRepositoryImpl(
      remoteDataSource,
      sessionStore,
      apiClient,
    );

    return AppDependencies(
      authController: AuthController(repository),
      studentDashboardRepository: StudentDashboardRepositoryImpl(
        apiClient,
        config.useMobileApi,
      ),
      studentAttendanceRepository: StudentAttendanceRepositoryImpl(
        apiClient,
        config.useMobileApi,
      ),
      studentScheduleRepository: StudentScheduleRepositoryImpl(apiClient),
      studentLocationRepository: StudentLocationRepositoryImpl(
        apiClient,
        config.useMobileApi,
      ),
      deviceLocationService: GeolocatorLocationService(),
      excuseLetterRepository: ExcuseLetterRepositoryImpl(
        apiClient,
        config.useMobileApi,
      ),
      notificationRepository: NotificationRepositoryImpl(
        apiClient,
        config.useMobileApi,
      ),
      parentRepository: ParentRepositoryImpl(apiClient, config.useMobileApi),
      parentEnrollmentRepository: ParentEnrollmentRepositoryImpl(
        apiClient,
        config.useMobileApi,
      ),
    );
  }
}

class AppDependencies {
  const AppDependencies({
    required this.authController,
    required this.studentDashboardRepository,
    required this.studentAttendanceRepository,
    required this.studentScheduleRepository,
    required this.studentLocationRepository,
    required this.deviceLocationService,
    required this.excuseLetterRepository,
    required this.notificationRepository,
    required this.parentRepository,
    required this.parentEnrollmentRepository,
  });

  final AuthController authController;
  final StudentDashboardRepository studentDashboardRepository;
  final StudentAttendanceRepository studentAttendanceRepository;
  final StudentScheduleRepository studentScheduleRepository;
  final StudentLocationRepository studentLocationRepository;
  final DeviceLocationService deviceLocationService;
  final ExcuseLetterRepository excuseLetterRepository;
  final NotificationRepository notificationRepository;
  final ParentRepository parentRepository;
  final ParentEnrollmentRepository parentEnrollmentRepository;
}
