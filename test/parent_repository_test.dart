import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qrdify/core/network/api_client.dart';
import 'package:qrdify/features/parent/data/parent_enrollment_repository_impl.dart';
import 'package:qrdify/features/parent/data/parent_repository_impl.dart';

void main() {
  test(
    'uses the mobile Parent namespace from the compatibility API base',
    () async {
      late Uri requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        expect(request.headers['authorization'], 'Bearer parent-token');
        return http.Response(jsonEncode(_childrenFixture), 200);
      });
      final apiClient = ApiClient(
        baseUrl: 'https://school.example/api/',
        httpClient: client,
      );
      final repository = ParentRepositoryImpl(apiClient, false);

      final children = await repository.fetchChildren(
        accessToken: 'parent-token',
      );

      expect(requestedUri.path, '/api/mobile/v1/parent/children');
      expect(children.single.name, 'Alex Student');
      apiClient.close();
    },
  );

  test('does not duplicate the namespace from a mobile API base', () async {
    late Uri requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(jsonEncode(_childrenFixture), 200);
    });
    final apiClient = ApiClient(
      baseUrl: 'https://school.example/api/mobile/v1/',
      httpClient: client,
    );
    final repository = ParentRepositoryImpl(apiClient, true);

    await repository.fetchChildren(accessToken: 'parent-token');

    expect(requestedUri.path, '/api/mobile/v1/parent/children');
    apiClient.close();
  });

  test(
    'uses the public invitation flow and authenticates an existing Parent',
    () async {
      var requestNumber = 0;
      final client = MockClient((request) async {
        requestNumber++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (requestNumber == 1) {
          expect(
            request.url.path,
            '/api/mobile/v1/parent-invitations/verification',
          );
          expect(body['token'], 'invite-token');
          return http.Response(
            jsonEncode({'verification_id': 'verification-id'}),
            202,
          );
        }

        expect(request.url.path, '/api/mobile/v1/parent-invitations/accept');
        expect(request.headers['authorization'], 'Bearer parent-token');
        expect(body['code'], '123456');
        return http.Response(
          jsonEncode({
            'data': {
              'parent_user_id': 201,
              'link': {'student_id': 15},
            },
          }),
          201,
        );
      });
      final apiClient = ApiClient(
        baseUrl: 'https://school.example/api/',
        httpClient: client,
      );
      final repository = ParentEnrollmentRepositoryImpl(apiClient, false);

      final verificationId = await repository.requestVerification(
        invitationToken: 'invite-token',
      );
      final result = await repository.acceptInvitation(
        invitationToken: 'invite-token',
        verificationId: verificationId,
        code: '123456',
        accessToken: 'parent-token',
      );

      expect(result.parentUserId, 201);
      expect(result.studentId, 15);
      expect(requestNumber, 2);
      apiClient.close();
    },
  );
}

const _childrenFixture = {
  'data': [
    {
      'id': 15,
      'name': 'Alex Student',
      'grade': 'Grade 6',
      'section': 'Rizal',
      'link': {
        'relationship': 'parent',
        'can_view_location': false,
        'can_submit_excuses': true,
        'history_visible_from': '2026-06-01',
      },
    },
  ],
};
