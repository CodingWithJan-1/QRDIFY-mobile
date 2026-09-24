import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qrdify/core/network/api_client.dart';
import 'package:qrdify/features/student/data/student_location_repository_impl.dart';
import 'package:qrdify/features/student/domain/student_location.dart';

void main() {
  test('uses mobile safety routes from the compatibility API base', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/location-consent')) {
        return http.Response(
          jsonEncode({
            'data': {
              'enabled': request.method == 'PUT',
              'policy_version': '2026-09',
              'consented_at': null,
              'revoked_at': null,
            },
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/geofence-policy')) {
        return http.Response(
          jsonEncode({
            'data': {
              'enabled': false,
              'polygon': <Object?>[],
              'tracking_window_active': false,
            },
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'data': {
            'sample_id': 10,
            'accepted': true,
            'boundary_state': 'inside',
            'tracking_window_active': true,
          },
        }),
        200,
      );
    });
    final repository = StudentLocationRepositoryImpl(
      ApiClient(baseUrl: 'https://qridify.online/api/', httpClient: client),
      false,
    );

    final consent = await repository.fetchConsent(accessToken: 'token');
    await repository.updateConsent(
      accessToken: 'token',
      enabled: true,
      policyVersion: consent.policyVersion,
    );
    await repository.fetchGeofencePolicy(accessToken: 'token');
    await repository.reportLocation(
      accessToken: 'token',
      sample: StudentLocationSample(
        clientSampleId: 'a4e20315-4c20-40c6-a7b4-b54049e1403c',
        latitude: 8.04482,
        longitude: 126.06032,
        accuracyMeters: 12.4,
        recordedAt: DateTime.utc(2026, 9, 23, 2, 15),
      ),
    );

    expect(
      requests.map((request) => request.url.path),
      everyElement(startsWith('/api/mobile/v1/student/')),
    );
    final sampleRequest = requests.last;
    expect(sampleRequest.method, 'POST');
    expect(
      sampleRequest.headers['idempotency-key'],
      'a4e20315-4c20-40c6-a7b4-b54049e1403c',
    );
    expect(jsonDecode(sampleRequest.body)['source'], 'flutter');
  });

  test('does not duplicate the mobile namespace', () async {
    late Uri requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        jsonEncode({
          'data': {'enabled': false, 'policy_version': '2026-09'},
        }),
        200,
      );
    });
    final repository = StudentLocationRepositoryImpl(
      ApiClient(
        baseUrl: 'https://qridify.online/api/mobile/v1/',
        httpClient: client,
      ),
      true,
    );

    await repository.fetchConsent(accessToken: 'token');

    expect(requestedUri.path, '/api/mobile/v1/student/location-consent');
  });
}
