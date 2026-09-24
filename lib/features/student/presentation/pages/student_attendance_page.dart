import 'package:flutter/material.dart';

import '../../domain/student_attendance.dart';
import '../../domain/student_attendance_repository.dart';
import '../controllers/student_attendance_controller.dart';

class StudentAttendancePage extends StatefulWidget {
  const StudentAttendancePage({
    required this.accessToken,
    required this.repository,
    super.key,
  });

  final String accessToken;
  final StudentAttendanceRepository repository;

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  late final StudentAttendanceController _controller;

  @override
  void initState() {
    super.initState();
    _controller = StudentAttendanceController(
      widget.repository,
      widget.accessToken,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance record')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isLoading && _controller.records.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_controller.records.isEmpty && _controller.errorMessage != null) {
            return _ErrorView(
              message: _controller.errorMessage!,
              onRetry: () => _controller.load(refresh: true),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _controller.load(refresh: true),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_controller.summary case final summary?)
                  _Summary(summary: summary),
                const SizedBox(height: 24),
                Text(
                  'History',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (_controller.records.isEmpty)
                  const _EmptyView()
                else
                  ..._controller.records.map(
                    (record) => _AttendanceTile(record: record),
                  ),
                if (_controller.errorMessage case final message?) ...[
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (_controller.hasMore) ...[
                  const SizedBox(height: 8),
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

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final AttendanceRecordSummary summary;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('Present', summary.present, Icons.check_circle_outline),
      ('Late', summary.late, Icons.schedule_outlined),
      ('Absent', summary.absent, Icons.cancel_outlined),
      ('Records', summary.total, Icons.list_alt_outlined),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.insights_outlined, size: 34),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recorded attendance rate'),
                      Text(
                        '${summary.presentPercentage.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final value in values)
                  SizedBox(
                    width: width,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(
                              value.$3,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${value.$2}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(value.$1),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({required this.record});

  final StudentAttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(child: Icon(_statusIcon(record.status))),
        title: Text(
          _displayDate(record.date),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(_timeLine(record)),
        trailing: _StatusBadge(status: record.status),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'present' || 'early' => Colors.green,
      'late' => Colors.orange,
      'absent' => Colors.red,
      'excused' => Colors.blue,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _sentenceCase(status),
        style: TextStyle(color: color.shade700, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          children: [
            Icon(Icons.event_available_outlined, size: 42),
            SizedBox(height: 10),
            Text('No attendance records yet.'),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _statusIcon(String status) => switch (status) {
  'present' || 'early' => Icons.check,
  'late' => Icons.schedule,
  'absent' => Icons.close,
  'excused' => Icons.description_outlined,
  _ => Icons.help_outline,
};

String _timeLine(StudentAttendanceRecord record) {
  final timeIn = _shortTime(record.timeIn);
  final timeOut = _shortTime(record.timeOut);
  if (timeIn == null && timeOut == null) {
    return record.remarks ?? 'No scan time';
  }
  return 'In: ${timeIn ?? '--'}  •  Out: ${timeOut ?? '--'}';
}

String? _shortTime(String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : value;
}

String _sentenceCase(String value) => value.isEmpty
    ? 'Unknown'
    : '${value[0].toUpperCase()}${value.substring(1).replaceAll('_', ' ')}';

String _displayDate(String value) {
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
