import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_bootstrap.dart';
import 'auth_gate.dart';

class QrdifyApp extends StatefulWidget {
  const QrdifyApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  State<QrdifyApp> createState() => _QrdifyAppState();
}

class _QrdifyAppState extends State<QrdifyApp> {
  @override
  void initState() {
    super.initState();
    widget.dependencies.authController.initialize();
  }

  @override
  void dispose() {
    widget.dependencies.authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TWCES - QRDify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AuthGate(
        controller: widget.dependencies.authController,
        studentDashboardRepository:
            widget.dependencies.studentDashboardRepository,
        studentAttendanceRepository:
            widget.dependencies.studentAttendanceRepository,
        studentScheduleRepository:
            widget.dependencies.studentScheduleRepository,
        studentLocationRepository:
            widget.dependencies.studentLocationRepository,
        deviceLocationService: widget.dependencies.deviceLocationService,
        excuseLetterRepository: widget.dependencies.excuseLetterRepository,
        notificationRepository: widget.dependencies.notificationRepository,
        parentRepository: widget.dependencies.parentRepository,
        parentEnrollmentRepository:
            widget.dependencies.parentEnrollmentRepository,
      ),
    );
  }
}
