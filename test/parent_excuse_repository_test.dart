import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qrdify/core/network/api_client.dart';
import 'package:qrdify/core/network/api_exception.dart';
import 'package:qrdify/features/parent/data/parent_repository_impl.dart';

Map<String, Object?> _letter(int id) => {
  'id': id,
  'title': 'Synthetic excuse',
  'reason': 'Synthetic private reason',
  'absent_date': '2026-10-12',
  'status': 'pending',
  'teacher': {'id': 3, 'name': 'Assigned Adviser'},
  'submitted_by_parent': {'id': 201, 'name': 'Synthetic Guardian'},
  'attachment_path': 'excuses/private.pdf',
};

void main() {
  for (final mobileBase in [false, true]) {
    test(
      'parent submission matches the backend contract (mobile base: $mobileBase)',
      () async {
        final api = ApiClient(
          baseUrl: mobileBase
              ? 'https://school.example/api/mobile/v1/'
              : 'https://school.example/api/',
          httpClient: MockClient((request) async {
            expect(request.method, 'POST');
            expect(
              request.url.path,
              '/api/mobile/v1/parent/children/15/excuse-letters',
            );
            expect(request.headers['authorization'], 'Bearer parent-token');
            expect(request.body, contains('name="title"'));
            expect(request.body, contains('2026-10-12'));
            expect(
              request.body,
              contains('name="attachment"; filename="medical.pdf"'),
            );
            for (final field in [
              'teacher_id',
              'student_id',
              'submitted_by_parent_id',
              'status',
              'attachment_path',
              'attachment_disk',
            ]) {
              expect(request.body, isNot(contains('name="$field"')));
            }
            return http.Response(jsonEncode({'letter': _letter(41)}), 201);
          }),
        );
        final repository = ParentRepositoryImpl(api, mobileBase);
        final letter = await repository.submitExcuseLetter(
          accessToken: 'parent-token',
          childId: 15,
          title: 'Synthetic excuse',
          reason: 'Synthetic private reason',
          absentDate: DateTime(2026, 10, 12),
          attachmentBytes: utf8.encode('%PDF synthetic'),
          attachmentName: 'medical.pdf',
        );
        expect(letter.id, 41);
        expect(letter.teacherName, 'Assigned Adviser');
        expect(letter.submittedByName, 'Synthetic Guardian');
        expect(letter.status, 'pending');
        api.close();
      },
    );
  }

  test(
    'history loads all bounded pages without following server-provided URLs',
    () async {
      var requests = 0;
      final api = ApiClient(
        baseUrl: 'https://school.example/api/',
        httpClient: MockClient((request) async {
          requests++;
          expect(request.url.host, 'school.example');
          expect(
            request.url.path,
            '/api/mobile/v1/parent/children/15/excuse-letters',
          );
          expect(request.url.queryParameters['page'], '$requests');
          expect(request.url.queryParameters['per_page'], '50');
          expect(request.headers['authorization'], 'Bearer parent-token');
          return http.Response(
            jsonEncode({
              'data': requests == 1
                  ? [_letter(42), _letter(41)]
                  : [_letter(41), _letter(40)],
              'meta': {'current_page': requests, 'last_page': 2},
              'links': {'next': 'https://external.invalid/collect'},
            }),
            200,
          );
        }),
      );
      final letters = await ParentRepositoryImpl(
        api,
        false,
      ).fetchExcuseLetters(accessToken: 'parent-token', childId: 15);
      expect(letters.map((letter) => letter.id), [42, 41, 40]);
      expect(requests, 2);
      api.close();
    },
  );

  test(
    'denied guardian access is surfaced without returning private history',
    () async {
      final api = ApiClient(
        baseUrl: 'https://school.example/api/',
        httpClient: MockClient(
          (request) async => http.Response(
            '{"message":"Child not found.","code":"not_found"}',
            404,
          ),
        ),
      );
      await expectLater(
        ParentRepositoryImpl(
          api,
          false,
        ).fetchExcuseLetters(accessToken: 'parent-token', childId: 99),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            404,
          ),
        ),
      );
      api.close();
    },
  );

  test('oversized histories fail explicitly instead of silently truncating records', () async {
    var requests = 0;
    final api = ApiClient(
      baseUrl: 'https://school.example/api/',
      httpClient: MockClient((request) async {
        requests++;
        return http.Response(
          jsonEncode({
            'data': [_letter(41)],
            'meta': {'current_page': 1, 'last_page': 21},
          }),
          200,
        );
      }),
    );
    await expectLater(
      ParentRepositoryImpl(
        api,
        false,
      ).fetchExcuseLetters(accessToken: 'parent-token', childId: 15),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'excuse_history_too_large',
        ),
      ),
    );
    expect(requests, 1);
    api.close();
  });
}
