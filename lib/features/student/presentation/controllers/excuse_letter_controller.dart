import '../../../../core/state/safe_change_notifier.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/excuse_letter.dart';
import '../../domain/excuse_letter_repository.dart';

class ExcuseLetterController extends SafeChangeNotifier {
  ExcuseLetterController(this._repository, this._accessToken);

  final ExcuseLetterRepository _repository;
  final String _accessToken;

  List<ExcuseLetter> letters = const [];
  bool isLoading = false;
  bool isSubmitting = false;
  int? deletingLetterId;
  String? errorMessage;
  String? actionError;

  Future<void> load() async {
    if (isLoading) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      letters = await _repository.fetchLetters(accessToken: _accessToken);
    } catch (error) {
      errorMessage = switch (error) {
        ApiException exception => exception.message,
        FormatException _ => 'QRDify returned letters in an unknown format.',
        _ => 'Unable to load excuse letters. Please try again.',
      };
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submit({
    required String title,
    required DateTime absentDate,
    required String reason,
    required int teacherId,
    List<int>? attachmentBytes,
    String? attachmentName,
  }) async {
    if (isSubmitting) return false;
    isSubmitting = true;
    actionError = null;
    notifyListeners();
    try {
      final letter = await _repository.submitLetter(
        accessToken: _accessToken,
        title: title,
        absentDate: absentDate,
        reason: reason,
        teacherId: teacherId,
        attachmentBytes: attachmentBytes,
        attachmentName: attachmentName,
      );
      letters = [letter, ...letters.where((item) => item.id != letter.id)];
      return true;
    } catch (error) {
      actionError = _message(error, fallback: 'Unable to send excuse letter.');
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> delete(ExcuseLetter letter) async {
    if (letter.status != 'pending') {
      actionError =
          'Reviewed excuse letters cannot be deleted. Contact your teacher.';
      notifyListeners();
      return false;
    }
    if (deletingLetterId != null) return false;
    deletingLetterId = letter.id;
    actionError = null;
    notifyListeners();
    try {
      await _repository.deleteLetter(
        accessToken: _accessToken,
        letterId: letter.id,
      );
      letters = letters.where((item) => item.id != letter.id).toList();
      return true;
    } catch (error) {
      actionError = _message(
        error,
        fallback: 'Unable to delete excuse letter.',
      );
      return false;
    } finally {
      deletingLetterId = null;
      notifyListeners();
    }
  }

  void clearActionError() {
    if (actionError == null) return;
    actionError = null;
    notifyListeners();
  }

  String _message(Object error, {required String fallback}) => switch (error) {
    ApiException exception => exception.message,
    FormatException _ => 'QRDify returned an unknown response.',
    _ => fallback,
  };
}
