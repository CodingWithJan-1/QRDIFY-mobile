import 'auth_session.dart';
import 'password_recovery.dart';

abstract interface class AuthRepository {
  Future<AuthSession?> restoreSession();

  Future<AuthSession> login({
    required String identifier,
    required String password,
  });

  Future<PasswordRecoveryRequest> requestPasswordReset({
    required String identifier,
  });

  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String password,
  });

  Future<void> logout();

  void close();
}
