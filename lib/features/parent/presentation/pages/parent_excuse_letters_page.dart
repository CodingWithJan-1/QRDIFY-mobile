import '../../../../core/storage/private_file_picker.dart';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/parent_child.dart';
import '../../domain/parent_excuse_letter.dart';
import '../../domain/parent_repository.dart';
import '../widgets/parent_design.dart';

class ParentExcuseLettersPage extends StatefulWidget {
  const ParentExcuseLettersPage({
    required this.accessToken,
    required this.repository,
    required this.child,
    super.key,
  });

  final String accessToken;
  final ParentRepository repository;
  final ParentChild child;

  @override
  State<ParentExcuseLettersPage> createState() =>
      _ParentExcuseLettersPageState();
}

class _ParentExcuseLettersPageState extends State<ParentExcuseLettersPage> {
  List<ParentExcuseLetter> _letters = const [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final letters = await widget.repository.fetchExcuseLetters(
        accessToken: widget.accessToken,
        childId: widget.child.id,
      );
      if (!mounted) return;
      setState(() => _letters = letters);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParentDesign.background,
      appBar: ParentPageHeader(title: 'Excuse letters', child: widget.child),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            ParentChildIdentity(child: widget.child, card: true),
            const SizedBox(height: 14),
            if (widget.child.canSubmitExcuses)
              _submitCard(context)
            else
              _permissionCard(),
            const SizedBox(height: 24),
            const ParentSectionLabel('Submitted letters'),
            const SizedBox(height: 12),
            if (_error != null)
              ParentEmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Letters unavailable',
                message: _error!,
                action: OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              )
            else if (_loading && _letters.isEmpty)
              const Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_letters.isEmpty)
              const ParentEmptyState(
                icon: Icons.description_outlined,
                title: 'No excuse letters yet',
                message: 'Letters submitted for this child will appear here.',
              )
            else
              ..._letters.map(_letterCard),
          ],
        ),
      ),
    );
  }

  Widget _submitCard(BuildContext context) => Card(
    color: ParentDesign.softBlue,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: ParentDesign.line),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.edit_document, color: AppColors.blue, size: 27),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Submit an excuse letter',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'It will go to this child’s section adviser.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _openForm,
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );

  Widget _permissionCard() => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7E6),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFF2D9A4)),
    ),
    child: const Row(
      children: [
        Icon(Icons.lock_outline_rounded, color: Color(0xFF9A6700)),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'This parent link does not have permission to submit excuse letters.',
          ),
        ),
      ],
    ),
  );

  Widget _letterCard(ParentExcuseLetter letter) {
    final (color, icon) = switch (letter.status) {
      'approved' => (AppColors.success, Icons.check_circle_outline_rounded),
      'rejected' => (AppColors.danger, Icons.cancel_outlined),
      _ => (const Color(0xFFF59E0B), Icons.schedule_rounded),
    };
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: ParentDesign.line),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          letter.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('Absent date: ${letter.absentDate}'),
        trailing: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(50),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            child: Text(
              _label(letter.status),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(letter.reason),
          if (letter.teacherName?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text('Adviser: ${letter.teacherName}'),
          ],
          if (letter.submittedByName?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text('Submitted by: ${letter.submittedByName}'),
          ],
          if (letter.attachmentPath?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.attach_file, size: 18),
                SizedBox(width: 5),
                Text('Supporting document attached'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openForm() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _ExcuseLetterForm(onSubmit: _submit)),
    );
    if (submitted != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Excuse letter sent to the child’s adviser.'),
      ),
    );
    await _load();
  }

  Future<bool> _submit({
    required String title,
    required DateTime absentDate,
    required String reason,
    PrivatePickedFile? attachment,
  }) async {
    setState(() => _submitting = true);
    try {
      final attachmentBytes = await attachment?.readAsBytes();
      await widget.repository.submitExcuseLetter(
        accessToken: widget.accessToken,
        childId: widget.child.id,
        title: title,
        absentDate: absentDate,
        reason: reason,
        attachmentBytes: attachmentBytes,
        attachmentName: attachment?.name,
      );
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message(error))));
      }
      return false;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _message(Object error) => switch (error) {
    ApiException exception => exception.message,
    _ => 'Unable to load or submit excuse letters. Please try again.',
  };
}

typedef _SubmitLetter = Future<bool> Function({
  required String title,
  required DateTime absentDate,
  required String reason,
  PrivatePickedFile? attachment,
});

