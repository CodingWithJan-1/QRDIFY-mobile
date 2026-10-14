import '../../../core/network/api_client.dart';
import '../domain/auth_session.dart';
import '../domain/auth_user.dart';
import '../domain/password_recovery.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._apiClient, this._useMobileApi);

  final ApiClient _apiClient;
  final bool _useMobileApi;

  Future<AuthSession> login({
    required String identifier,
    required String password,
    required String installationId,
  }) async {
    final response = await _apiClient.post(
      _useMobileApi ? 'auth/login' : 'mobile/v1/auth/login',
      body: {
        'identifier': identifier,
        'password': password,
        'device_name': 'QRDify Flutter',
        'installation_id': installationId,
      },
    );

    final json = _asMap(response);
    return AuthSession(
      accessToken: json['access_token'] as String,
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
      user: _userFromJson(_asMap(json['user'])),
    );
  }

  Future<PasswordRecoveryRequest> requestPasswordReset({
    required String identifier,
  }) async {
    final response = await _apiClient.post(
      _passwordPath('forgot'),
      body: {'identifier': identifier},
    );
    final json = _asMap(response);
    return PasswordRecoveryRequest(
      message:
          json['message'] as String? ??
          'If that account exists, a reset code has been sent.',
      expiresIn: Duration(
        seconds: (json['expires_in'] as num?)?.toInt() ?? 300,
      ),
      resendIn: Duration(seconds: (json['resend_in'] as num?)?.toInt() ?? 60),
    );
  }

  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String password,
  }) async {
    await _apiClient.post(
      _passwordPath('reset'),
      body: {
        'identifier': identifier,
        'code': code,
        'password': password,
        'password_confirmation': password,
      },
    );
  }

  Future<AuthUser> getCurrentUser(String token) async {
    final response = await _apiClient.get('me', token: token);
    final json = _asMap(response);
    final userJson = json['data'] ?? json['user'];
    return _userFromJson(_asMap(userJson));
  }

  Future<AuthUser> uploadProfilePhoto(String token, List<int> bytes) async {
    final response = await _apiClient.postMultipart(
      _profilePhotoPath,
      fields: const {},
      token: token,
      fileField: 'photo',
      fileBytes: bytes,
      fileName: 'profile.png',
    );
    return _userFromJson(_asMap(_asMap(response)['user']));
  }

  Future<AuthUser> removeProfilePhoto(String token) async {
    final response = await _apiClient.delete(_profilePhotoPath, token: token);
    return _userFromJson(_asMap(_asMap(response)['user']));
  }

  String get _profilePhotoPath => _useMobileApi
      ? 'account/profile-photo'
      : 'mobile/v1/account/profile-photo';

  AuthUser _userFromJson(Map<String, dynamic> json) => AuthUser.fromJson({
    ...json,
    'photo_url': _apiClient.publicAssetUrl(json['photo_url'] as String?),
  });

  Future<void> logout(String token) async {
    await _apiClient.post(
      _useMobileApi ? 'auth/logout' : 'logout',
      token: token,
    );
  }

  Future<AuthUser> changePassword(
    String token, {
    required String currentPassword,
    required String password,
  }) async {
    final response = await _apiClient.post(
      _useMobileApi ? '../../change-password' : 'change-password',
      token: token,
      body: {
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': password,
      },
    );
    return _userFromJson(_asMap(_asMap(response)['user']));
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value case Map<String, dynamic> json) return json;
    throw const FormatException('The server returned an unexpected response.');
  }

  String _passwordPath(String action) =>
      _useMobileApi ? '../../password/$action' : 'password/$action';
}
