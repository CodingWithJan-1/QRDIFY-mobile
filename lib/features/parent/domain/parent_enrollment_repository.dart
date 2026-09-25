enum ParentInvitationChannel { email, sms }

class ParentEnrollmentResult {
  const ParentEnrollmentResult({
    required this.parentUserId,
    required this.studentId,
  });

  final int parentUserId;
  final int studentId;
}

abstract interface class ParentEnrollmentRepository {
  Future<String> requestVerification({required String invitationToken});

  Future<ParentEnrollmentResult> acceptInvitation({
    required String invitationToken,
    required String verificationId,
    required String code,
    String? name,
    String? password,
    String? accessToken,
  });
}
