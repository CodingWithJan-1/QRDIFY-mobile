import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class SessionRevocationGuard {
  Future<bool> isRevoked();
  Future<void> setRevoked(bool revoked);
}

// A non-secret, durable logout marker is separate from encrypted token storage.
// This prevents a failed keystore deletion from restoring a logged-out session.
class AndroidSessionRevocationGuard implements SessionRevocationGuard {
  static const _channel = MethodChannel('online.qridify.twces/security');
  bool _revoked = false;

  @override
  Future<bool> isRevoked() async {
    if (defaultTargetPlatform != TargetPlatform.android) return _revoked;
    return await _channel.invokeMethod<bool>('isSessionRevoked') ?? true;
  }

  @override
  Future<void> setRevoked(bool revoked) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _channel.invokeMethod<void>('setSessionRevoked', revoked);
    }
    _revoked = revoked;
  }
}
