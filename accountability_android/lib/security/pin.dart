import 'dart:convert';
import 'package:crypto/crypto.dart';

class Pin {
  // Stored form is "salt:sha256(salt+pin)". Raw PIN is never persisted.
  static String hash(String pin, {required String salt}) {
    final digest = sha256.convert(utf8.encode('$salt$pin')).toString();
    return '$salt:$digest';
  }

  static bool verify(String pin, String stored) {
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    return hash(pin, salt: parts[0]) == stored;
  }
}
