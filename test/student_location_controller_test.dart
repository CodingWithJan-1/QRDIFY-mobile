import 'package:flutter_test/flutter_test.dart';
import 'package:qrdify/core/network/api_exception.dart';
import 'package:qrdify/features/student/domain/device_location_service.dart';
import 'package:qrdify/features/student/domain/student_location.dart';
import 'package:qrdify/features/student/domain/student_location_repository.dart';
import 'package:qrdify/features/student/presentation/controllers/student_location_controller.dart';

void main() {
  test('uses the production fifteen-minute reporting interval', () {
    final controller = StudentLocationController(
      _FakeLocationRepository(),
      _FakeLocationService(
        permission: DeviceLocationPermission.whileInUse,
        location: _location(.5, DateTime.utc(2026, 9, 9, 2, 15)),
      ),
      'student-token',
    );

    expect(controller.reportInterval, const Duration(minutes: 15));
    controller.dispose();
  });

  test('records consent before starting location sharing', () async {
    final locationService = _FakeLocationService(
      permission: DeviceLocationPermission.whileInUse,
      location: _location(.5, DateTime.utc(2026, 9, 9, 2, 15)),
    );
    final repository = _FakeLocationRepository(consentEnabled: false);
    final controller = StudentLocationController(
      repository,
      locationService,
      'student-token',
    );

    await controller.start();

    expect(repository.consentUpdates, [true]);
    expect(controller.serverConsentEnabled, isTrue);
    await controller.stop();
    expect(repository.consentUpdates, [true, false]);
    controller.dispose();
  });

  test('does not capture or upload when permission is denied', () async {
    final locationService = _FakeLocationService(
      permission: DeviceLocationPermission.denied,
    );
    final repository = _FakeLocationRepository();
    final controller = StudentLocationController(
      repository,
      locationService,
      'student-token',
    );

    await controller.start();

    expect(controller.status, StudentLocationStatus.permissionDenied);
    expect(locationService.captureCount, 0);
    expect(repository.samples, isEmpty);
    controller.dispose();
  });

  test('checks an inside position locally without uploading it', () async {
    final recordedAt = DateTime.utc(2026, 9, 9, 2, 15, 30);
    final locationService = _FakeLocationService(
      permission: DeviceLocationPermission.whileInUse,
      location: DeviceLocation(
        latitude: .5,
        longitude: .5,
        accuracyMeters: 12.4,
        recordedAt: recordedAt,
      ),
    );
    final repository = _FakeLocationRepository();
    final controller = StudentLocationController(
      repository,
      locationService,
      'student-token',
      createSampleId: () => 'sample-uuid',
    );

    await controller.start();

    expect(locationService.captureCount, 1);
    expect(repository.samples, isEmpty);
    expect(controller.boundaryState, BoundaryState.inside);
    expect(controller.lastReportedAt, isNull);

    await controller.stop();
    controller.dispose();
  });

  test('uploads two outside readings only after local confirmation', () async {
    var id = 0;
    final locationService = _FakeLocationService(
      permission: DeviceLocationPermission.whileInUse,
      locations: [
        _location(2, DateTime.utc(2026, 9, 9, 2, 15)),
        _location(2.1, DateTime.utc(2026, 9, 9, 2, 17)),
      ],
    );
    final repository = _FakeLocationRepository();
    final controller = StudentLocationController(
      repository,
      locationService,
      'student-token',
      createSampleId: () => 'sample-${++id}',
    );

    await controller.start();
    expect(repository.samples, isEmpty);

    await controller.checkNow();

    expect(repository.samples, hasLength(2));
    expect(repository.accessTokens, everyElement('student-token'));
    expect(controller.boundaryState, BoundaryState.outside);
    expect(controller.latestReport?.breachStatus, 'open');
    expect(controller.lastReportedAt, isNotNull);
    controller.dispose();
  });

  test('one outside GPS jump followed by inside does not upload', () async {
    final locationService = _FakeLocationService(
      permission: DeviceLocationPermission.whileInUse,
      locations: [
        _location(2, DateTime.utc(2026, 9, 9, 2, 15)),
        _location(.5, DateTime.utc(2026, 9, 9, 2, 17)),
      ],
    );
    final repository = _FakeLocationRepository();
    final controller = StudentLocationController(
      repository,
      locationService,
      'student-token',
    );

    await controller.start();
    await controller.checkNow();

    expect(repository.samples, isEmpty);
    expect(controller.boundaryState, BoundaryState.inside);
    controller.dispose();
  });

  test('uploads two inside readings to resolve an active alert', () async {
    final locationService = _FakeLocationService(
      permission: DeviceLocationPermission.whileInUse,
      locations: [
        _location(.5, DateTime.utc(2026, 9, 9, 2, 15)),
        _location(.6, DateTime.utc(2026, 9, 9, 2, 17)),
      ],
    );
    final repository = _FakeLocationRepository(activeBreach: true);
    final controller = StudentLocationController(
      repository,
      locationService,
      'student-token',
    );

    await controller.start();
    expect(repository.samples, isEmpty);
    await controller.checkNow();

    expect(repository.samples, hasLength(2));
    expect(controller.latestReport?.breachStatus, 'resolved');
    expect(controller.boundaryState, BoundaryState.inside);
    controller.dispose();
  });

  test(
    'uses server evaluation when the policy endpoint is unavailable',
    () async {
      final locationService = _FakeLocationService(
        permission: DeviceLocationPermission.whileInUse,
        locations: [
          _location(.5, DateTime.utc(2026, 9, 9, 2, 15)),
          _location(.6, DateTime.utc(2026, 9, 9, 2, 17)),
        ],
      );
      final repository = _FakeLocationRepository(policyUnavailable: true);
      final controller = StudentLocationController(
        repository,
        locationService,
        'student-token',
      );

      await controller.start();
      await controller.checkNow();

      expect(repository.policyRequestCount, 1);
      expect(repository.samples, hasLength(2));
      expect(controller.errorMessage, isNull);
      controller.dispose();
    },
  );
}

