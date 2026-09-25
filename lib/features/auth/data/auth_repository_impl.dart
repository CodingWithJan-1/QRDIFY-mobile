import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/session_store.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
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

  @override
  Future<AuthSession?> restoreSession() async {
    final token = await _sessionStore.readAccessToken();
    if (token == null || token.isEmpty) return null;

    try {
      final user = await _remoteDataSource.getCurrentUser(token);
      _accessToken = token;
      return AuthSession(accessToken: token, user: user);
    } on ApiException catch (error) {
      if (error.isUnauthorized || error.statusCode == 403) {
        await _clearSession();
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
    final installationId = await _sessionStore.getOrCreateInstallationId();
    final session = await _remoteDataSource.login(
      identifier: identifier,
      password: password,
      installationId: installationId,
    );

    await _sessionStore.writeAccessToken(session.accessToken);
    _accessToken = session.accessToken;
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
    final token = _accessToken ?? await _sessionStore.readAccessToken();
    try {
      if (token != null) await _remoteDataSource.logout(token);
    } finally {
      await _clearSession();
    }
  }

  Future<void> _clearSession() async {
    _accessToken = null;
    await _sessionStore.clearAccessToken();
  }

  @override
  void close() => _apiClient.close();
}
