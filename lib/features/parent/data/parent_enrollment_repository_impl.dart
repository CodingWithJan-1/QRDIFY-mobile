import '../../../core/network/api_client.dart';
import '../domain/parent_enrollment_repository.dart';

class ParentEnrollmentRepositoryImpl implements ParentEnrollmentRepository {
  const ParentEnrollmentRepositoryImpl(this._apiClient, this._useMobileApi);

  final ApiClient _apiClient;
  final bool _useMobileApi;

  String get _basePath =>
      _useMobileApi ? 'parent-invitations' : 'mobile/v1/parent-invitations';

  @override
  Future<String> requestVerification({required String invitationToken}) async {
    final response = await _apiClient.post(
      '$_basePath/verification',
      body: {'token': invitationToken.trim()},
    );
    final json = _map(response, 'Invalid verification response.');
    final id = json['verification_id']?.toString();
    if (id == null || id.isEmpty) {
      throw const FormatException('Missing verification identifier.');
    }

    return id;
  }

  @override
  Future<ParentEnrollmentResult> acceptInvitation({
    required String invitationToken,
    required String verificationId,
    required String code,
    String? name,
    String? password,
    String? accessToken,
  }) async {
    final response = await _apiClient.post(
      '$_basePath/accept',
      token: accessToken,
      body: {
        'token': invitationToken.trim(),
        'verification_id': verificationId,
        'code': code.trim(),
        if (name != null) 'name': name.trim(),
        if (password != null) ...{
          'password': password,
          'password_confirmation': password,
        },
      },
    );
    final json = _map(response, 'Invalid invitation acceptance response.');
    final data = _map(json['data'], 'Missing invitation acceptance data.');
    final link = _map(data['link'], 'Missing Parent link data.');

    return ParentEnrollmentResult(
      parentUserId: (data['parent_user_id'] as num).toInt(),
      studentId: (link['student_id'] as num).toInt(),
    );
  }

  Map<String, dynamic> _map(Object? value, String message) {
    if (value is Map<String, dynamic>) return value;
    throw FormatException(message);
  }
}
