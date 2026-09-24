import 'auth_user.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.user,
    this.expiresAt,
  });

  final String accessToken;
  final AuthUser user;
  final DateTime? expiresAt;
}
