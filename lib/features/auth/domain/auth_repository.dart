import 'auth_session.dart';

abstract interface class AuthRepository {
  Future<AuthSession?> restoreSession();

  Future<AuthSession> login({required String email, required String password});

  Future<void> logout();

  void close();
}
