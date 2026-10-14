import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrdify/core/storage/secure_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const encrypted = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  const security = MethodChannel('online.qridify.twces/security');
  late Map<String, String> values;
  var revoked = false;
  var failDelete = false;
  var failMarker = false;
  var failAllow = false;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    values = {};
    revoked = failDelete = failMarker = false;
    failAllow = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(encrypted, (call) async {
      final arguments = call.arguments as Map;
      final key = arguments['key'] as String;
      switch (call.method) {
        case 'read':
          return values[key];
        case 'write':
          values[key] = arguments['value'] as String;
          return null;
        case 'delete':
          if (failDelete) {
            throw PlatformException(code: 'synthetic_keystore_failure');
          }
          values.remove(key);
          return null;
      }
      throw StateError('Unexpected encrypted-storage operation');
    });
    messenger.setMockMethodCallHandler(security, (call) async {
      if (call.method == 'isSessionRevoked') return revoked;
      if (call.method == 'setSessionRevoked') {
        if (failMarker) {
          throw PlatformException(code: 'synthetic_marker_failure');
        }
        if (failAllow && call.arguments == false) {
          throw PlatformException(code: 'synthetic_allow_failure');
        }
        revoked = call.arguments as bool;
        return null;
      }
      throw StateError('Unexpected session-guard operation');
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(encrypted, null);
    messenger.setMockMethodCallHandler(security, null);
  });

  test(
    'expiry and token persist together and survive a new store instance',
    () async {
      final expiry = DateTime.utc(2026, 10, 15);
      await SecureSessionStore().writeAccessToken(
        'synthetic-token',
        expiresAt: expiry,
      );
      final restored = SecureSessionStore();
      expect(await restored.readAccessToken(), 'synthetic-token');
      expect(await restored.readExpiresAt(), expiry);
      expect(
        jsonDecode(values['auth.access_token']!)['expires_at'],
        expiry.toIso8601String(),
      );
    },
  );

  test(
    'durable marker prevents restoration after encrypted deletion fails',
    () async {
      final store = SecureSessionStore();
      await store.writeAccessToken('synthetic-token');
      failDelete = true;
      await store.clearAccessToken();
      expect(values['auth.access_token'], isNotNull);
      expect(revoked, isTrue);
      expect(await SecureSessionStore().readAccessToken(), isNull);
      // A successful new login explicitly permits its new token.
      await store.writeAccessToken('replacement-token');
      expect(await SecureSessionStore().readAccessToken(), 'replacement-token');
    },
  );

  test('token deletion still runs when the marker write fails', () async {
    final store = SecureSessionStore();
    await store.writeAccessToken('synthetic-token');
    failMarker = true;
    await store.clearAccessToken();
    expect(await SecureSessionStore().readAccessToken(), isNull);
  });

  test('failure of both durable clearing mechanisms is reported', () async {
    final store = SecureSessionStore();
    await store.writeAccessToken('synthetic-token');
    failMarker = failDelete = true;
    await expectLater(
      store.clearAccessToken(),
      throwsA(isA<PlatformException>()),
    );
  });

  test(
    'old raw tokens remain readable for server-validated migration',
    () async {
      values['auth.access_token'] = 'legacy-synthetic-token';
      expect(
        await SecureSessionStore().readAccessToken(),
        'legacy-synthetic-token',
      );
      expect(await SecureSessionStore().readExpiresAt(), isNull);
    },
  );
  test(
    'an incomplete login cannot restore its partially written token',
    () async {
      failAllow = true;
      await expectLater(
        SecureSessionStore().writeAccessToken('synthetic-token'),
        throwsA(isA<PlatformException>()),
      );
      expect(values['auth.access_token'], isNotNull);
      expect(revoked, isTrue);
      expect(await SecureSessionStore().readAccessToken(), isNull);
    },
  );
}
