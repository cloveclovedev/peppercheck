import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// A Sign in with Apple nonce: a random [raw] string sent to Apple as the
/// SHA-256 [sha256Hex], then passed back to Firebase as the raw value to bind
/// the credential and prevent replay.
typedef AppleNonce = ({String raw, String sha256Hex});

const _charset =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz._-';

/// Generates a 32-char random nonce and its SHA-256 hex digest. [rng] is
/// injectable for deterministic tests; production passes `Random.secure()`.
AppleNonce generateAppleNonce([Random? rng]) {
  final random = rng ?? Random.secure();
  final raw = List.generate(
    32,
    (_) => _charset[random.nextInt(_charset.length)],
  ).join();
  final digest = sha256.convert(utf8.encode(raw)).toString();
  return (raw: raw, sha256Hex: digest);
}
