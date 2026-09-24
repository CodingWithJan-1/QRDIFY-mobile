import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qrdify/core/network/api_client.dart';
import 'package:qrdify/features/student/data/excuse_letter_repository_impl.dart';

void main() {
  test(
    'loads excuse letters and Teachers from the configured API base',
    () async {
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add(request.url.path);
        expect(request.headers['authorization'], 'Bearer student-token');
        if (request.url.path.endsWith('/teachers')) {
          return http.Response(
            jsonEncode([
              {'id': 8, 'name': 'Teacher Demo'},
            ]),
            200,
          );
        }
        return http.Response(
          jsonEncode([
            {
              'id': 91,
              'title': 'Medical appointment',
              'absent_date': '2026-09-18',
              'reason': 'Appointment',
              'status': 'pending',
              'teacher': {'id': 8, 'name': 'Teacher Demo'},
            },
          ]),
          200,
        );
      });
      final apiClient = ApiClient(
        baseUrl: 'https://school.example/api/mobile/v1/',
        httpClient: client,
      );
      final repository = ExcuseLetterRepositoryImpl(apiClient, true);

      final letters = await repository.fetchLetters(
        accessToken: 'student-token',
      );
      final teachers = await repository.fetchTeachers(
        accessToken: 'student-token',
      );

      expect(paths, [
        '/api/mobile/v1/student/excuse-letters',
        '/api/mobile/v1/student/teachers',
      ]);
      expect(letters.single.teacherName, 'Teacher Demo');
      expect(teachers.single.id, 8);
      apiClient.close();
    },
  );

  test(
    'submits multipart fields and an optional attachment, then deletes',
    () async {
      var requestNumber = 0;
      final client = MockClient((request) async {
        requestNumber++;
        expect(request.headers['authorization'], 'Bearer student-token');
        if (requestNumber == 1) {
          expect(request.method, 'POST');
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data; boundary='),
          );
          final body = request.body;
          expect(body, contains('name="title"'));
          expect(body, contains('Medical appointment'));
          expect(body, contains('name="absent_date"'));
          expect(body, contains('2026-09-18'));
          expect(body, contains('name="teacher_id"'));
          expect(body, contains('filename="appointment.pdf"'));
          return http.Response(
            jsonEncode({
              'message': 'Sent.',
              'letter': {
                'id': 92,
                'title': 'Medical appointment',
                'absent_date': '2026-09-18',
                'reason': 'Appointment',
                'status': 'pending',
                'attachment_path': 'excuses/generated.pdf',
              },
            }),
            200,
          );
        }

        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/mobile/v1/student/excuse-letters/92');
        return http.Response(jsonEncode({'message': 'Deleted.'}), 200);
      });
      final apiClient = ApiClient(
        baseUrl: 'https://school.example/api/mobile/v1/',
        httpClient: client,
      );
      final repository = ExcuseLetterRepositoryImpl(apiClient, true);

      final letter = await repository.submitLetter(
        accessToken: 'student-token',
        title: 'Medical appointment',
        absentDate: DateTime(2026, 9, 18),
        reason: 'Appointment',
        teacherId: 8,
        attachmentBytes: utf8.encode('pdf test bytes'),
        attachmentName: 'appointment.pdf',
      );
      await repository.deleteLetter(
        accessToken: 'student-token',
        letterId: letter.id,
      );

      expect(letter.id, 92);
      expect(letter.attachmentPath, 'excuses/generated.pdf');
      expect(requestNumber, 2);
      apiClient.close();
    },
  );
}
