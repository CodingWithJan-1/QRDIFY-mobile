import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/student_attendance.dart';
import '../../domain/student_attendance_repository.dart';

class StudentAttendanceController extends ChangeNotifier {
  StudentAttendanceController(this._repository, this._accessToken);

  final StudentAttendanceRepository _repository;
  final String _accessToken;

  AttendanceRecordSummary? summary;
  final List<StudentAttendanceRecord> records = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  String? errorMessage;
  int _currentPage = 0;
  int _lastPage = 1;

  bool get hasMore => _currentPage < _lastPage;

  Future<void> load({bool refresh = false}) async {
    if (isLoading || isLoadingMore) return;
    if (!refresh && records.isNotEmpty) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.fetchAttendance(
        accessToken: _accessToken,
      );
      summary = result.summary;
      records
        ..clear()
        ..addAll(result.records);
      _currentPage = result.currentPage;
      _lastPage = result.lastPage;
    } catch (error) {
      errorMessage = _messageFor(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || isLoading || isLoadingMore) return;
    isLoadingMore = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.fetchAttendance(
        accessToken: _accessToken,
        page: _currentPage + 1,
      );
      records.addAll(result.records);
      _currentPage = result.currentPage;
      _lastPage = result.lastPage;
    } catch (error) {
      errorMessage = _messageFor(error);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  String _messageFor(Object error) => switch (error) {
    ApiException exception => exception.message,
    FormatException _ =>
      'QRDify returned attendance data in an unknown format.',
    _ => 'Unable to load attendance. Please try again.',
  };
}
