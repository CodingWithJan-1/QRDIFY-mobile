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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Excuse letters')),
    body: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => RefreshIndicator(
        onRefresh: _controller.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'A parent or authorized guardian submits excuse letters for students.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_controller.isLoading && _controller.letters.isEmpty)
              const Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_controller.errorMessage case final message?)
              _EmptyMessage(message: message, onRetry: _controller.load)
            else if (_controller.letters.isEmpty)
              const _EmptyMessage(message: 'No excuse letters yet.')
            else ...[
              const SizedBox(height: 12),
              ..._controller.letters.map(_LetterCard.new),
            ],
          ],
        ),
      ),
    ),
  );
}

class _LetterCard extends StatelessWidget {
  const _LetterCard(this.letter);
  final ExcuseLetter letter;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (letter.status) {
      'approved' => (Colors.green, Icons.check_circle_outline_rounded),
      'rejected' => (Colors.red, Icons.cancel_outlined),
      _ => (Colors.orange, Icons.schedule_rounded),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: CircleAvatar(child: Icon(icon, color: color)),
        title: Text(
          letter.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('Absent date: ${letter.absentDate}'),
        trailing: Text(
          _label(letter.status),
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(letter.reason),
          if (letter.teacherName case final teacher?) ...[
            const SizedBox(height: 8),
            Text('Adviser: $teacher'),
          ],
          if (letter.attachmentPath != null) ...[
            const SizedBox(height: 8),
            const Text('Supporting document attached.'),
          ],
        ],
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      children: [
        const Icon(Icons.description_outlined, size: 42),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
        if (onRetry != null)
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
      ],
    ),
  );
}

String _label(String value) => value.isEmpty
    ? 'Unknown'
    : '${value[0].toUpperCase()}${value.substring(1)}';
