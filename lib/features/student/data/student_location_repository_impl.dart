import '../../../core/network/api_client.dart';
import '../domain/student_location.dart';
import '../domain/student_location_repository.dart';

class StudentLocationRepositoryImpl implements StudentLocationRepository {
  const StudentLocationRepositoryImpl(this._apiClient, this._useMobileApi);

  final ApiClient _apiClient;
  final bool _useMobileApi;

  String get _mobilePrefix => _useMobileApi ? '' : 'mobile/v1/';

  @override
  Future<StudentLocationConsent> fetchConsent({
    required String accessToken,
  }) async {
    final response = await _apiClient.get(
      '${_mobilePrefix}student/location-consent',
      token: accessToken,
    );
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid location consent response.');
    }
    return StudentLocationConsent.fromJson(response);
  }

  @override
  Future<StudentLocationConsent> updateConsent({
    required String accessToken,
    required bool enabled,
    required String policyVersion,
  }) async {
    final response = await _apiClient.put(
      '${_mobilePrefix}student/location-consent',
      token: accessToken,
      body: {'enabled': enabled, 'policy_version': policyVersion},
    );
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid location consent response.');
    }
    return StudentLocationConsent.fromJson(response);
  }

  @override
  Future<StudentGeofencePolicy> fetchGeofencePolicy({
    required String accessToken,
  }) async {
    final response = await _apiClient.get(
      '${_mobilePrefix}student/geofence-policy',
      token: accessToken,
    );
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid geofence policy response.');
    }
    return StudentGeofencePolicy.fromJson(response);
  }

  @override
  Future<StudentLocationReport> reportLocation({
    required String accessToken,
    required StudentLocationSample sample,
  }) async {
    final response = await _apiClient.post(
      '${_mobilePrefix}student/location-samples',
      token: accessToken,
      headers: {'Idempotency-Key': sample.clientSampleId},
      body: sample.toMobileJson(),
    );

    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid student location response.');
    }

    return StudentLocationReport.fromMobileJson(response);
  }
}
