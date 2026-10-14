// Regression tests for confirmed mobile audit findings; all requests are mocked.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qrdify/core/network/api_client.dart';
import 'package:qrdify/core/network/api_exception.dart';
import 'package:qrdify/core/storage/session_store.dart';
import 'package:qrdify/features/auth/data/auth_remote_data_source.dart';
import 'package:qrdify/features/auth/data/auth_repository_impl.dart';
import 'package:qrdify/features/auth/presentation/controllers/auth_controller.dart';
import 'package:qrdify/features/student/domain/device_location_service.dart';
import 'package:qrdify/features/student/domain/student_location.dart';
import 'package:qrdify/features/student/domain/student_location_repository.dart';
import 'package:qrdify/features/student/presentation/controllers/student_location_controller.dart';

void main() {
  test('cross-origin bearer request is blocked before HTTP dispatch', () async {
    final api = ApiClient(
      baseUrl: 'https://school.example/api/',
      httpClient: MockClient((request) async {
        fail('A cross-origin request must not reach the HTTP client.');
      }),
    );
    await expectLater(
      api.get(
        'https://external.invalid/collect',
        token: 'synthetic-audit-token',
      ),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'invalid_api_origin'),
      ),
    );
    api.close();
  });

  test(
    'API redirects are rejected rather than forwarding bearer credentials',
    () async {
      var calls = 0;
      final api = ApiClient(
        baseUrl: 'https://school.example/api/',
        httpClient: MockClient((request) async {
          calls++;
          expect(request.followRedirects, isFalse);
          return http.Response(
            '',
            307,
            headers: {'location': 'https://other.school.example/collect'},
          );
        }),
      );
      await expectLater(
        api.get('redirect', token: 'synthetic'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            307,
          ),
        ),
      );
      expect(calls, 1);
      api.close();
    },
  );

  test('oversized API responses are rejected before JSON parsing', () async {
    final api = ApiClient(
      baseUrl: 'https://school.example/api/',
      maxResponseBytes: 4,
      httpClient: MockClient((request) async => http.Response('123456', 200)),
    );
    await expectLater(
      api.get('large'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'response_too_large',
        ),
      ),
    );
    api.close();
  });

  test(
    'an active 401 clears authenticated identity and stored token',
    () async {
      final store = _Store();
      final fixture = _authFixture(store);
      await fixture.controller.login(
        identifier: 'synthetic',
        password: 'synthetic',
      );
      await expectLater(
        fixture.api.get('student/dashboard', token: 'synthetic-audit-token'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(fixture.controller.status, AuthStatus.unauthenticated);
      expect(store.token, isNull);
      fixture.controller.dispose();
    },
  );

  test(
    'failed logout storage cleanup is visible and cannot restore in process',
    () async {
      final store = _Store()..failDelete = true;
      final fixture = _authFixture(store);
      await fixture.controller.login(
        identifier: 'synthetic',
        password: 'synthetic',
      );
      await fixture.controller.logout();
      expect(fixture.controller.status, AuthStatus.unauthenticated);
      expect(fixture.controller.errorMessage, contains('storage'));
      expect(store.token, 'synthetic-audit-token');
      expect(await fixture.repository.restoreSession(), isNull);
      fixture.controller.dispose();
    },
  );

  test(
    'a normal permission 403 does not invalidate an authenticated session',
    () async {
      final store = _Store();
      final fixture = _authFixture(store, failureStatus: 403);
      await fixture.controller.login(
        identifier: 'synthetic',
        password: 'synthetic',
      );
      await expectLater(
        fixture.api.get('restricted', token: 'synthetic-audit-token'),
        throwsA(isA<ApiException>()),
      );
      expect(fixture.controller.status, AuthStatus.authenticated);
      expect(store.token, 'synthetic-audit-token');
      fixture.controller.dispose();
    },
  );

  test('an account-blocked 403 clears the current session', () async {
    final store = _Store();
    final fixture = _authFixture(
      store,
      failureStatus: 403,
      failureCode: 'account_blocked',
    );
    await fixture.controller.login(
      identifier: 'synthetic',
      password: 'synthetic',
    );
    await expectLater(
      fixture.api.get('restricted', token: 'synthetic-audit-token'),
      throwsA(isA<ApiException>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(fixture.controller.session, isNull);
    expect(store.token, isNull);
    fixture.controller.dispose();
  });

  test(
    'password-required 403 opens the password gate without logging out',
    () async {
      final store = _Store();
      final fixture = _authFixture(
        store,
        failureStatus: 403,
        failureCode: 'password_change_required',
      );
      await fixture.controller.login(
        identifier: 'synthetic',
        password: 'synthetic',
      );
      await expectLater(
        fixture.api.get('restricted', token: 'synthetic-audit-token'),
        throwsA(isA<ApiException>()),
      );
      expect(fixture.controller.status, AuthStatus.authenticated);
      expect(fixture.controller.mustChangePassword, isTrue);
      expect(store.token, 'synthetic-audit-token');
      fixture.controller.dispose();
    },
  );

  test('a stale token denial cannot invalidate a newer session', () async {
    final fixture = _authFixture(_Store());
    await fixture.controller.login(
      identifier: 'synthetic',
      password: 'synthetic',
    );
    fixture.api.onSessionInvalidated!(
      'old-synthetic-token',
      const ApiException(statusCode: 401, message: 'expired'),
    );
    expect(fixture.controller.status, AuthStatus.authenticated);
    fixture.controller.dispose();
  });

  test(
    'unauthenticated request failures cannot invalidate the active session',
    () async {
      final fixture = _authFixture(_Store());
      await fixture.controller.login(
        identifier: 'synthetic',
        password: 'synthetic',
      );
      await expectLater(
        fixture.api.post('public-request'),
        throwsA(isA<ApiException>()),
      );
      expect(fixture.controller.status, AuthStatus.authenticated);
      fixture.controller.dispose();
    },
  );

  test(
    'expired persisted tokens are removed before restoring identity',
    () async {
      final store = _Store()
        ..token = 'expired-token'
        ..expiry = DateTime.utc(2000);
      final fixture = _authFixture(store);
      await fixture.controller.initialize();
      expect(fixture.controller.status, AuthStatus.unauthenticated);
      expect(store.token, isNull);
      fixture.controller.dispose();
    },
  );

  test(
    'logout still clears storage when reading the old token fails',
    () async {
      final store = _Store()
        ..token = 'synthetic-old-token'
        ..failRead = true;
      final fixture = _authFixture(store);
      await fixture.repository.logout();
      expect(store.token, isNull);
      expect(await fixture.repository.restoreSession(), isNull);
      fixture.controller.dispose();
    },
  );

  test('a stale expiry lookup cannot erase a newly signed-in token', () async {
    final store = _Store()
      ..token = 'old-token'
      ..delayedExpiry = Completer<DateTime?>();
    final fixture = _authFixture(store);
    final restoring = fixture.repository.restoreSession();
    await store.expiryRequested.future;
    await fixture.controller.login(
      identifier: 'synthetic',
      password: 'synthetic',
    );
    store.delayedExpiry!.complete(DateTime.utc(2000));
    expect(await restoring, isNull);
    expect(store.token, 'synthetic-audit-token');
    expect(fixture.controller.status, AuthStatus.authenticated);
    fixture.controller.dispose();
  });

  test('same-origin relative password paths continue to work', () async {
    final api = ApiClient(
      baseUrl: 'https://school.example/api/mobile/v1/',
      httpClient: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://school.example/api/password/forgot',
        );
        return http.Response('{}', 200);
      }),
    );
    await api.post('../../password/forgot');
    api.close();
  });

  test(
    'a revoked session stops foreground tracking before capturing location',
    () async {
      final service = _Locations();
      final repository = _LocationsRepository()..rejectPolicy = true;
      final controller = StudentLocationController(
        repository,
        service,
        'synthetic',
      );
      await controller.start();
      expect(controller.status, StudentLocationStatus.failed);
      expect(service.starts, 1);
      expect(service.stops, 1);
      expect(service.captures, 0);
      await controller.checkNow();
      expect(service.captures, 0);
      expect(controller.isSessionEnabled, isFalse);
      controller.dispose();
    },
  );

  test(
    'stopping during consent lookup cannot enable server consent later',
    () async {
      final service = _Locations();
      final repository = _LocationsRepository()
        ..delayedConsent = Completer<StudentLocationConsent>();
      final controller = StudentLocationController(
        repository,
        service,
        'synthetic',
      );
      final starting = controller.start();
      await repository.consentRequested.future;
      await controller.stop();
      repository.delayedConsent!.complete(
        const StudentLocationConsent(
          enabled: false,
          policyVersion: 'synthetic-policy',
        ),
      );
      await starting;
      expect(controller.isSessionEnabled, isFalse);
      expect(service.starts, 0);
      expect(repository.enabled, isFalse);
      expect(controller.serverConsentEnabled, isFalse);
      controller.dispose();
    },
  );
  test('Stop compensates an enable write that was already in flight', () async {
    final service = _Locations();
    final repository = _LocationsRepository()
      ..delayedEnable = Completer<StudentLocationConsent>();
    final controller = StudentLocationController(
      repository,
      service,
      'synthetic',
    );
    final starting = controller.start();
    await repository.enableRequested.future;
    final stopping = controller.stop();
    repository.delayedEnable!.complete(
      const StudentLocationConsent(
        enabled: true,
        policyVersion: 'synthetic-policy',
      ),
    );
    await Future.wait([starting, stopping]);
    expect(repository.enabled, isFalse);
    expect(controller.serverConsentEnabled, isFalse);
    expect(service.starts, 0);
    expect(controller.isSessionEnabled, isFalse);
    controller.dispose();
  });

  test(
    'disposal compensates a late consent enable without updating disposed UI',
    () async {
      final repository = _LocationsRepository()
        ..delayedEnable = Completer<StudentLocationConsent>();
      final controller = StudentLocationController(
        repository,
        _Locations(),
        'synthetic',
      );
      final starting = controller.start();
      await repository.enableRequested.future;
      controller.dispose();
      repository.delayedEnable!.complete(
        const StudentLocationConsent(
          enabled: true,
          policyVersion: 'synthetic-policy',
        ),
      );
      await starting;
      await Future<void>.delayed(Duration.zero);
      expect(repository.enabled, isFalse);
    },
  );
}