DeviceLocation _location(double coordinate, DateTime recordedAt) =>
    DeviceLocation(
      latitude: coordinate,
      longitude: coordinate,
      accuracyMeters: 10,
      recordedAt: recordedAt,
    );

class _FakeLocationRepository implements StudentLocationRepository {
  _FakeLocationRepository({
    this.activeBreach = false,
    this.policyUnavailable = false,
    this.consentEnabled = true,
  });

  final bool activeBreach;
  final bool policyUnavailable;
  bool consentEnabled;
  int policyRequestCount = 0;
  final List<String> accessTokens = [];
  final List<StudentLocationSample> samples = [];
  final List<bool> consentUpdates = [];

  @override
  Future<StudentLocationConsent> fetchConsent({
    required String accessToken,
  }) async => StudentLocationConsent(
    enabled: consentEnabled,
    policyVersion: 'test-policy',
  );

  @override
  Future<StudentLocationConsent> updateConsent({
    required String accessToken,
    required bool enabled,
    required String policyVersion,
  }) async {
    consentEnabled = enabled;
    consentUpdates.add(enabled);
    return StudentLocationConsent(
      enabled: enabled,
      policyVersion: policyVersion,
    );
  }

  @override
  Future<StudentGeofencePolicy> fetchGeofencePolicy({
    required String accessToken,
  }) async {
    policyRequestCount++;
    if (policyUnavailable) {
      throw const ApiException(
        message: 'The requested information was not found.',
        statusCode: 404,
      );
    }
    return StudentGeofencePolicy(
      enabled: true,
      polygon: [
        GeofencePoint(latitude: 0, longitude: 0),
        GeofencePoint(latitude: 0, longitude: 1),
        GeofencePoint(latitude: 1, longitude: 1),
        GeofencePoint(latitude: 1, longitude: 0),
      ],
      boundaryBufferMeters: 15,
      maxAccuracyMeters: 100,
      outsideConfirmations: 2,
      insideConfirmations: 2,
      confirmationWindow: Duration(minutes: 5),
      trackingWindowActive: true,
      activeBreach: activeBreach,
      version: 1,
    );
  }

  @override
  Future<StudentLocationReport> reportLocation({
    required String accessToken,
    required StudentLocationSample sample,
  }) async {
    accessTokens.add(accessToken);
    samples.add(sample);
    final boundaryState =
        sample.latitude >= 0 &&
            sample.latitude <= 1 &&
            sample.longitude >= 0 &&
            sample.longitude <= 1
        ? BoundaryState.inside
        : BoundaryState.outside;
    return StudentLocationReport(
      accepted: true,
      boundaryState: boundaryState,
      trackingWindowActive: true,
      breachEventId: samples.length >= 2 ? 1 : null,
      breachStatus: samples.length >= 2
          ? boundaryState == BoundaryState.inside
                ? 'resolved'
                : 'open'
          : activeBreach
          ? 'open'
          : null,
    );
  }
}

class _FakeLocationService implements DeviceLocationService {
  _FakeLocationService({
    required this.permission,
    this.location,
    this.locations,
  });

  final DeviceLocationPermission permission;
  final DeviceLocation? location;
  final List<DeviceLocation>? locations;
  int captureCount = 0;

  @override
  Future<DeviceLocationPermission> checkPermission() async => permission;

  @override
  Future<DeviceLocation> getCurrentLocation() async {
    captureCount++;
    return locations == null ? location! : locations!.removeAt(0);
  }

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<void> startBackgroundTracking(Duration interval) async {}

  @override
  Future<void> stopBackgroundTracking() async {}

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<DeviceLocationPermission> requestPermission() async => permission;
}
