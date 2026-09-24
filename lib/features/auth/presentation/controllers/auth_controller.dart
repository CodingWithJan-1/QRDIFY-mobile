import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_session.dart';

enum AuthStatus { checking, unauthenticated, authenticating, authenticated }

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  AuthStatus _status = AuthStatus.checking;
  AuthSession? _session;
  String? _errorMessage;
  bool _initialized = false;

  AuthStatus get status => _status;
  AuthSession? get session => _session;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticating => _status == AuthStatus.authenticating;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      _session = await _repository.restoreSession();
      _status = _session == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
    } on Object {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Unable to restore your session. Please sign in again.';
    }
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      _session = await _repository.login(
        email: email.trim(),
        password: password,
      );

      if (_session?.user.portalRole == null) {
        await _repository.logout();
        _session = null;
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'This app is available only to students and parents.';
      } else {
        _status = AuthStatus.authenticated;
      }
    } on ApiException catch (error) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = error.message;
    } on FormatException {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'QRDify returned an invalid response. Please try again.';
    } on Object {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Unable to sign in. Please try again.';
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _errorMessage = null;
    _status = AuthStatus.checking;
    notifyListeners();

    try {
      await _repository.logout();
    } on Object {
      // Local credentials are cleared by the repository even if the API fails.
    }

    _session = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.close();
    super.dispose();
  }
}
