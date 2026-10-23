import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/session_store.dart';
import '../../auth/domain/auth_session.dart';
import '../domain/notification_signals.dart';

@pragma('vm:entry-point')
Future<void> qrdifyBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Android displays the generic notification payload. Private details stay in the inbox.
}

abstract interface class PushClient {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<bool> permissionEnabled();
  Future<String?> getToken();
  Future<void> deleteToken();
  Future<Map<String, dynamic>?> initialMessage();
  Stream<String> get tokenChanges;
  Stream<Map<String, dynamic>> get messages;
  Stream<Map<String, dynamic>> get opens;
  Future<void> showForeground(Map<String, dynamic> data);
}

class FirebasePushClient implements PushClient {
  static const channel = MethodChannel('online.qridify.twces/alerts');

  @override
  Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'Android push is not configured on this platform.',
      );
    }
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(qrdifyBackgroundMessage);
    await channel.invokeMethod<void>('initialize');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'open' && call.arguments is Map) {
        NotificationSignals.openRequest.value = Map<String, dynamic>.from(
          call.arguments as Map,
        );
      }
    });
  }

  @override
  Future<bool> requestPermission() async {
    final result = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final granted =
        result.authorizationStatus == AuthorizationStatus.authorized ||
        result.authorizationStatus == AuthorizationStatus.provisional;
    return granted &&
        await channel.invokeMethod<bool>('channelEnabled') == true;
  }

  @override
  Future<bool> permissionEnabled() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized &&
        await channel.invokeMethod<bool>('channelEnabled') == true;
  }

  @override
  // The PHP sender uses HTTP v1 registration tokens, not the new FID target API.
  Future<String?> getToken() async {
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    // ignore: deprecated_member_use
    return FirebaseMessaging.instance.getToken();
  }

  @override
  Future<void> deleteToken() async {
    await FirebaseMessaging.instance.setAutoInitEnabled(false);
    // ignore: deprecated_member_use
    await FirebaseMessaging.instance.deleteToken();
  }

  @override
  // ignore: deprecated_member_use
  Stream<String> get tokenChanges => FirebaseMessaging.instance.onTokenRefresh;
  @override
  Stream<Map<String, dynamic>> get messages =>
      FirebaseMessaging.onMessage.map((m) => m.data);
  @override
  Stream<Map<String, dynamic>> get opens =>
      FirebaseMessaging.onMessageOpenedApp.map((m) => m.data);
  @override
  Future<Map<String, dynamic>?> initialMessage() async {
    final remote = await FirebaseMessaging.instance.getInitialMessage();
    return remote?.data ??
        await channel.invokeMapMethod<String, dynamic>('initialMessage');
  }

  @override
  Future<void> showForeground(Map<String, dynamic> data) =>
      channel.invokeMethod<void>('show', data);
}

class MobilePushService {
  MobilePushService(
    this._api,
    this._store, {
    PushClient? client,
    this.useMobileApi = false,
  }) : _client = client ?? FirebasePushClient();
  final ApiClient _api;
  final SessionStore _store;
  final PushClient _client;
  final bool useMobileApi;
  String get _prefix => useMobileApi ? '' : 'mobile/v1/';
  AuthSession? _session;
  int _epoch = 0;
  bool _initialized = false;
  bool _disposed = false;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Set<String> _seen = {};

  Future<void> updateSession(AuthSession? session) async {
    final previous = _session;
    if (_disposed || previous?.accessToken == session?.accessToken) return;
    _session = session;
    final epoch = ++_epoch;
    _seen.clear();
    if (previous != null) {
      try {
        final installation = await _store.getOrCreateInstallationId();
        await _api.delete(
          '${_prefix}push-devices?installation_id=$installation',
          token: previous.accessToken,
        );
      } catch (_) {
        /* Session revocation also removes its device binding server-side. */
      }
    }
    if (_disposed || epoch != _epoch) return;
    if (session == null) {
      NotificationSignals.pushStatus.value = null;
      NotificationSignals.openRequest.value = null;
      if (_initialized) {
        try {
          await _client.deleteToken();
        } catch (_) {}
      }
      return;
    }
    await _connect(epoch);
  }

  Future<void> _connect(int epoch) async {
    final session = _session;
    if (session == null || _disposed || epoch != _epoch) return;
    try {
      final status = await _api.get(
        '${_prefix}push-status',
        token: session.accessToken,
      );
      if (_disposed || epoch != _epoch) return;
      if (status is! Map || status['enabled'] != true) {
        NotificationSignals.pushStatus.value = 'Phone alerts are not enabled on the server yet. Your inbox still updates here.';
        return;
      }
      if (!_initialized) {
        await _client.initialize();
        _initialized = true;
        _subscriptions.add(
          _client.tokenChanges.listen((_) => unawaited(_register(_epoch))),
        );
        _subscriptions.add(
          _client.messages.listen((data) => _receive(data, open: false)),
        );
        _subscriptions.add(
          _client.opens.listen((data) => _receive(data, open: true)),
        );
      }
      if (_disposed || epoch != _epoch) return;
      if (!await _client.requestPermission()) {
        NotificationSignals.pushStatus.value = 'Phone notifications are off. Enable QRDify notifications in Android settings for banners and sounds.';
        return;
      }
      await _register(epoch);
      if (_disposed || epoch != _epoch) return;
      final initial = await _client.initialMessage();
      if (initial != null) _receive(initial, open: true);
    } catch (_) {
      if (!_disposed && epoch == _epoch) {
        NotificationSignals.pushStatus.value = 'Phone alerts could not connect. Your inbox still updates while the app is open.';
      }
    }
  }

  Future<void> _register(int epoch) async {
    try {
      final session = _session;
      if (!await _client.permissionEnabled()) {
        NotificationSignals.pushStatus.value = 'Phone notifications are off. Enable QRDify notifications in Android settings for banners and sounds.';
        return;
      }
      if (_disposed || epoch != _epoch) return;
      final token = await _client.getToken().timeout(
        const Duration(seconds: 15),
      );
      final installation = await _store.getOrCreateInstallationId();
      if (_disposed || epoch != _epoch || session == null || token == null) {
        return;
      }
      await _api.post(
        '${_prefix}push-devices',
        token: session.accessToken,
        body: {'token': token, 'installation_id': installation},
      );
      if (!_disposed && epoch == _epoch) {
        NotificationSignals.pushStatus.value = null;
      }
    } catch (_) {
      if (!_disposed && epoch == _epoch) {
        NotificationSignals.pushStatus.value =
            'Phone alerts could not connect. Pull down to refresh your inbox.';
      }
    }
  }

  void _receive(Map<String, dynamic> data, {required bool open}) {
    if (_disposed ||
        _session == null ||
        '${data['user_id']}' != '${_session!.user.id}') {
      return;
    }
    if (open) {
      NotificationSignals.openRequest.value = Map.of(data);
    } else if (_seen.add('${data['notification_id']}')) {
      if (_seen.length > 200) _seen.remove(_seen.first);
      NotificationSignals.received();
      unawaited(_client.showForeground(data).catchError((_) {}));
    }
  }

  Future<void> resume() async {
    if (_session == null || _disposed) return;
    if (_initialized) {
      await _register(_epoch);
    } else {
      await _connect(_epoch);
    }
  }

  void dispose() {
    _disposed = true;
    ++_epoch;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }
}
