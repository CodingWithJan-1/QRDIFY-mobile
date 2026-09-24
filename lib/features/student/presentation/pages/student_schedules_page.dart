import 'package:flutter/material.dart';

import '../../domain/student_schedule.dart';
import '../../domain/student_schedule_repository.dart';
import '../controllers/student_schedule_controller.dart';

class StudentSchedulesPage extends StatefulWidget {
  const StudentSchedulesPage({
    required this.accessToken,
    required this.repository,
    super.key,
  });

  final String accessToken;
  final StudentScheduleRepository repository;

  @override
  State<StudentSchedulesPage> createState() => _StudentSchedulesPageState();
}

class _StudentSchedulesPageState extends State<StudentSchedulesPage> {
  late final StudentScheduleController _controller;

  @override
  void initState() {
    super.initState();
    _controller = StudentScheduleController(
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
      appBar: AppBar(title: const Text('Schedules and alarms')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Add schedule'),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isLoading && _controller.schedules.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_controller.schedules.isEmpty &&
              _controller.errorMessage != null) {
            return _ScheduleMessage(
              icon: Icons.cloud_off_outlined,
              message: _controller.errorMessage!,
              action: OutlinedButton.icon(
                onPressed: _controller.load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _controller.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Alarm settings are saved. Background phone alarms '
                            'will be enabled with the notification service.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_controller.errorMessage case final message?) ...[
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (_controller.schedules.isEmpty)
                  const _ScheduleMessage(
                    icon: Icons.event_note_outlined,
                    message:
                        'No schedules yet. Tap Add schedule to create one.',
                  )
                else
                  ..._controller.schedules.map(
                    (schedule) => _ScheduleCard(
                      schedule: schedule,
                      onEdit: () => _openEditor(schedule),
                      onDelete: () => _confirmDelete(schedule),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openEditor([StudentSchedule? schedule]) async {
    final draft = await showDialog<StudentScheduleDraft>(
      context: context,
      builder: (_) => _ScheduleEditorDialog(schedule: schedule),
    );

    if (draft == null || !mounted) return;
    final saved = await _controller.save(draft, id: schedule?.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? schedule == null
                    ? 'Schedule added.'
                    : 'Schedule updated.'
              : _controller.errorMessage ?? 'Could not save schedule.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(StudentSchedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete schedule?'),
        content: Text('Delete “${schedule.title}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await _controller.delete(schedule.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Schedule deleted.'
              : _controller.errorMessage ?? 'Could not delete schedule.',
        ),
      ),
    );
  }
}

class _ScheduleEditorDialog extends StatefulWidget {
  const _ScheduleEditorDialog({this.schedule});

  final StudentSchedule? schedule;

  @override
  State<_ScheduleEditorDialog> createState() => _ScheduleEditorDialogState();
}

class _ScheduleEditorDialogState extends State<_ScheduleEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime _date;
  late TimeOfDay _time;
  late bool _isAlarm;

  @override
  void initState() {
    super.initState();
    final schedule = widget.schedule;
    _titleController = TextEditingController(text: schedule?.title);
    _descriptionController = TextEditingController(text: schedule?.description);
    _date = DateTime.tryParse(schedule?.date ?? '') ?? DateTime.now();
    _time = _parseTime(schedule?.startTime) ?? TimeOfDay.now();
    _isAlarm = schedule?.isAlarm ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _dateValue(_date);
    return AlertDialog(
      title: Text(widget.schedule == null ? 'Add schedule' : 'Edit schedule'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                maxLength: 255,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a title.'
                    : null,
              ),
              TextFormField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Date'),
                subtitle: Text(dateText),
                onTap: _pickDate,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Start time'),
                subtitle: Text(_time.format(context)),
                onTap: _pickTime,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Alarm'),
                subtitle: const Text('Save this schedule as an alarm'),
                value: _isAlarm,
                onChanged: (value) => setState(() => _isAlarm = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              StudentScheduleDraft(
                title: _titleController.text.trim(),
                description: _nullIfEmpty(_descriptionController.text),
                date: dateText,
                startTime: _timeValue(_time),
                isAlarm: _isAlarm,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) setState(() => _time = picked);
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.onEdit,
    required this.onDelete,
  });

  final StudentSchedule schedule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onEdit,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          child: Icon(
            schedule.isAlarm ? Icons.alarm_on_outlined : Icons.event_outlined,
          ),
        ),
        title: Text(
          schedule.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${_displayDate(schedule.date)} • ${_displayTime(schedule.startTime)}'
          '${schedule.description == null ? '' : '\n${schedule.description}'}',
        ),
        isThreeLine: schedule.description != null,
        trailing: IconButton(
          tooltip: 'Delete schedule',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }
}

class _ScheduleMessage extends StatelessWidget {
  const _ScheduleMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

TimeOfDay? _parseTime(String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _dateValue(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _timeValue(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

String? _nullIfEmpty(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}

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

String _displayTime(String value) {
  final time = _parseTime(value);
  if (time == null) return value;
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
}
