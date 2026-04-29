import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

typedef EncodeFn =
    Future<Uint8List> Function(Uint8List bytes, int longestSide, int quality);

class NormalizedImage {
  NormalizedImage({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
}

class ImageTooLargeException implements Exception {
  @override
  String toString() =>
      'ImageTooLargeException: image still exceeds 5MB after fallback';
}

class ImageProcessingException implements Exception {
  ImageProcessingException(this.reason);
  final String reason;
  @override
  String toString() => 'ImageProcessingException: $reason';
}

class ImageNormalizer {
  ImageNormalizer({EncodeFn? encode}) : _encode = encode ?? _defaultEncode;

  final EncodeFn _encode;

  static const int _maxBytes = 5 * 1024 * 1024;

  Future<NormalizedImage> normalize(XFile image) async {
    final original = await image.readAsBytes();
    final encoded = await _encode(original, 2048, 85);
    if (encoded.lengthInBytes <= _maxBytes) {
      return NormalizedImage(
        bytes: encoded,
        filename: image.name,
        mimeType: 'image/jpeg',
      );
    }
    throw ImageTooLargeException();
  }

  static Future<Uint8List> _defaultEncode(
    Uint8List bytes,
    int longestSide,
    int quality,
  ) async {
    throw UnimplementedError(); // wired in Task 8
  }
}
