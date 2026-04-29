import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
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

  group('ImageNormalizer.normalize - happy path', () {
    test(
      'returns step 1 bytes when first encoded result is under 5MB',
      () async {
        final fakeXFile = XFile.fromData(
          Uint8List.fromList([0x01, 0x02, 0x03]),
          path: 'photo.jpg',
        );
        final encodedBytes = Uint8List(1024 * 1024); // 1MB

        Future<Uint8List> fakeEncode(
          Uint8List bytes,
          int longestSide,
          int quality,
        ) async {
          expect(longestSide, equals(2048));
          expect(quality, equals(85));
          return encodedBytes;
        }

        final normalizer = ImageNormalizer(encode: fakeEncode);
        final result = await normalizer.normalize(fakeXFile);

        expect(result.bytes, equals(encodedBytes));
        expect(result.filename, equals('photo.jpg'));
        expect(result.mimeType, equals('image/jpeg'));
      },
    );

    test('falls back to step 2 (1536px) when step 1 exceeds 5MB', () async {
      final fakeXFile = XFile.fromData(
        Uint8List.fromList([0x01]),
        path: 'photo.jpg',
      );
      final step2Bytes = Uint8List(2 * 1024 * 1024); // 2MB

      Future<Uint8List> fakeEncode(
        Uint8List bytes,
        int longestSide,
        int quality,
      ) async {
        if (longestSide == 2048) return Uint8List(6 * 1024 * 1024); // 6MB
        if (longestSide == 1536) return step2Bytes;
        fail('unexpected longestSide: $longestSide');
      }

      final normalizer = ImageNormalizer(encode: fakeEncode);
      final result = await normalizer.normalize(fakeXFile);

      expect(result.bytes, equals(step2Bytes));
    });
  });
}
