import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../controllers/parent_home_controller.dart';
import '../widgets/parent_design.dart';

class ParentDashboardPage extends StatelessWidget {
  const ParentDashboardPage({required this.controller, super.key});

  final ParentHomeController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParentDesign.background,
      appBar: const ParentPageHeader(title: 'Child overview'),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final child = controller.selectedChild;
          final dashboard = controller.dashboard;
          if (child == null) {
            return const ParentEmptyState(
              icon: Icons.family_restroom_outlined,
              title: 'Choose a child first',
              message: 'Select a linked child from the Children tab.',
            );
          }
          if (controller.isLoading && dashboard == null) {
            return const ParentLoadingView();
          }
          if (dashboard == null) {
            return ParentEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Overview unavailable',
              message: controller.errorMessage ?? 'Please try again.',
              action: OutlinedButton.icon(
                onPressed: () => controller.load(refresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => controller.load(refresh: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
              children: [
                ParentChildIdentity(child: child),
                const Divider(height: 34),
                const ParentSectionLabel("Today's status"),
                const SizedBox(height: 14),
                _TodayStatus(
                  status: dashboard.todayStatus,
                  timeIn: dashboard.todayTimeIn,
                ),
                const Divider(height: 36),
                const ParentSectionLabel('Attendance summary'),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  children: [
                    _CountCard(
                      label: 'Present',
                      value: dashboard.present,
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.success,
                    ),
                    _CountCard(
                      label: 'Late',
                      value: dashboard.late,
                      icon: Icons.schedule_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                    _CountCard(
                      label: 'Absent',
                      value: dashboard.absent,
                      icon: Icons.event_busy_rounded,
                      color: AppColors.danger,
                    ),
                    _CountCard(
                      label: 'Excused',
                      value: dashboard.excused,
                      icon: Icons.description_outlined,
                      color: AppColors.blue,
                    ),
                  ],
                ),
                if (!dashboard.summaryComplete) ...[
                  const SizedBox(height: 22),
                  const Divider(),
                  const SizedBox(height: 12),
                  const _InformationNote(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TodayStatus extends StatelessWidget {
  const _TodayStatus({required this.status, required this.timeIn});

  final String status;
  final String? timeIn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 38,
            color: AppColors.muted,
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sentenceCase(status),
                  style: const TextStyle(
                    color: ParentDesign.deepInk,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                if (timeIn != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Time in: ${_shortTime(timeIn)}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParentDesign.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const Spacer(),
          Text(
            '$value',
            style: const TextStyle(
              color: ParentDesign.deepInk,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _InformationNote extends StatelessWidget {
  const _InformationNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: AppColors.muted, size: 28),
        SizedBox(width: 14),
        Expanded(
          child: Text(
            'Counts use recorded attendance. Missing school days are not treated as absences.',
            style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.5),
          ),
        ),
      ],
    );
  }
}

String _sentenceCase(String value) => value.isEmpty
    ? 'Pending'
    : '${value[0].toUpperCase()}${value.substring(1)}';

String _shortTime(String? value) =>
    value == null ? '' : value.split(':').take(2).join(':');
