import 'package:file_picker/file_picker.dart';

import 'dart:typed_data';

class PrivatePickedFile {
  const PrivatePickedFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
  Future<int> length() async => bytes.length;
  Future<Uint8List> readAsBytes() async => bytes;
}

abstract final class PrivateFilePicker {
  static Future<PrivatePickedFile?> pickFile({
    required List<String> allowedExtensions,
    required int maxBytes,
  }) async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );
      if (file == null) return null;
      final length = await file.length();
      if (length == null || length > maxBytes) {
        throw FormatException(
          'Choose a file no larger than ${maxBytes ~/ (1024 * 1024)} MiB.',
        );
      }
      final chunks = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
        if (chunks.length + chunk.length > maxBytes) {
          throw const FormatException('The selected file is too large.');
        }
        chunks.add(chunk);
      }
      // Only a bounded memory copy survives. Cleanup never deletes the original.
      return PrivatePickedFile(file.name, chunks.takeBytes());
    } finally {
      await clearTemporaryFiles();
    }
  }

  static Future<void> clearTemporaryFiles() async {
    try {
      await FilePicker.clearTemporaryFiles();
    } on Object {
      /* Retry at startup/logout. */
    }
  }
}
