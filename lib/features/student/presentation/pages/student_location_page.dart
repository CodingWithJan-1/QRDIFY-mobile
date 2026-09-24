import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/student_location.dart';
import '../controllers/student_location_controller.dart';

class StudentLocationPage extends StatelessWidget {
  const StudentLocationPage({required this.controller, super.key});

  final StudentLocationController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus location')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _StatusCard(controller: controller),
              const SizedBox(height: 16),
              _PrivacyCard(controller: controller),
              const SizedBox(height: 16),
              _Actions(controller: controller),
            ],
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.controller});

  final StudentLocationController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presentation = _statusPresentation(controller);

    return Card(
      color: presentation.color(theme.colorScheme),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(presentation.icon, size: 40),
            const SizedBox(height: 12),
            Text(
              presentation.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(presentation.message),
            if (controller.latestLocation case final location?) ...[
              const SizedBox(height: 16),
              Text(
                'GPS accuracy: about ${location.accuracyMeters.round()} m',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (controller.lastReportedAt case final reportedAt?) ...[
              const SizedBox(height: 4),
              Text(
                'Last sent: ${_formatTime(reportedAt)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (controller.isReporting) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (controller.errorMessage case final error?) ...[
              const SizedBox(height: 12),
              Text(error, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.controller});

  final StudentLocationController controller;

  @override
  Widget build(BuildContext context) {
    final supportsAndroidBackground =
        defaultTargetPlatform == TargetPlatform.android;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Before you start',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'By starting, you consent to QRDify collecting campus location '
              'for school safety during the configured school days and hours. '
              '${supportsAndroidBackground ? 'On Android, sharing may continue in the background with a persistent notification. ' : 'The operating system may pause updates when this app is not active. '}'
              'A powered-off, force-stopped, offline, battery-restricted, or '
              'permission-blocked phone cannot send a current location. You '
              'can stop sharing and revoke consent here at any time.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  controller.serverConsentEnabled
                      ? Icons.verified_user_outlined
                      : Icons.shield_outlined,
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    controller.isConsentLoading
                        ? 'Checking consent status…'
                        : controller.serverConsentEnabled
                        ? 'Location consent is active.'
                        : 'Location consent is not active.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.controller});

  final StudentLocationController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.status;
    if (status == StudentLocationStatus.checking ||
        controller.isConsentLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (status == StudentLocationStatus.serviceDisabled) {
      return FilledButton.icon(
        onPressed: controller.openLocationSettings,
        icon: const Icon(Icons.settings_outlined),
        label: const Text('Open location settings'),
      );
    }

    if (status == StudentLocationStatus.permissionDeniedForever) {
      return FilledButton.icon(
        onPressed: controller.openAppSettings,
        icon: const Icon(Icons.settings_outlined),
        label: const Text('Open app settings'),
      );
    }

    if (controller.isSessionEnabled) {
      return FilledButton.tonalIcon(
        onPressed: controller.stop,
        icon: const Icon(Icons.location_off_outlined),
        label: const Text('Stop location sharing'),
      );
    }

    return FilledButton.icon(
      onPressed: controller.start,
      icon: const Icon(Icons.my_location_outlined),
      label: Text(
        status == StudentLocationStatus.idle
            ? 'Start location sharing'
            : 'Try again',
      ),
    );
  }
}

_StatusPresentation _statusPresentation(StudentLocationController controller) {
  final report = controller.latestReport;
  if (controller.isTracking &&
      controller.boundaryState == BoundaryState.outside) {
    return _StatusPresentation(
      title: 'Outside the campus boundary',
      message:
          report?.breachStatus == 'open' ||
              report?.breachStatus == 'acknowledged'
          ? 'The confirmed exit was reported to QRDify.'
          : 'QRDify is confirming the outside reading on this phone.',
      icon: Icons.warning_amber_rounded,
      color: _errorContainer,
    );
  }
  if (controller.isTracking &&
      controller.boundaryState == BoundaryState.inside) {
    return const _StatusPresentation(
      title: 'Inside the campus boundary',
      message: 'Checked on this phone. No routine location was uploaded.',
      icon: Icons.location_on_outlined,
      color: _primaryContainer,
    );
  }

  return switch (controller.status) {
    StudentLocationStatus.idle => const _StatusPresentation(
      title: 'Location sharing is off',
      message: 'Start sharing when you are ready.',
      icon: Icons.location_off_outlined,
      color: _surfaceContainer,
    ),
    StudentLocationStatus.checking => const _StatusPresentation(
      title: 'Checking location access',
      message: 'Please wait.',
      icon: Icons.location_searching_outlined,
      color: _surfaceContainer,
    ),
    StudentLocationStatus.serviceDisabled => const _StatusPresentation(
      title: 'Phone location is off',
      message: 'Turn on the phone location service, then try again.',
      icon: Icons.gps_off_outlined,
      color: _errorContainer,
    ),
    StudentLocationStatus.permissionDenied => const _StatusPresentation(
      title: 'Location permission was denied',
      message: 'QRDify needs permission before it can share your location.',
      icon: Icons.location_disabled_outlined,
      color: _errorContainer,
    ),
    StudentLocationStatus.permissionDeniedForever => const _StatusPresentation(
      title: 'Location permission is blocked',
      message: 'Allow location access from the app settings, then try again.',
      icon: Icons.location_disabled_outlined,
      color: _errorContainer,
    ),
    StudentLocationStatus.paused => const _StatusPresentation(
      title: 'Location sharing is paused',
      message: 'QRDify will resume when the app returns to the foreground.',
      icon: Icons.pause_circle_outline,
      color: _surfaceContainer,
    ),
    StudentLocationStatus.tracking => _StatusPresentation(
      title: report == null
          ? 'Finding your location'
          : 'Location sharing is active',
      message: report == null
          ? 'Waiting for an accurate GPS update.'
          : 'The server accepted the latest boundary event.',
      icon: Icons.location_searching_outlined,
      color: _primaryContainer,
    ),
    StudentLocationStatus.failed => const _StatusPresentation(
      title: 'Location sharing could not start',
      message: 'Check the phone settings and try again.',
      icon: Icons.error_outline,
      color: _errorContainer,
    ),
  };
}

class _StatusPresentation {
  const _StatusPresentation({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color Function(ColorScheme) color;
}

Color _primaryContainer(ColorScheme colors) => colors.primaryContainer;
Color _errorContainer(ColorScheme colors) => colors.errorContainer;
Color _surfaceContainer(ColorScheme colors) => colors.surfaceContainerHighest;

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour == 0
      ? 12
      : (local.hour > 12 ? local.hour - 12 : local.hour);
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}
