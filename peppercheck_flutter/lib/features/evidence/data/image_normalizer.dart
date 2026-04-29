import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
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
  ImageProcessingException(this.reason, {this.cause});
  final String reason;
  final Object? cause;
  @override
  String toString() => 'ImageProcessingException: $reason';
}

class ImageNormalizer {
  ImageNormalizer({EncodeFn? encode}) : _encode = encode ?? _defaultEncode;

  final EncodeFn _encode;

  static const int _maxBytes = 5 * 1024 * 1024;

  Future<NormalizedImage> normalize(XFile image) async {
    final original = await image.readAsBytes();
    const steps = [(2048, 85), (1536, 85), (1024, 85)];
    for (final (side, quality) in steps) {
      Uint8List encoded;
      try {
        encoded = await _encode(original, side, quality);
      } catch (e, st) {
        Error.throwWithStackTrace(
          ImageProcessingException(e.toString(), cause: e),
          st,
        );
      }
      if (encoded.isEmpty) {
        throw ImageProcessingException('encoder returned empty bytes');
      }
      if (encoded.lengthInBytes <= _maxBytes) {
        return NormalizedImage(
          bytes: encoded,
          filename: _toJpgFilename(image.name),
          mimeType: 'image/jpeg',
        );
      }
    }
    throw ImageTooLargeException();
  }

  static String _toJpgFilename(String name) {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex <= 0) return '$name.jpg';
    return '${name.substring(0, dotIndex)}.jpg';
  }

  static Future<Uint8List> _defaultEncode(
    Uint8List bytes,
    int longestSide,
    int quality,
  ) async {
    // Both axes set to longestSide so the plugin fits the longer dimension
    // to that bound while preserving aspect ratio.
    return FlutterImageCompress.compressWithList(
      bytes,
      minWidth: longestSide,
      minHeight: longestSide,
      quality: quality,
      format: CompressFormat.jpeg,
    );
  }
}
