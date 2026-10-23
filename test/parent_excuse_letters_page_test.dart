import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrdify/core/theme/app_theme.dart';
import 'package:qrdify/features/parent/domain/parent_child.dart';
import 'package:qrdify/features/parent/domain/parent_excuse_letter.dart';
import 'package:qrdify/features/parent/domain/parent_repository.dart';
import 'package:qrdify/features/parent/presentation/pages/parent_excuse_letters_page.dart';

void main() {
  testWidgets(
    'previews, replaces, and removes attachments without losing a cancelled selection',
    (tester) async {
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      final previousPicker = FilePickerPlatform.instance;
      FilePickerPlatform.instance = _Picker([
        _PickedFile('first.png', png),
        null,
        _PickedFile('second.PNG', png),
        _PickedFile(
          'proof.pdf',
          Uint8List.fromList(utf8.encode('%PDF synthetic')),
        ),
      ]);
      addTearDown(() => FilePickerPlatform.instance = previousPicker);
      await _pumpPage(tester, _ParentRepository());
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      Future<void> pick(String label) async {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await pick('Attach supporting file (optional)');
      expect(find.text('first.png'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Image preview unavailable'), findsNothing);
      await pick('Replace attachment'); // Cancel keeps the first image.
      expect(find.text('first.png'), findsOneWidget);
      await pick('Replace attachment');
      expect(find.text('first.png'), findsNothing);
      expect(find.text('second.PNG'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Remove attachment'));
      await tester.tap(find.byTooltip('Remove attachment'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('second.PNG'), findsNothing);
      await pick('Attach supporting file (optional)');
      expect(find.text('proof.pdf'), findsOneWidget);
      expect(find.textContaining('PDF document'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keyboard resizes the form once without leaving a blank gap', (
    tester,
  ) async {
    await _pumpPage(tester, _ParentRepository());
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    final reason = find.byType(TextFormField).at(1);
    await tester.showKeyboard(reason);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byType(Form)).bottom, closeTo(544, 1));
    await tester.enterText(reason, 'Resting at home.');
    expect(find.text('Resting at home.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 384.0]) {
    for (final textScale in [1.0, 1.5]) {
      testWidgets(
        'Create stays visible at width $width and text scale $textScale',
        (tester) async {
          await _pumpPage(
            tester,
            _ParentRepository(),
            width: width,
            textScale: textScale,
          );

          final heading = tester.getRect(find.text('Submit an excuse letter'));
          final button = tester.getRect(
            find.widgetWithText(FilledButton, 'Create'),
          );
          expect(heading.height, lessThan(120));
          expect(heading.width, greaterThan(150));
          expect(button.right, lessThanOrEqualTo(width));
          expect(button.bottom, lessThan(844));
          expect(tester.takeException(), isNull);

          await tester.tap(find.text('Create'));
          await tester.pumpAndSettle();
          expect(find.text('New excuse letter'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'a missing date can be corrected and the selected child letter submitted',
    (tester) async {
      final repository = _ParentRepository();
      await _pumpPage(tester, repository);
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Fever');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Resting at home.',
      );
      await tester.ensureVisible(find.text('Send to adviser'));
      await tester.tap(find.text('Send to adviser'));
      await tester.pumpAndSettle();
      expect(repository.submitCalls, 0);
      expect(find.text('Choose the date of absence.'), findsOneWidget);

      await tester.ensureVisible(find.text('Choose absence date'));
      await tester.tap(find.text('Choose absence date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Choose the date of absence.'), findsNothing);
      await tester.ensureVisible(find.text('Send to adviser'));
      await tester.tap(find.text('Send to adviser'));
      await tester.pumpAndSettle();

      expect(repository.submitCalls, 1);
      expect(repository.submittedChildId, 15);
      expect(find.text('New excuse letter'), findsNothing);
      expect(find.text('Fever'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.textContaining('Excuse letter sent'), findsOneWidget);
    },
  );

  testWidgets('a parent without excuse permission cannot open submission', (
    tester,
  ) async {
    await _pumpPage(tester, _ParentRepository(), canSubmit: false);
    expect(find.text('Create'), findsNothing);
    expect(find.textContaining('does not have permission'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  ParentRepository repository, {
  double width = 384,
  double textScale = 1,
  bool canSubmit = true,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: ParentExcuseLettersPage(
        accessToken: 'parent-token',
        repository: repository,
        child: ParentChild(
          id: 15,
          name: 'Sample Child',
          grade: 'Grade 1',
          section: 'Rizal',
          relationship: 'parent',
          canViewLocation: false,
          canSubmitExcuses: canSubmit,
          historyVisibleFrom: '2026-09-01',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Picker extends FilePickerPlatform {
  _Picker(this.files);
  final List<PlatformFile?> files;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => files.removeAt(0);
}

final class _PickedFile extends PlatformFile {
  _PickedFile(this.name, this.bytes);
  @override
  final String name;
  final Uint8List bytes;
  @override
  Future<int?> length() async => bytes.length;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ParentRepository implements ParentRepository {
  final letters = <ParentExcuseLetter>[];
  int submitCalls = 0;
  int? submittedChildId;

  @override
  Future<List<ParentExcuseLetter>> fetchExcuseLetters({
    required String accessToken,
    required int childId,
  }) async => List.of(letters);

  @override
  Future<ParentExcuseLetter> submitExcuseLetter({
    required String accessToken,
    required int childId,
    required String title,
    required DateTime absentDate,
    required String reason,
    List<int>? attachmentBytes,
    String? attachmentName,
  }) async {
    expect(accessToken, 'parent-token');
    expect(title, 'Fever');
    expect(reason, 'Resting at home.');
    expect(attachmentBytes, isNull);
    submitCalls++;
    submittedChildId = childId;
    final letter = ParentExcuseLetter(
      id: 41,
      title: title,
      absentDate: absentDate.toIso8601String(),
      reason: reason,
      status: 'pending',
      teacherName: 'Assigned Adviser',
    );
    letters.add(letter);
    return letter;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
