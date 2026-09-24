import '../../../core/network/api_client.dart';
import '../domain/auth_session.dart';
import '../domain/auth_user.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._apiClient, this._useMobileApi);

  final ApiClient _apiClient;
  final bool _useMobileApi;

  Future<AuthSession> login({
    required String email,
    required String password,
    required String installationId,
  }) async {
    final response = await _apiClient.post(
      _useMobileApi ? 'auth/login' : 'login',
      body: {
        'email': email,
        'password': password,
        'device_name': 'QRDify Flutter',
        'installation_id': installationId,
      },
    );

    final json = _asMap(response);
    return AuthSession(
      accessToken: json['access_token'] as String,
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
      user: AuthUser.fromJson(_asMap(json['user'])),
    );
  }

  Future<AuthUser> getCurrentUser(String token) async {
    final response = await _apiClient.get('me', token: token);
    final json = _asMap(response);
    final userJson = json['data'] ?? json['user'];
    return AuthUser.fromJson(_asMap(userJson));
  }

  Future<void> logout(String token) async {
    await _apiClient.post(
      _useMobileApi ? 'auth/logout' : 'logout',
      token: token,
    );
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value case Map<String, dynamic> json) return json;
    throw const FormatException('The server returned an unexpected response.');
  }
}
