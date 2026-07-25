import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/features/auth/data/apple_nonce.dart';

void main() {
  test('sha256Hex is the SHA-256 of the raw nonce', () {
    final nonce = generateAppleNonce(Random(1));
    final expected = sha256.convert(utf8.encode(nonce.raw)).toString();
    expect(nonce.sha256Hex, expected);
  });

  test('raw nonce is sufficiently long and URL-safe', () {
    final nonce = generateAppleNonce(Random(2));
    expect(nonce.raw.length, greaterThanOrEqualTo(32));
    expect(RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(nonce.raw), isTrue);
  });
}
