import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/parent_attendance.dart';
import '../../domain/parent_repository.dart';

class ParentAttendanceController extends ChangeNotifier {
  ParentAttendanceController(
    this._repository,
    this._accessToken, {
    required this.childId,
    required this.absencesOnly,
  });

  final ParentRepository _repository;
  final String _accessToken;
  final int childId;
  final bool absencesOnly;
  final List<ParentAttendanceRecord> records = [];
  ParentAttendanceSummary? summary;
  bool isLoading = false;
  bool isLoadingMore = false;
  String? errorMessage;
  int _page = 0;
  int _lastPage = 1;

  bool get hasMore => _page < _lastPage;

  Future<void> load({bool refresh = false}) async {
    if (isLoading || (!refresh && records.isNotEmpty)) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _fetch(1);
      records
        ..clear()
        ..addAll(result.records);
      summary = result.summary;
      _page = result.currentPage;
      _lastPage = result.lastPage;
    } catch (error) {
      errorMessage = _message(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || isLoading || isLoadingMore) return;
    isLoadingMore = true;
    notifyListeners();
    try {
      final result = await _fetch(_page + 1);
      records.addAll(result.records);
      _page = result.currentPage;
      _lastPage = result.lastPage;
    } catch (error) {
      errorMessage = _message(error);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<ParentAttendanceResult> _fetch(int page) =>
      _repository.fetchAttendance(
        accessToken: _accessToken,
        childId: childId,
        page: page,
        absencesOnly: absencesOnly,
      );

  String _message(Object error) => switch (error) {
    ApiException exception => exception.message,
    FormatException _ => 'QRDify returned attendance in an unknown format.',
    _ => 'Unable to load attendance. Please try again.',
  };
}
