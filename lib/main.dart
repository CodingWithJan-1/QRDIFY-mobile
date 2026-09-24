import 'package:flutter/material.dart';

import 'app/app_bootstrap.dart';
import 'app/qrdify_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = AppBootstrap.create();
  runApp(QrdifyApp(dependencies: dependencies));
}
