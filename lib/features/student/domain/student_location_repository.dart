import 'student_location.dart';

abstract interface class StudentLocationRepository {
  Future<StudentLocationConsent> fetchConsent({required String accessToken});

  Future<StudentLocationConsent> updateConsent({
    required String accessToken,
    required bool enabled,
    required String policyVersion,
  });

  Future<StudentGeofencePolicy> fetchGeofencePolicy({
    required String accessToken,
  });

  Future<StudentLocationReport> reportLocation({
    required String accessToken,
    required StudentLocationSample sample,
  });
}
