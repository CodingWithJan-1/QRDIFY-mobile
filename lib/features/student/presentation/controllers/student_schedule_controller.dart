import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/student_schedule.dart';
import '../../domain/student_schedule_repository.dart';

class StudentScheduleController extends ChangeNotifier {
  StudentScheduleController(this._repository, this._accessToken);

  final StudentScheduleRepository _repository;
  final String _accessToken;

  List<StudentSchedule> schedules = const [];
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  Future<void> load() async {
    if (isLoading) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _repository.fetchSchedules(
        accessToken: _accessToken,
      );
      result.sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        return dateCompare != 0
            ? dateCompare
            : a.startTime.compareTo(b.startTime);
      });
      schedules = result;
    } catch (error) {
      errorMessage = _messageFor(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> save(StudentScheduleDraft draft, {int? id}) async {
    if (isSaving) return false;
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      if (id == null) {
        await _repository.createSchedule(
          accessToken: _accessToken,
          draft: draft,
        );
      } else {
        await _repository.updateSchedule(
          accessToken: _accessToken,
          id: id,
          draft: draft,
        );
      }
      await _reloadAfterWrite();
      return true;
    } catch (error) {
      errorMessage = _messageFor(error);
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> delete(int id) async {
    if (isSaving) return false;
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _repository.deleteSchedule(accessToken: _accessToken, id: id);
      schedules = schedules.where((schedule) => schedule.id != id).toList();
      return true;
    } catch (error) {
      errorMessage = _messageFor(error);
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _reloadAfterWrite() async {
    final result = await _repository.fetchSchedules(accessToken: _accessToken);
    result.sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      return dateCompare != 0
          ? dateCompare
          : a.startTime.compareTo(b.startTime);
    });
    schedules = result;
  }

  String _messageFor(Object error) => switch (error) {
    ApiException exception => exception.message,
    FormatException _ => 'QRDify returned schedule data in an unknown format.',
    _ => 'Unable to update schedules. Please try again.',
  };
}
