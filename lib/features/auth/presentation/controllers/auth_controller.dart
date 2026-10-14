import 'package:flutter/foundation.dart';

import 'dart:async';

import '../../../../core/network/api_exception.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_session.dart';
import '../../domain/auth_user.dart';
import '../../domain/password_recovery.dart';

enum AuthStatus { checking, unauthenticated, authenticating, authenticated }

class AuthController extends ChangeNotifier {
  AuthController(this._repository) {
    _repository.setSessionInvalidationHandler(_onSessionInvalidated);
  }

  final AuthRepository _repository;

  AuthStatus _status = AuthStatus.checking;
  AuthSession? _session;
  String? _errorMessage;
  bool _initialized = false;
  int _generation = 0;
  Timer? _expiryTimer;
  bool _disposed = false;
  bool _passwordChangeRequired = false;
  bool _logoutCleanupFailed = false;

  AuthStatus get status => _status;
  AuthSession? get session => _session;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticating => _status == AuthStatus.authenticating;
  bool get mustChangePassword =>
      _passwordChangeRequired || _session?.user.needsPasswordChange == true;
  bool get needsLogoutRetry => _logoutCleanupFailed;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final generation = ++_generation;

    try {
      final restored = await _repository.restoreSession();
      if (_disposed || generation != _generation) return;
      _session = restored;
      _status = _session == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
    } on Object {
      if (_disposed || generation != _generation) return;
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Unable to restore your session. Please sign in again.';
    }
    _scheduleExpiry();
    notifyListeners();
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    final generation = ++_generation;
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final signedIn = await _repository.login(
        identifier: identifier.trim(),
        password: password,
      );
      if (_disposed || generation != _generation) return;
      _session = signedIn;
      _passwordChangeRequired = false;

      if (_session?.user.portalRole == null) {
        await _repository.logout();
        _session = null;
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'This app is available only to students and parents.';
      } else {
        _status = AuthStatus.authenticated;
      }
    } on ApiException catch (error) {
      if (_disposed || generation != _generation) return;
      _status = AuthStatus.unauthenticated;
      _errorMessage = error.message;
    } on FormatException {
      if (_disposed || generation != _generation) return;
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'QRDify returned an invalid response. Please try again.';
    } on Object {
      if (_disposed || generation != _generation) return;
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Unable to sign in. Please try again.';
    }
    _scheduleExpiry();
    notifyListeners();
  }

  Future<PasswordRecoveryRequest> requestPasswordReset({
    required String identifier,
  }) => _repository.requestPasswordReset(identifier: identifier);

  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String password,
  }) => _repository.resetPassword(
    identifier: identifier,
    code: code,
    password: password,
  );

  Future<void> logout() async {
    final generation = ++_generation;
    _expiryTimer?.cancel();
    _session = null;
    _passwordChangeRequired = false;
    _errorMessage = null;
    _status = AuthStatus.checking;
    notifyListeners();

    try {
      await _repository.logout();
      if (_disposed || generation != _generation) return;
      _logoutCleanupFailed = false;
    } on Object {
      if (_disposed || generation != _generation) return;
      _logoutCleanupFailed = true;
      _errorMessage = 'Session storage could not be cleared. Retry signing out before handing this phone to someone else.';
    }

    if (_disposed || generation != _generation) return;
    _session = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void _onSessionInvalidated(String token, ApiException error) {
    if (_session?.accessToken != token) return;
    if (error.code == 'password_change_required') {
      _passwordChangeRequired = true;
      notifyListeners();
      return;
    }
    unawaited(_invalidateSession(error.message));
  }

  Future<void> _invalidateSession(String message) async {
    final generation = ++_generation;
    _expiryTimer?.cancel();
    _session = null;
    _passwordChangeRequired = false;
    _status = AuthStatus.unauthenticated;
    _errorMessage = message;
    notifyListeners();
    try {
      await _repository.clearLocalSession();
      if (!_disposed && generation == _generation) _logoutCleanupFailed = false;
    } on Object {
      if (_disposed || generation != _generation) return;
      _logoutCleanupFailed = true;
      _errorMessage = 'Session expired, but storage could not be cleared. Retry signing out on this phone.';
      notifyListeners();
    }
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final expiry = _session?.expiresAt;
    if (expiry == null) return;
    final delay = expiry.difference(DateTime.now());
    _expiryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      unawaited(
        _invalidateSession('Your session has expired. Please sign in again.'),
      );
    });
  }

  Future<void> revalidateSession() async {
    final session = _session;
    if (session == null) return;
    if (session.expiresAt != null &&
        !session.expiresAt!.isAfter(DateTime.now())) {
      await _invalidateSession(
        'Your session has expired. Please sign in again.',
      );
      return;
    }
    final generation = _generation;
    try {
      final restored = await _repository.restoreSession();
      if (_disposed || generation != _generation) return;
      if (restored == null) {
        await _invalidateSession('Please sign in again.');
      } else {
        _session = restored;
        _scheduleExpiry();
        notifyListeners();
      }
    } on ApiException catch (error) {
      if (_disposed || generation != _generation) return;
      if (error.isUnauthorized || error.code == 'account_blocked') {
        await _invalidateSession(error.message);
      }
      // A temporary network failure does not turn a valid session into logout.
    } on Object {
      if (_disposed || generation != _generation) return;
      await _invalidateSession(
        'Unable to verify your session. Please sign in again.',
      );
    }
  }

  Future<AuthUser> changePassword({
    required String currentPassword,
    required String password,
  }) async {
    final user = await _updateProfileUser(
      () => _repository.changePassword(
        currentPassword: currentPassword,
        password: password,
      ),
    );
    _passwordChangeRequired = user.needsPasswordChange;
    notifyListeners();
    return user;
  }

  Future<AuthUser> uploadProfilePhoto(List<int> bytes) =>
      _updateProfileUser(() => _repository.uploadProfilePhoto(bytes));

  Future<AuthUser> removeProfilePhoto() =>
      _updateProfileUser(_repository.removeProfilePhoto);

  Future<AuthUser> _updateProfileUser(
    Future<AuthUser> Function() action,
  ) async {
    final session = _session;
    if (session == null) {
      throw const ApiException(
        statusCode: 401,
        message: 'Please sign in again.',
      );
    }
    final user = await action();
    if (_session?.accessToken != session.accessToken ||
        user.id != session.user.id) {
      throw const ApiException(
        message: 'Your session changed. Please sign in again.',
      );
    }
    _session = AuthSession(
      accessToken: session.accessToken,
      expiresAt: session.expiresAt,
      user: user,
    );
    notifyListeners();
    return user;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _expiryTimer?.cancel();
    _repository.close();
    super.dispose();
  }
}
