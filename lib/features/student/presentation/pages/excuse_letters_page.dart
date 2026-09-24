import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../domain/excuse_letter.dart';
import '../../domain/excuse_letter_repository.dart';
import '../controllers/excuse_letter_controller.dart';

class ExcuseLettersPage extends StatefulWidget {
  const ExcuseLettersPage({
    required this.accessToken,
    required this.repository,
    super.key,
  });

  final String accessToken;
  final ExcuseLetterRepository repository;

  @override
  State<ExcuseLettersPage> createState() => _ExcuseLettersPageState();
}

class _ExcuseLettersPageState extends State<ExcuseLettersPage> {
  late final ExcuseLetterController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ExcuseLetterController(widget.repository, widget.accessToken)
      ..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Excuse letters')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isLoading && _controller.letters.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: _controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _CreateCard(
                  enabled: !_controller.isLoading,
                  onPressed: _openCreateForm,
                ),
                if (_controller.actionError case final message?) ...[
                  const SizedBox(height: 12),
                  _Message(icon: Icons.error_outline_rounded, text: message),
                ],
                if (_controller.errorMessage case final message?) ...[
                  const SizedBox(height: 16),
                  _Message(
                    icon: Icons.cloud_off_outlined,
                    text: message,
                    onRetry: _controller.load,
                  ),
                ] else if (_controller.letters.isEmpty) ...[
                  const SizedBox(height: 28),
                  const _Message(
                    icon: Icons.description_outlined,
                    text: 'No excuse letters yet.',
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  ..._controller.letters.map(
                    (letter) => _LetterCard(
                      letter: letter,
                      isDeleting: _controller.deletingLetterId == letter.id,
                      onDelete: () => _confirmDelete(letter),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openCreateForm() async {
    _controller.clearActionError();
    if (_controller.teachers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No Teachers are available for excuse submission.'),
        ),
      );
      return;
    }
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: _CreateExcuseSheet(controller: _controller),
      ),
    );
    if (!mounted || submitted != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Your excuse letter was sent. Please wait for your Teacher’s review.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(ExcuseLetter letter) async {
    _controller.clearActionError();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Delete excuse letter?'),
        content: Text(
          'Delete “${letter.title}”? This follows the same permanent delete '
          'behavior as the Student web app.',
        ),
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
    final deleted = await _controller.delete(letter);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Excuse letter deleted.'
              : _controller.actionError ?? 'Unable to delete excuse letter.',
        ),
      ),
    );
  }
}

