import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/parent_attendance.dart';
import '../../domain/parent_child.dart';
import '../../domain/parent_repository.dart';
import '../controllers/parent_attendance_controller.dart';
import '../widgets/parent_design.dart';

class ParentAttendancePage extends StatefulWidget {
  const ParentAttendancePage({
    required this.accessToken,
    required this.repository,
    required this.child,
    this.absencesOnly = false,
    super.key,
  });

  final String accessToken;
  final ParentRepository repository;
  final ParentChild child;
  final bool absencesOnly;

  @override
  State<ParentAttendancePage> createState() => _ParentAttendancePageState();
}

class _ParentAttendancePageState extends State<ParentAttendancePage> {
  late final ParentAttendanceController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ParentAttendanceController(
      widget.repository,
      widget.accessToken,
      childId: widget.child.id,
      absencesOnly: widget.absencesOnly,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.absencesOnly ? 'Absences' : 'Attendance';
    return Scaffold(
      backgroundColor: ParentDesign.background,
      appBar: ParentPageHeader(title: title),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isLoading && _controller.records.isEmpty) {
            return const ParentLoadingView();
          }

          return RefreshIndicator(
            onRefresh: () => _controller.load(refresh: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
              children: [
                ParentChildIdentity(
                  child: widget.child,
                  card: widget.absencesOnly,
                ),
                if (!widget.absencesOnly) const Divider(height: 28),
                if (!widget.absencesOnly && _controller.summary != null) ...[
                  _SummaryCard(summary: _controller.summary!),
                  const SizedBox(height: 24),
                ],
                _HistoryHeader(absencesOnly: widget.absencesOnly),
                const SizedBox(height: 12),
                if (_controller.errorMessage case final message?)
                  ParentEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Records unavailable',
                    message: message,
                    action: OutlinedButton.icon(
                      onPressed: () => _controller.load(refresh: true),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  )
                else if (_controller.records.isEmpty)
                  ParentEmptyState(
                    icon: widget.absencesOnly
                        ? Icons.event_busy_outlined
                        : Icons.fact_check_outlined,
                    title: widget.absencesOnly
                        ? 'No absences recorded'
                        : 'No attendance recorded',
                    message: widget.absencesOnly
                        ? 'Recorded absences for this child will appear here.'
                        : 'Recorded attendance for this child will appear here.',
                  )
                else
                  _AttendanceHistory(records: _controller.records),
                if (_controller.hasMore) ...[
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: _controller.isLoadingMore
                        ? null
                        : _controller.loadMore,
                    child: _controller.isLoadingMore
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Load more'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.absencesOnly});

  final bool absencesOnly;

  @override
  Widget build(BuildContext context) {
    if (absencesOnly) {
      return const Padding(
        padding: EdgeInsets.only(top: 18),
        child: ParentSectionLabel('Recorded absences'),
      );
    }

    return Row(
      children: [
        const Expanded(child: ParentSectionLabel('Attendance history')),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ParentDesign.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_outlined, size: 20),
              const SizedBox(width: 7),
              Text(
                _monthLabel(DateTime.now()),
                style: const TextStyle(
                  color: ParentDesign.deepInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final ParentAttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 18),
      decoration: BoxDecoration(
        color: ParentDesign.softBlue,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: ParentDesign.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ParentSectionLabel('Recorded attendance'),
          const SizedBox(height: 14),
          Row(
            children: [
              _RateRing(value: summary.presentPercentage),
              const SizedBox(width: 12),
              const SizedBox(
                width: 82,
                child: Text(
                  'Attendance\nrate',
                  maxLines: 2,
                  style: TextStyle(
                    color: ParentDesign.deepInk,
                    fontSize: 13,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _SummaryNumber(label: 'Present', value: summary.present),
              Container(
                height: 58,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: ParentDesign.line,
              ),
              _SummaryNumber(label: 'Absent', value: summary.absent),
            ],
          ),
        ],
      ),
    );
  }
}

class _RateRing extends StatelessWidget {
  const _RateRing({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 72,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: (value / 100).clamp(0, 1),
            strokeWidth: 10,
            backgroundColor: const Color(0xFFC8DCF8),
            color: AppColors.blue,
          ),
          Center(
            child: Text(
              '${value.toStringAsFixed(1)}%',
              style: const TextStyle(
                color: AppColors.blue,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryNumber extends StatelessWidget {
  const _SummaryNumber({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: ParentDesign.deepInk,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _AttendanceHistory extends StatelessWidget {
  const _AttendanceHistory({required this.records});

  final List<ParentAttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: ParentDesign.line),
      ),
      child: Column(
        children: [
          for (var index = 0; index < records.length; index++) ...[
            _AttendanceRow(record: records[index]),
            if (index != records.length - 1)
              const Divider(height: 1, indent: 68, endIndent: 14),
          ],
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.record});

  final ParentAttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(record.status);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_statusIcon(record.status), color: color, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(record.date),
                  style: const TextStyle(
                    color: ParentDesign.deepInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _details(record.timeIn, record.timeOut, record.remarks),
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusChip(status: record.status),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Text(
          _sentenceCase(status),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

Color _statusColor(String status) => switch (status.toLowerCase()) {
  'present' || 'early' => AppColors.success,
  'late' => const Color(0xFFF59E0B),
  'absent' => AppColors.danger,
  'excused' => AppColors.blue,
  _ => AppColors.muted,
};

IconData _statusIcon(String status) => switch (status.toLowerCase()) {
  'present' || 'early' => Icons.check_rounded,
  'late' => Icons.schedule_rounded,
  'absent' => Icons.event_busy_rounded,
  'excused' => Icons.description_outlined,
  _ => Icons.help_outline_rounded,
};

String _details(String? timeIn, String? timeOut, String? remarks) {
  final values = <String>[
    ?timeIn == null ? null : 'In ${_shortTime(timeIn)}',
    ?timeOut == null ? null : 'Out ${_shortTime(timeOut)}',
    ?remarks,
  ];
  return values.isEmpty ? 'No time recorded' : values.join(' • ');
}

String _shortTime(String value) => value.split(':').take(2).join(':');

String _sentenceCase(String value) => value.isEmpty
    ? 'Unknown'
    : '${value[0].toUpperCase()}${value.substring(1).replaceAll('_', ' ')}';

String _formatDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _monthLabel(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.year}';
}
