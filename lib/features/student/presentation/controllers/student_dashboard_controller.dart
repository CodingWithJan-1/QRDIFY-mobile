import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/student_dashboard.dart';
import '../../domain/student_dashboard_repository.dart';

enum DashboardStatus { initial, loading, loaded, failed }

class StudentDashboardController extends ChangeNotifier {
  StudentDashboardController(this._repository, this._accessToken);

  final StudentDashboardRepository _repository;
  final String _accessToken;

  DashboardStatus _status = DashboardStatus.initial;
  StudentDashboard? _dashboard;
  String? _errorMessage;

  DashboardStatus get status => _status;
  StudentDashboard? get dashboard => _dashboard;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == DashboardStatus.loading;

  Future<void> load({bool refresh = false}) async {
    if (isLoading) return;
    if (!refresh && _status == DashboardStatus.loaded) return;

    _status = DashboardStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _dashboard = await _repository.fetchDashboard(
        accessToken: _accessToken,
        month: DateTime.now(),
      );
      _status = DashboardStatus.loaded;
    } on ApiException catch (error) {
      _status = DashboardStatus.failed;
      _errorMessage = error.message;
    } on FormatException {
      _status = DashboardStatus.failed;
      _errorMessage = 'QRDify returned invalid dashboard data.';
    } on Object {
      _status = DashboardStatus.failed;
      _errorMessage = 'Unable to load the dashboard. Please try again.';
    }
    notifyListeners();
  }
}
