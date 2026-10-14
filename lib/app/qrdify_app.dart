import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_bootstrap.dart';
import 'auth_gate.dart';

import 'dart:async';

import '../core/storage/private_file_picker.dart';

class QrdifyApp extends StatefulWidget {
  const QrdifyApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  State<QrdifyApp> createState() => _QrdifyAppState();
}

class _QrdifyAppState extends State<QrdifyApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  String? _lastToken;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.dependencies.authController.addListener(_onAuthChanged);
    unawaited(PrivateFilePicker.clearTemporaryFiles());
    widget.dependencies.authController.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.dependencies.authController.removeListener(_onAuthChanged);
    widget.dependencies.authController.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    final session = widget.dependencies.authController.session;
    final token = session?.accessToken;
    if (token != _lastToken ||
        widget.dependencies.authController.mustChangePassword) {
      _lastToken = token;
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (token == null) unawaited(PrivateFilePicker.clearTemporaryFiles());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.dependencies.authController.revalidateSession());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