class _CreateCard extends StatelessWidget {
  const _CreateCard({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.mark_email_unread_outlined,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need to explain an absence?',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 3),
                  Text('Send a letter and optional supporting document.'),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 112,
              child: FilledButton.icon(
                onPressed: enabled ? onPressed : null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateExcuseSheet extends StatefulWidget {
  const _CreateExcuseSheet({required this.controller});

  final ExcuseLetterController controller;

  @override
  State<_CreateExcuseSheet> createState() => _CreateExcuseSheetState();
}

class _CreateExcuseSheetState extends State<_CreateExcuseSheet> {
  static const _maxAttachmentBytes = 5 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _dateController = TextEditingController();
  final _reasonController = TextEditingController();
  int? _teacherId;
  DateTime? _absentDate;
  PlatformFile? _attachment;
  int? _attachmentSize;
  String? _attachmentError;

  @override
  void initState() {
    super.initState();
    if (widget.controller.teachers.length == 1) {
      _teacherId = widget.controller.teachers.single.id;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Create Excuse Letter'),
          leading: IconButton(
            onPressed: widget.controller.isSubmitting
                ? null
                : () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              DropdownButtonFormField<int>(
                initialValue: _teacherId,
                decoration: const InputDecoration(
                  labelText: 'Teacher',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                items: widget.controller.teachers
                    .map(
                      (teacher) => DropdownMenuItem(
                        value: teacher.id,
                        child: Text(teacher.name),
                      ),
                    )
                    .toList(),
                onChanged: widget.controller.isSubmitting
                    ? null
                    : (value) => setState(() => _teacherId = value),
                validator: (value) =>
                    value == null ? 'Select a Teacher.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                enabled: !widget.controller.isSubmitting,
                maxLength: 255,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Example: Fever and colds',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a title.'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                enabled: !widget.controller.isSubmitting,
                onTap: _pickDate,
                decoration: const InputDecoration(
                  labelText: 'Date of absence',
                  hintText: 'Select a date',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  suffixIcon: Icon(Icons.arrow_drop_down_rounded),
                ),
                validator: (_) =>
                    _absentDate == null ? 'Select the absence date.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                enabled: !widget.controller.isSubmitting,
                minLines: 4,
                maxLines: 7,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Reason for absence',
                  hintText: 'Provide a clear reason for the absence.',
                  alignLabelWithHint: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the reason for the absence.'
                    : null,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: widget.controller.isSubmitting
                    ? null
                    : _pickAttachment,
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(
                  _attachment == null
                      ? 'Add JPG, PNG, or PDF'
                      : _attachment!.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_attachment != null && _attachmentSize != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${_formatBytes(_attachmentSize!)} • Maximum 5 MiB',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_attachmentError case final error?) ...[
                const SizedBox(height: 6),
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (widget.controller.actionError case final error?) ...[
                const SizedBox(height: 16),
                _Message(icon: Icons.error_outline_rounded, text: error),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: widget.controller.isSubmitting ? null : _submit,
                icon: widget.controller.isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  widget.controller.isSubmitting
                      ? 'Sending...'
                      : 'Send Excuse Letter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _absentDate ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _absentDate = selected;
      _dateController.text = _formatDate(selected);
    });
  }

  Future<void> _pickAttachment() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (file == null || !mounted) return;
    final size = await file.length();
    if (!mounted) return;
    setState(() {
      if (size == null) {
        _attachment = null;
        _attachmentSize = null;
        _attachmentError = 'The selected file size could not be checked.';
      } else if (size > _maxAttachmentBytes) {
        _attachment = null;
        _attachmentSize = null;
        _attachmentError = 'Choose a file no larger than 5 MiB.';
      } else {
        _attachment = file;
        _attachmentSize = size;
        _attachmentError = null;
      }
    });
  }

  Future<void> _submit() async {
    widget.controller.clearActionError();
    if (!_formKey.currentState!.validate() ||
        _teacherId == null ||
        _absentDate == null ||
        _attachmentError != null) {
      return;
    }
    List<int>? attachmentBytes;
    if (_attachment != null) {
      try {
        attachmentBytes = await _attachment!.readAsBytes();
      } catch (_) {
        if (mounted) {
          setState(() {
            _attachmentError = 'The selected file could not be read.';
          });
        }
        return;
      }
    }
    final submitted = await widget.controller.submit(
      title: _titleController.text,
      absentDate: _absentDate!,
      reason: _reasonController.text,
      teacherId: _teacherId!,
      attachmentBytes: attachmentBytes,
      attachmentName: _attachment?.name,
    );
    if (!mounted || !submitted) return;
    Navigator.pop(context, true);
  }
}

class _LetterCard extends StatelessWidget {
  const _LetterCard({
    required this.letter,
    required this.isDeleting,
    required this.onDelete,
  });

  final ExcuseLetter letter;
  final bool isDeleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = switch (letter.status) {
      'approved' => Colors.green,
      'rejected' => Colors.red,
      'withdrawn' => Colors.grey,
      _ => Colors.orange,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: CircleAvatar(
          child: Icon(Icons.description_outlined, color: color),
        ),
        title: Text(
          letter.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('Absent date: ${letter.absentDate}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _sentenceCase(letter.status),
            style: TextStyle(
              color: color.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(letter.reason),
          if (letter.teacherName case final name?) ...[
            const SizedBox(height: 10),
            Text('Reviewer: $name'),
          ],
          if (letter.reviewNote case final note?) ...[
            const SizedBox(height: 10),
            Text('Review note: $note'),
          ],
          if (letter.attachmentPath != null) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.attach_file_rounded, size: 18),
                SizedBox(width: 5),
                Text('Supporting document attached'),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: isDeleting ? null : onDelete,
              icon: isDeleting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded),
              label: Text(isDeleting ? 'Deleting...' : 'Delete'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(icon, size: 44),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
  }
  return '${(bytes / 1024).toStringAsFixed(0)} KiB';
}

String _sentenceCase(String value) => value.isEmpty
    ? 'Unknown'
    : '${value[0].toUpperCase()}${value.substring(1).replaceAll('_', ' ')}';
