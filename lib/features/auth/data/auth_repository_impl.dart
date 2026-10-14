import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/session_store.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import '../domain/auth_user.dart';
import '../domain/password_recovery.dart';
import 'auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(
    this._remoteDataSource,
    this._sessionStore,
    this._apiClient,
  );

  final AuthRemoteDataSource _remoteDataSource;
  final SessionStore _sessionStore;
  final ApiClient _apiClient;

  String? _accessToken;
  bool _locallyInvalidated = false;
  int _generation = 0;
  Future<void> _storeQueue = Future.value();

  Future<T> _withStore<T>(Future<T> Function() action) {
    final result = _storeQueue.then((_) => action());
    _storeQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  @override
  void setSessionInvalidationHandler(
    void Function(String token, ApiException error)? handler,
  ) {
    _apiClient.onSessionInvalidated = handler;
  }

  @override
  Future<AuthSession?> restoreSession() async {
    if (_locallyInvalidated) return null;
    final generation = _generation;
    final token = await _sessionStore.readAccessToken();
    if (token == null || token.isEmpty) return null;
    final expiresAt = await _sessionStore.readExpiresAt();
    if (generation != _generation) return null;
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) {
      await clearLocalSession();
      return null;
    }

    try {
      final user = await _remoteDataSource.getCurrentUser(token);
      if (generation != _generation) return null;
      _accessToken = token;
      return AuthSession(accessToken: token, user: user, expiresAt: expiresAt);
    } on ApiException catch (error) {
      if (error.isUnauthorized || error.code == 'account_blocked') {
        if (generation == _generation) await clearLocalSession();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async {
    final generation = ++_generation;
    final installationId = await _sessionStore.getOrCreateInstallationId();
    final session = await _remoteDataSource.login(
      identifier: identifier,
      password: password,
      installationId: installationId,
    );

    await _withStore(() async {
      if (generation != _generation) {
        throw const ApiException(
          message: 'Sign-in was cancelled. Please try again.',
        );
      }
      await _sessionStore.writeAccessToken(
        session.accessToken,
        expiresAt: session.expiresAt,
      );
    });
    if (generation != _generation) {
      throw const ApiException(
        message: 'Sign-in was cancelled. Please try again.',
      );
    }
    _accessToken = session.accessToken;
    _locallyInvalidated = false;
    return session;
  }

  @override
  Future<PasswordRecoveryRequest> requestPasswordReset({
    required String identifier,
  }) => _remoteDataSource.requestPasswordReset(identifier: identifier.trim());

  @override
  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String password,
  }) => _remoteDataSource.resetPassword(
    identifier: identifier.trim(),
    code: code.trim(),
    password: password,
  );

  @override
  Future<void> logout() async {
    var token = _accessToken;
    try {
      token ??= await _sessionStore.readAccessToken();
    } on Object {
      // A failed read must not prevent either durable clearing mechanism.
    }
    await clearLocalSession();
    try {
      if (token != null) await _remoteDataSource.logout(token);
    } on ApiException {
      // Local logout is durable; offline server revocation is not guaranteed.
    }
  }

  @override
  Future<void> clearLocalSession() async {
    _generation++;
    _accessToken = null;
    _locallyInvalidated = true;
    await _withStore(_sessionStore.clearAccessToken);
  }

  Future<String> _profileToken() async {
    if (_locallyInvalidated) {
      throw const ApiException(
        statusCode: 401,
        message: 'Please sign in again.',
      );
    }
    final token = _accessToken ?? await _sessionStore.readAccessToken();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        statusCode: 401,
        message: 'Please sign in again.',
      );
    }
    return token;
  }

  @override
  Future<AuthUser> uploadProfilePhoto(List<int> bytes) async =>
      _remoteDataSource.uploadProfilePhoto(await _profileToken(), bytes);

  @override
  Future<AuthUser> removeProfilePhoto() async =>
      _remoteDataSource.removeProfilePhoto(await _profileToken());

  @override
  Future<AuthUser> changePassword({
    required String currentPassword,
    required String password,
  }) async => _remoteDataSource.changePassword(
    await _profileToken(),
    currentPassword: currentPassword,
    password: password,
  );

  @override
  void close() {
    _apiClient.onSessionInvalidated = null;
    _apiClient.close();
  }
}
