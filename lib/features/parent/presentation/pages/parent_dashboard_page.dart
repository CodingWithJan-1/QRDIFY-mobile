import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/domain/attendance_sessions.dart';
import '../controllers/parent_home_controller.dart';
import '../widgets/parent_design.dart';

class ParentDashboardPage extends StatelessWidget {
  const ParentDashboardPage({
    required this.controller,
    required this.onChangeChild,
    super.key,
  });

  final ParentHomeController controller;
  final VoidCallback onChangeChild;

  @override
  Widget build(BuildContext context) {
    final child = controller.selectedChild;
    return Scaffold(
      backgroundColor: ParentDesign.background,
      appBar: ParentPageHeader(
        title: 'Overview',
        child: child,
        onChangeChild: onChangeChild,
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
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
                  status: dashboard.todaySessions.dayStatus(
                    dashboard.todayStatus,
                  ),
                  timeIn: dashboard.todayTimeIn,
                  timeOut: dashboard.todayTimeOut,
                  sessions: dashboard.todaySessions,
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
                    if (dashboard.halfDay > 0)
                      _CountCard(
                        label: 'Half-day',
                        value: dashboard.halfDay,
                        icon: Icons.timelapse,
                        color: Colors.deepOrange,
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
  const _TodayStatus({
    required this.status,
    required this.timeIn,
    required this.timeOut,
    required this.sessions,
  });

  final String status;
  final String? timeIn;
  final String? timeOut;
  final AttendanceSessions sessions;

  bool get hasAttendanceTime => timeIn != null || timeOut != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ParentDesign.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 34,
            color: AppColors.muted,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status == 'pending' && !hasAttendanceTime
                      ? 'Awaiting attendance'
                      : attendanceStatusLabel(status),
                  style: const TextStyle(
                    color: ParentDesign.deepInk,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                if (!hasAttendanceTime) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'No gate scans recorded.',
                    style: TextStyle(color: AppColors.muted, height: 1.35),
                  ),
                ],
                if (sessions.hasDetails) ...[
                  const SizedBox(height: 8),
                  Text(
                    sessions.description,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
                if (timeIn != null || timeOut != null) ...[
                  const SizedBox(height: 12),
                  if (timeIn != null)
                    _AttendanceTimestamp(
                      icon: Icons.login_rounded,
                      label: 'Checked in',
                      time: timeIn!,
                    ),
                  if (timeIn != null && timeOut != null)
                    const SizedBox(height: 8),
                  if (timeOut != null)
                    _AttendanceTimestamp(
                      icon: Icons.logout_rounded,
                      label: 'Checked out',
                      time: timeOut!,
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

class _AttendanceTimestamp extends StatelessWidget {
  const _AttendanceTimestamp({
    required this.icon,
    required this.label,
    required this.time,
  });

  final IconData icon;
  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.blue),
        const SizedBox(width: 8),
        Text(
          '$label · ${_formatAttendanceTime(time)}',
          style: const TextStyle(
            color: ParentDesign.deepInk,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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

String _formatAttendanceTime(String value) {
  final timestamp = DateTime.tryParse(value);
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
  final hour = timestamp?.toLocal().hour ?? int.tryParse(match?.group(1) ?? '');
  final minute =
      timestamp?.toLocal().minute ?? int.tryParse(match?.group(2) ?? '');
  if (hour == null || minute == null) return value;

  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  final minuteText = minute.toString().padLeft(2, '0');
  final period = hour < 12 ? 'AM' : 'PM';
  return '$hour12:$minuteText $period';
}
