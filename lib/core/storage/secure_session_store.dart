import 'dart:math';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_store.dart';
import 'session_revocation_guard.dart';

class SecureSessionStore implements SessionStore {
  SecureSessionStore({
    FlutterSecureStorage? storage,
    SessionRevocationGuard? revocationGuard,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _revocationGuard = revocationGuard ?? AndroidSessionRevocationGuard();

  static const _accessTokenKey = 'auth.access_token';
  static const _installationIdKey = 'device.installation_id';

  final FlutterSecureStorage _storage;
  final SessionRevocationGuard _revocationGuard;

  @override
  Future<String?> readAccessToken() async {
    final record = await _readRecord();
    return record?['token'] as String?;
  }

  Future<Map<String, dynamic>?> _readRecord() async {
    if (await _revocationGuard.isRevoked()) return null;
    final value = await _storage.read(key: _accessTokenKey);
    if (value == null || value.isEmpty) return null;
    // Existing installations stored a raw Sanctum token.
    if (!value.startsWith('{')) return {'token': value};
    return jsonDecode(value) as Map<String, dynamic>;
  }

  @override
  Future<DateTime?> readExpiresAt() async {
    final record = await _readRecord();
    return DateTime.tryParse(record?['expires_at'] as String? ?? '');
  }

  @override
  Future<void> writeAccessToken(String token, {DateTime? expiresAt}) async {
    // A partially completed login must never make its token restorable.
    await _revocationGuard.setRevoked(true);
    await _storage.write(
      key: _accessTokenKey,
      value: jsonEncode({
        'token': token,
        'expires_at': expiresAt?.toUtc().toIso8601String(),
      }),
    );
    await _revocationGuard.setRevoked(false);
  }

  @override
  Future<void> clearAccessToken() async {
    var revoked = false;
    try {
      await _revocationGuard.setRevoked(true);
      revoked = true;
    } on Object {
      // Deleting the token is still safe if the marker cannot be written.
    }
    try {
      await _storage.delete(key: _accessTokenKey);
    } on Object {
      if (!revoked) rethrow;
      // The durable marker blocks restoration even if encrypted deletion fails.
    }
  }

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
