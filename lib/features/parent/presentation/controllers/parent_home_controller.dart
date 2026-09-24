import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/parent_child.dart';
import '../../domain/parent_dashboard.dart';
import '../../domain/parent_repository.dart';

class ParentHomeController extends ChangeNotifier {
  ParentHomeController(this._repository, this._accessToken);

  final ParentRepository _repository;
  final String _accessToken;

  final List<ParentChild> children = [];
  ParentChild? selectedChild;
  ParentChildDashboard? dashboard;
  bool isLoading = false;
  String? errorMessage;

  Future<void> load({bool refresh = false}) async {
    if (isLoading || (!refresh && children.isNotEmpty)) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final loaded = await _repository.fetchChildren(accessToken: _accessToken);
      final previousId = selectedChild?.id;
      children
        ..clear()
        ..addAll(loaded);
      selectedChild = children.isEmpty
          ? null
          : children.firstWhere(
              (child) => child.id == previousId,
              orElse: () => children.first,
            );
      await _loadDashboard();
    } catch (error) {
      errorMessage = _message(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectChild(ParentChild child) async {
    if (selectedChild?.id == child.id) return;
    selectedChild = child;
    dashboard = null;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _loadDashboard();
    } catch (error) {
      errorMessage = _message(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadDashboard() async {
    final child = selectedChild;
    if (child == null) {
      dashboard = null;
      return;
    }
    dashboard = await _repository.fetchDashboard(
      accessToken: _accessToken,
      childId: child.id,
      month: DateTime.now(),
    );
  }

  String _message(Object error) => switch (error) {
    ApiException exception => exception.message,
    FormatException _ => 'QRDify returned Parent data in an unknown format.',
    _ => 'Unable to load linked children. Please try again.',
  };
}
