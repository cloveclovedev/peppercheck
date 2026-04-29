import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/features/evidence/data/image_normalizer.dart';

void main() {
  group('NormalizedImage', () {
    test('holds bytes, filename, and mimeType', () {
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]);
      final image = NormalizedImage(
        bytes: bytes,
        filename: 'photo.jpg',
        mimeType: 'image/jpeg',
      );

      expect(image.bytes, equals(bytes));
      expect(image.filename, equals('photo.jpg'));
      expect(image.mimeType, equals('image/jpeg'));
    });
  });

  group('ImageTooLargeException', () {
    test('is an Exception', () {
      expect(ImageTooLargeException(), isA<Exception>());
    });
  });

  group('ImageProcessingException', () {
    test('is an Exception with reason', () {
      final exception = ImageProcessingException('codec failed');
      expect(exception, isA<Exception>());
      expect(exception.toString(), contains('codec failed'));
    });
  });
}
