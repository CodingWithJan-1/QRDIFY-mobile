import 'package:flutter/foundation.dart';

abstract final class NotificationSignals {
  static final refresh = ValueNotifier<int>(0);
  static final openRequest = ValueNotifier<Map<String, dynamic>?>(null);
  static final pushStatus = ValueNotifier<String?>(null);
  static void received() => changed();
  static void changed() => refresh.value++;
}