class _ExcuseLetterForm extends StatefulWidget {
  const _ExcuseLetterForm({required this.onSubmit});
  final _SubmitLetter onSubmit;

  @override
  State<_ExcuseLetterForm> createState() => _ExcuseLetterFormState();
}

class _ExcuseLetterFormState extends State<_ExcuseLetterForm> {
  final _key = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _reason = TextEditingController();
  DateTime? _date;
  PrivatePickedFile? _attachment;
  bool _saving = false;
  bool _pickingAttachment = false;
  String? _dateError;
  String? _attachmentError;

  @override
  void dispose() {
    _title.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('New excuse letter'),
      leading: IconButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        icon: const Icon(Icons.close),
      ),
    ),
    body: Form(
      key: _key,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(20),
        children: [
          _textField(_title, 'Title', 'e.g. Fever and colds'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              _date == null
                  ? 'Choose absence date'
                  : _date!.toLocal().toString().split(' ').first,
            ),
          ),
          if (_dateError != null) ...[
            const SizedBox(height: 6),
            Text(
              _dateError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          _textField(
            _reason,
            'Reason',
            'Explain the reason for the absence',
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _saving || _pickingAttachment ? null : _pickAttachment,
            icon: const Icon(Icons.attach_file_rounded),
            label: Text(
              _pickingAttachment
                  ? 'Opening file…'
                  : _attachment == null
                  ? 'Attach supporting file (optional)'
                  : 'Replace attachment',
            ),
          ),
          if (_attachment case final file?) ...[
            const SizedBox(height: 12),
            _attachmentPreview(file),
          ],
          if (_attachmentError != null) ...[
            const SizedBox(height: 6),
            Text(
              _attachmentError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 6),
          const Text(
            'JPG, PNG, or PDF up to 5 MiB.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving || _pickingAttachment ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(_saving ? 'Sending…' : 'Send to adviser'),
          ),
        ],
      ),
    ),
  );

  Widget _attachmentPreview(PrivatePickedFile file) {
    final isImage = const [
      'jpg',
      'jpeg',
      'png',
    ].contains(file.name.split('.').last.toLowerCase());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: ParentDesign.softBlue,
              child: Image.memory(
                file.bytes,
                key: ValueKey(file),
                height: 200,
                fit: BoxFit.contain,
                cacheWidth: 1200,
                semanticLabel: 'Selected supporting image',
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 100,
                  child: Center(child: Text('Image preview unavailable')),
                ),
              ),
            ),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
          ),
          title: Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${isImage ? 'Image' : 'PDF document'} • ${(file.bytes.length / 1024).ceil()} KB',
          ),
          trailing: IconButton(
            tooltip: 'Remove attachment',
            onPressed: _saving || _pickingAttachment
                ? null
                : () => setState(() {
                    _attachment = null;
                    _attachmentError = null;
                  }),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ],
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    String hint, {
    int maxLines = 1,
  }) => TextFormField(
    controller: controller,
    enabled: !_saving,
    maxLines: maxLines,
    maxLength: label == 'Title' ? 120 : 5000,
    validator: (value) => value == null || value.trim().isEmpty
        ? 'This field is required.'
        : null,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    ),
  );

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (date != null && mounted) {
      setState(() {
        _date = date;
        _dateError = null;
      });
    }
  }

  Future<void> _pickAttachment() async {
    if (_pickingAttachment || _saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _pickingAttachment = true);
    try {
      final file = await PrivateFilePicker.pickFile(
        maxBytes: 5 * 1024 * 1024,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (file == null || !mounted) return;
      setState(() {
        _attachment = file;
        _attachmentError = null;
      });
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _attachmentError = error.message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _attachmentError = 'Could not read the selected file.';
        });
      }
    } finally {
      if (mounted) setState(() => _pickingAttachment = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _pickingAttachment) return;
    FocusScope.of(context).unfocus();
    final valid = _key.currentState!.validate();
    setState(
      () => _dateError = _date == null ? 'Choose the date of absence.' : null,
    );
    if (!valid || _date == null || _attachmentError != null) return;
    setState(() => _saving = true);
    final submitted = await widget.onSubmit(
      title: _title.text.trim(),
      absentDate: _date!,
      reason: _reason.text.trim(),
      attachment: _attachment,
    );
    if (submitted && mounted) Navigator.pop(context, true);
    if (mounted) setState(() => _saving = false);
  }
}

String _label(String value) => value.isEmpty
    ? 'Unknown'
    : '${value[0].toUpperCase()}${value.substring(1)}';
