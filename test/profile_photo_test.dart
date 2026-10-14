import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qrdify/core/images/profile_photo_processor.dart';
import 'package:qrdify/core/network/api_client.dart';
import 'package:qrdify/core/network/api_exception.dart';
import 'package:qrdify/features/auth/data/auth_remote_data_source.dart';
import 'package:qrdify/features/auth/domain/auth_repository.dart';
import 'package:qrdify/features/auth/domain/auth_session.dart';
import 'package:qrdify/features/auth/domain/auth_user.dart';
import 'package:qrdify/features/auth/domain/password_recovery.dart';
import 'package:qrdify/features/auth/presentation/controllers/auth_controller.dart';

Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawPaint(ui.Paint()..color = const ui.Color(0xff2060a0));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'large portrait is resized with its aspect ratio and fits the upload limit',
    () async {
      final resized = await ProfilePhotoProcessor.prepare(
        await _png(800, 1600),
      );
      final codec = await ui.instantiateImageCodec(resized);
      final image = (await codec.getNextFrame()).image;
      expect([image.width, image.height], [256, 512]);
      expect(resized.length, lessThan(2 * 1024 * 1024));
      image.dispose();
      codec.dispose();
    },
  );

  test('small photo is not upscaled', () async {
    final resized = await ProfilePhotoProcessor.prepare(await _png(80, 100));
    final codec = await ui.instantiateImageCodec(resized);
    final image = (await codec.getNextFrame()).image;
    expect([image.width, image.height], [80, 100]);
    image.dispose();
    codec.dispose();
  });

  test(
    'empty, oversized, corrupt and unsupported source images are rejected',
    () async {
      for (final bytes in [
        Uint8List(0),
        Uint8List(ProfilePhotoProcessor.maxSourceBytes + 1),
        Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 13, 10, 26, 10]),
        Uint8List.fromList(utf8.encode('GIF89a fake')),
      ]) {
        await expectLater(
          ProfilePhotoProcessor.prepare(bytes),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'excessive source dimensions are rejected before full decoding',
    () async {
      await expectLater(
        ProfilePhotoProcessor.prepare(await _png(8193, 1)),
        throwsFormatException,
      );
    },
  );

  for (final mobileMode in [false, true]) {
    test(
      'profile upload uses authenticated multipart in API mode $mobileMode',
      () async {
        final client = MockClient((request) async {
          expect(request.url.path, '/api/mobile/v1/account/profile-photo');
          expect(request.headers['authorization'], 'Bearer parent-token');
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data; boundary='),
          );
          expect(
            latin1.decode(request.bodyBytes),
            contains('name="photo"; filename="profile.png"'),
          );
          return http.Response(
            jsonEncode({
              'user': {
                ..._userJson,
                'photo_url': '/storage/profile-photos/201/new.jpg',
              },
            }),
            200,
          );
        });
        final api = ApiClient(
          baseUrl: mobileMode
              ? 'https://school.example/api/mobile/v1/'
              : 'https://school.example/api/',
          httpClient: client,
        );
        final remote = AuthRemoteDataSource(api, mobileMode);
        final user = await remote.uploadProfilePhoto('parent-token', [1, 2, 3]);
        expect(
          user.photoUrl,
          'https://school.example/storage/profile-photos/201/new.jpg',
        );
        api.close();
      },
    );
  }

  test(
    'removal clears photo and restored identity resolves relative photo URLs',
    () async {
      final client = MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer parent-token');
        if (request.method == 'DELETE') {
          expect(request.url.path, '/api/mobile/v1/account/profile-photo');
          return http.Response(
            jsonEncode({
              'user': {..._userJson, 'photo_url': null},
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'user': {
              ..._userJson,
              'photo_url': '/storage/profile-photos/201/current.jpg',
            },
          }),
          200,
        );
      });
      final api = ApiClient(
        baseUrl: 'https://school.example/api/',
        httpClient: client,
      );
      final remote = AuthRemoteDataSource(api, false);
      expect(
        (await remote.getCurrentUser('parent-token')).photoUrl,
        'https://school.example/storage/profile-photos/201/current.jpg',
      );
      expect(
        (await remote.removeProfilePhoto('parent-token')).photoUrl,
        isNull,
      );
      api.close();
    },
  );

  test('successful photo change updates the active session without losing its token', () async {
    final repository = _ProfileRepository();
    final controller = AuthController(repository);
    await controller.initialize();
    final upload = controller.uploadProfilePhoto([1]);
    repository.upload.complete(
      AuthUser.fromJson({
        ..._userJson,
        'photo_url': 'https://school.example/new.jpg',
      }),
    );
    await upload;
    expect(controller.status, AuthStatus.authenticated);
    expect(controller.session!.accessToken, 'parent-token');
    expect(controller.session!.user.photoUrl, 'https://school.example/new.jpg');
    controller.dispose();
  });

  test(
    'late upload response after logout cannot restore the old identity',
    () async {
      final repository = _ProfileRepository();
      final controller = AuthController(repository);
      await controller.initialize();
      final upload = controller.uploadProfilePhoto([1]);
      final failure = expectLater(upload, throwsA(isA<ApiException>()));
      await controller.logout();
      repository.upload.complete(
        AuthUser.fromJson({
          ..._userJson,
          'photo_url': 'https://school.example/new.jpg',
        }),
      );
      await failure;
      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.session, isNull);
      controller.dispose();
    },
  );
}

const _userJson = {
  'id': 201,
  'name': 'Test Parent',
  'email': 'parent@example.test',
  'roles': ['parent'],
};

class _ProfileRepository implements AuthRepository {
  @override
  Future<void> clearLocalSession() async {}

  @override
  void setSessionInvalidationHandler(
    void Function(String, ApiException)? handler,
  ) {}

  @override
  Future<AuthUser> changePassword({
    required String currentPassword,
    required String password,
  }) => throw UnimplementedError();
  final upload = Completer<AuthUser>();

  @override
  Future<AuthSession?> restoreSession() async => AuthSession(
    accessToken: 'parent-token',
    user: AuthUser.fromJson(_userJson),
  );

  @override
  Future<AuthUser> uploadProfilePhoto(List<int> bytes) => upload.future;

  @override
  Future<AuthUser> removeProfilePhoto() async =>
      AuthUser.fromJson({..._userJson, 'photo_url': null});

  @override
  Future<void> logout() async {}

  @override
  void close() {}

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<PasswordRecoveryRequest> requestPasswordReset({
    required String identifier,
  }) => throw UnimplementedError();

  @override
  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String password,
  }) => throw UnimplementedError();
}
