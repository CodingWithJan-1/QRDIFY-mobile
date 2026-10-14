import 'auth_session.dart';
import 'auth_user.dart';
import 'password_recovery.dart';
import '../../../core/network/api_exception.dart';

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

  Future<void> clearLocalSession();

  void setSessionInvalidationHandler(
    void Function(String token, ApiException error)? handler,
  );

  Future<AuthUser> changePassword({
    required String currentPassword,
    required String password,
  });

  Future<AuthUser> uploadProfilePhoto(List<int> bytes);

  Future<AuthUser> removeProfilePhoto();

  void close();
}
