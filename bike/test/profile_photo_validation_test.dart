import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:bikers/utils/profile_photo_validation.dart';

void main() {
  group('ProfilePhotoValidation', () {
    test('accepts JPEG, PNG, and WebP image signatures', () {
      expect(
        ProfilePhotoValidation.validateAndGetContentType(
          Uint8List.fromList([0xFF, 0xD8, 0xFF]),
          maxBytes: 100,
        ),
        'image/jpeg',
      );
      expect(
        ProfilePhotoValidation.validateAndGetContentType(
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
          maxBytes: 100,
        ),
        'image/png',
      );
      expect(
        ProfilePhotoValidation.validateAndGetContentType(
          Uint8List.fromList([
            0x52,
            0x49,
            0x46,
            0x46,
            0,
            0,
            0,
            0,
            0x57,
            0x45,
            0x42,
            0x50,
          ]),
          maxBytes: 100,
        ),
        'image/webp',
      );
    });

    test('rejects unsupported, empty, and oversized images', () {
      expect(
        () => ProfilePhotoValidation.validateAndGetContentType(
          Uint8List(0),
          maxBytes: 10,
        ),
        throwsFormatException,
      );
      expect(
        () => ProfilePhotoValidation.validateAndGetContentType(
          Uint8List.fromList([1, 2, 3]),
          maxBytes: 10,
        ),
        throwsFormatException,
      );
      expect(
        () => ProfilePhotoValidation.validateAndGetContentType(
          Uint8List.fromList([0xFF, 0xD8, 0xFF, 0]),
          maxBytes: 3,
        ),
        throwsFormatException,
      );
    });

    test('prepares a square compressed JPEG no larger than 512 pixels', () {
      final source = img.Image(width: 800, height: 400);
      final bytes = Uint8List.fromList(img.encodePng(source));

      final prepared = ProfilePhotoValidation.prepareForUpload(bytes);
      final decoded = img.decodeImage(prepared);

      expect(
        ProfilePhotoValidation.validateAndGetContentType(
          prepared,
          maxBytes: ProfilePhotoValidation.maxUploadBytes,
        ),
        'image/jpeg',
      );
      expect(decoded?.width, 512);
      expect(decoded?.height, 512);
    });
  });
}