({ApiClient api, AuthRepositoryImpl repository, AuthController controller})
_authFixture(_Store store, {int failureStatus = 401, String? failureCode}) {
  const user = <String, Object?>{
    'id': 1,
    'name': 'Synthetic Audit User',
    'email': 'synthetic@example.invalid',
    'roles': ['student'],
    'needs_password_change': false,
  };
  final api = ApiClient(
    baseUrl: 'https://school.example/api/',
    httpClient: MockClient((request) async {
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response(
          jsonEncode({
            'access_token': 'synthetic-audit-token',
            'expires_at': DateTime.now()
                .add(const Duration(days: 1))
                .toIso8601String(),
            'user': user,
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/me')) {
        return http.Response(jsonEncode({'user': user}), 200);
      }
      if (request.url.path.endsWith('/logout')) {
        throw http.ClientException('Synthetic offline failure');
      }
      return http.Response(
        jsonEncode({'message': 'Synthetic API denial', 'code': failureCode}),
        failureStatus,
      );
    }),
  );
  final repository = AuthRepositoryImpl(
    AuthRemoteDataSource(api, false),
    store,
    api,
  );
  return (
    api: api,
    repository: repository,
    controller: AuthController(repository),
  );
}

class _Store implements SessionStore {
  String? token;
  bool failDelete = false;
  bool failRead = false;
  Completer<DateTime?>? delayedExpiry;
  final expiryRequested = Completer<void>();
  @override
  Future<String?> readAccessToken() async {
    if (failRead) throw StateError('Synthetic read failure');
    return token;
  }

  @override
  Future<void> writeAccessToken(String value, {DateTime? expiresAt}) async {
    token = value;
    expiry = expiresAt;
  }

  DateTime? expiry;
  @override
  Future<DateTime?> readExpiresAt() async {
    if (!expiryRequested.isCompleted) expiryRequested.complete();
    return delayedExpiry == null ? expiry : await delayedExpiry!.future;
  }

  @override
  Future<void> clearAccessToken() async {
    if (failDelete) throw StateError('Synthetic storage deletion failure');
    token = null;
  }

  @override
  Future<String> getOrCreateInstallationId() async =>
      'b953779a-d3d3-4114-bd79-224ec5f9ab21';
}

class _Locations implements DeviceLocationService {
  int starts = 0;
  int stops = 0;
  int captures = 0;
  @override
  Future<DeviceLocationPermission> checkPermission() async =>
      DeviceLocationPermission.whileInUse;
  @override
  Future<DeviceLocationPermission> requestPermission() async =>
      DeviceLocationPermission.whileInUse;
  @override
  Future<bool> isServiceEnabled() async => true;
  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
  @override
  Future<void> startBackgroundTracking(Duration interval) async {
    starts++;
  }

  @override
  Future<void> stopBackgroundTracking() async {
    stops++;
  }

  @override
  Future<DeviceLocation> getCurrentLocation() async {
    captures++;
    return DeviceLocation(
      latitude: 2,
      longitude: 2,
      accuracyMeters: 5,
      recordedAt: DateTime.now(),
    );
  }
}

class _LocationsRepository implements StudentLocationRepository {
  bool enabled = false;
  bool rejectPolicy = false;
  Completer<StudentLocationConsent>? delayedConsent;
  Completer<StudentLocationConsent>? delayedEnable;
  final enableRequested = Completer<void>();
  final consentRequested = Completer<void>();
  @override
  Future<StudentLocationConsent> fetchConsent({
    required String accessToken,
  }) async {
    if (!consentRequested.isCompleted) consentRequested.complete();
    return delayedConsent == null
        ? StudentLocationConsent(
            enabled: enabled,
            policyVersion: 'synthetic-policy',
          )
        : await delayedConsent!.future;
  }

  @override
  Future<StudentLocationConsent> updateConsent({
    required String accessToken,
    required bool enabled,
    required String policyVersion,
  }) async {
    this.enabled = enabled;
    if (enabled && delayedEnable != null) {
      if (!enableRequested.isCompleted) enableRequested.complete();
      return await delayedEnable!.future;
    }
    return StudentLocationConsent(
      enabled: enabled,
      policyVersion: policyVersion,
    );
  }

  @override
  Future<StudentGeofencePolicy> fetchGeofencePolicy({
    required String accessToken,
  }) async {
    if (rejectPolicy) {
      throw const ApiException(
        statusCode: 401,
        message: 'Synthetic expired session',
      );
    }
    throw StateError('Policy should not be fetched by this probe');
  }

  @override
  Future<StudentLocationReport> reportLocation({
    required String accessToken,
    required StudentLocationSample sample,
  }) async {
    throw StateError('No real location upload is allowed in audit probes');
  }
}
