import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

abstract final class ProfilePhotoProcessor {
  static const maxSourceBytes = 10 * 1024 * 1024;

  static Future<Uint8List> prepare(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxSourceBytes) {
      throw const FormatException('Choose a photo no larger than 10 MiB.');
    }
    final jpg =
        bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
    final png =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47;
    final webp =
        bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    if (!jpg && !png && !webp) {
      throw const FormatException('Choose a valid JPG, PNG or WebP photo.');
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (math.max(descriptor.width, descriptor.height) > 8192 ||
          descriptor.width * descriptor.height > 40000000) {
        throw const FormatException(
          'Choose a photo no larger than 8192 pixels per side and 40 megapixels.',
        );
      }
      final scale = math.min(
        1.0,
        512 / math.max(descriptor.width, descriptor.height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      image = (await codec.getNextFrame()).image;
      final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
      if (encoded == null || encoded.lengthInBytes > 2 * 1024 * 1024) {
        throw const FormatException(
          'This photo could not be resized. Choose a smaller image.',
        );
      }
      return encoded.buffer.asUint8List(
        encoded.offsetInBytes,
        encoded.lengthInBytes,
      );
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException(
        'The selected photo could not be opened. Choose another image.',
      );
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}
