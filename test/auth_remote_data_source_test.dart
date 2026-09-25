import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qrdify/core/network/api_client.dart';
import 'package:qrdify/features/auth/data/auth_remote_data_source.dart';

void main() {
  test('sends a phone login as identifier', () async {
    late Uri requestedUri;
    late Map<String, dynamic> requestedBody;
    final client = MockClient((request) async {
      requestedUri = request.url;
      requestedBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'access_token': 'access-token',
          'user': {
            'id': 201,
            'name': 'Phone Parent',
            'email': null,
            'phone': '+639387671972',
            'roles': ['parent'],
          },
        }),
        200,
      );
    });
    final apiClient = ApiClient(
      baseUrl: 'https://school.example/api/mobile/v1/',
      httpClient: client,
    );
    final dataSource = AuthRemoteDataSource(apiClient, true);

    final session = await dataSource.login(
      identifier: '09387671972',
      password: 'parent-password',
      installationId: 'installation-id',
    );

    expect(requestedUri.path, '/api/mobile/v1/auth/login');
    expect(requestedBody['identifier'], '09387671972');
    expect(requestedBody.containsKey('email'), isFalse);
    expect(session.user.email, isEmpty);
    expect(session.user.phone, '+639387671972');
    expect(session.user.displayIdentifier, '+639387671972');
    apiClient.close();
  });

  test('uses public password recovery routes from a mobile API base', () async {
    final paths = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      if (request.url.path.endsWith('/forgot')) {
        return http.Response(
          jsonEncode({
            'message': 'Reset code sent.',
            'expires_in': 300,
            'resend_in': 60,
          }),
          202,
        );
      }
      return http.Response(jsonEncode({'message': 'Password reset.'}), 200);
    });
    final apiClient = ApiClient(
      baseUrl: 'https://school.example/api/mobile/v1/',
      httpClient: client,
    );
    final dataSource = AuthRemoteDataSource(apiClient, true);

    final request = await dataSource.requestPasswordReset(
      identifier: '09387671972',
    );
    await dataSource.resetPassword(
      identifier: '09387671972',
      code: '123456',
      password: 'new-password',
    );

    expect(paths, ['/api/password/forgot', '/api/password/reset']);
    expect(bodies.first, {'identifier': '09387671972'});
    expect(bodies.last['identifier'], '09387671972');
    expect(bodies.last['password_confirmation'], 'new-password');
    expect(request.expiresIn, const Duration(minutes: 5));
    expect(request.resendIn, const Duration(minutes: 1));
    apiClient.close();
  });
}
