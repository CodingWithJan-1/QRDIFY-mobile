import 'package:flutter/foundation.dart';

// Session invalidation can dispose a page before its pending API call finishes.
// Late completions must not notify listeners belonging to a removed account UI.
abstract class SafeChangeNotifier extends ChangeNotifier {
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
