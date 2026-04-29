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
  ImageNormalizer({EncodeFn? encode});

  Future<NormalizedImage> normalize(XFile image) {
    throw UnimplementedError();
  }
}
