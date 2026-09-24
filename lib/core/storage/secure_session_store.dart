import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_store.dart';

class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'auth.access_token';
  static const _installationIdKey = 'device.installation_id';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  @override
  Future<void> writeAccessToken(String token) {
    return _storage.write(key: _accessTokenKey, value: token);
  }

  @override
  Future<void> clearAccessToken() => _storage.delete(key: _accessTokenKey);

  @override
  Future<String> getOrCreateInstallationId() async {
    final existing = await _storage.read(key: _installationIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = _generateUuidV4();
    await _storage.write(key: _installationIdKey, value: generated);
    return generated;
  }

  String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
