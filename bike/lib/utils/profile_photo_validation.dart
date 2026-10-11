import 'dart:typed_data';

import 'package:image/image.dart' as img;

class ProfilePhotoValidation {
  static const int maxSourceBytes = 20 * 1024 * 1024;
  static const int maxUploadBytes = 4 * 1024 * 1024;

  static String validateAndGetContentType(
    Uint8List bytes, {
    required int maxBytes,
  }) {
    if (bytes.isEmpty) {
      throw const FormatException('The selected image is empty.');
    }
    if (bytes.length > maxBytes) {
      throw FormatException(
        'Image must be smaller than ${maxBytes ~/ (1024 * 1024)} MB.',
      );
    }
    if (_hasJpegSignature(bytes)) return 'image/jpeg';
    if (_hasPngSignature(bytes)) return 'image/png';
    if (_hasWebpSignature(bytes)) return 'image/webp';
    throw const FormatException('Choose a JPG, JPEG, PNG, or WebP image.');
  }

  static Uint8List prepareForUpload(Uint8List bytes) {
    validateAndGetContentType(bytes, maxBytes: maxSourceBytes);
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('The selected image could not be decoded.');
    }
    if (decoded.width * decoded.height > 30 * 1024 * 1024) {
      throw const FormatException('Image dimensions are too large to process.');
    }

    final side = decoded.width < decoded.height
        ? decoded.width
        : decoded.height;
    final square = img.copyCrop(
      decoded,
      x: (decoded.width - side) ~/ 2,
      y: (decoded.height - side) ~/ 2,
      width: side,
      height: side,
    );
    final resized = img.copyResize(
      square,
      width: 512,
      height: 512,
      interpolation: img.Interpolation.average,
    );
    return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
  }

  static bool _hasJpegSignature(Uint8List bytes) =>
      bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF;

  static bool _hasPngSignature(Uint8List bytes) =>
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A;

  static bool _hasWebpSignature(Uint8List bytes) =>
      bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;
}
