import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/parent_enrollment_repository.dart';

enum ParentEnrollmentStep { invitation, verification, complete }

class ParentEnrollmentController extends ChangeNotifier {
  ParentEnrollmentController(this._repository, {this.accessToken});

  final ParentEnrollmentRepository _repository;
  final String? accessToken;

  ParentEnrollmentStep step = ParentEnrollmentStep.invitation;
  bool isWorking = false;
  bool requiresSignIn = false;
  String? errorMessage;
  String? _invitationToken;
  String? _verificationId;

  bool get isExistingParent => accessToken != null;

  Future<bool> requestCode(String invitationToken) async {
    if (isWorking) return false;
    isWorking = true;
    errorMessage = null;
    notifyListeners();
    try {
      _verificationId = await _repository.requestVerification(
        invitationToken: invitationToken,
      );
      _invitationToken = invitationToken.trim();
      step = ParentEnrollmentStep.verification;
      return true;
    } catch (error) {
      errorMessage = _message(error);
      return false;
    } finally {
      isWorking = false;
      notifyListeners();
    }
  }

  Future<bool> accept({
    required String code,
    String? name,
    String? password,
  }) async {
    if (isWorking || _invitationToken == null || _verificationId == null) {
      return false;
    }
    isWorking = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _repository.acceptInvitation(
        invitationToken: _invitationToken!,
        verificationId: _verificationId!,
        code: code,
        name: isExistingParent ? null : name,
        password: isExistingParent ? null : password,
        accessToken: accessToken,
      );
      step = ParentEnrollmentStep.complete;
      return true;
    } on ApiException catch (error) {
      if (error.code == 'sign_in_required') {
        requiresSignIn = true;
      } else {
        errorMessage = _message(error);
      }
      return false;
    } catch (error) {
      errorMessage = _message(error);
      return false;
    } finally {
      isWorking = false;
      notifyListeners();
    }
  }

  void startOver() {
    step = ParentEnrollmentStep.invitation;
    requiresSignIn = false;
    errorMessage = null;
    _invitationToken = null;
    _verificationId = null;
    notifyListeners();
  }

  String _message(Object error) => switch (error) {
    ApiException exception when exception.code == 'state_conflict' => 'The invited email is already used by another QRDify account or requires school review. Ask the teacher to verify the Parent email and issue a new invitation.',
    ApiException exception => exception.message,
    FormatException _ => 'QRDify returned an unknown enrollment response.',
    _ => 'Unable to continue Parent enrollment. Please try again.',
  };
}
