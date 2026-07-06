import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

// PIN hashing. Upgraded from a single SHA-256 with a time-based salt (rainbow-table-able, no work
// factor — audit #13) to PBKDF2-HMAC-SHA256 with a RANDOM salt and an iteration work factor.
// Stored form: "pbkdf2:<iterations>:<saltB64url>:<dkB64>". The raw PIN is never persisted.
// NOTE: a short numeric PIN has a tiny search space, so this is friction, not a hard lock — pair it
// with a longer PIN (the setup wizard now requires 6+).
class Pin {
  static const _defaultIterations = 100000;

  static String hash(String pin, {String? salt, int iterations = _defaultIterations}) {
    final saltStr = salt ?? _randomSalt();
    final dk = _pbkdf2(utf8.encode(pin), utf8.encode(saltStr), iterations, 32);
    return 'pbkdf2:$iterations:$saltStr:${base64.encode(dk)}';
  }

  static bool verify(String pin, String stored) {
    final parts = stored.split(':');
    if (parts.length != 4 || parts[0] != 'pbkdf2') return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1) return false;
    final dk = _pbkdf2(utf8.encode(pin), utf8.encode(parts[2]), iterations, 32);
    return _constEq(base64.encode(dk), parts[3]);
  }

  static String _randomSalt() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  // PBKDF2 for a single output block (dkLen <= 32 = SHA-256 output). U1 = HMAC(salt||INT(1)),
  // Ui = HMAC(U(i-1)), DK = U1 xor U2 xor ... xor Un.
  static List<int> _pbkdf2(List<int> pass, List<int> salt, int iterations, int dkLen) {
    final hmac = Hmac(sha256, pass);
    var u = hmac.convert(<int>[...salt, 0, 0, 0, 1]).bytes;
    final result = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result.sublist(0, dkLen);
  }

  // Constant-time comparison so verification time doesn't leak how many chars matched.
  static bool _constEq(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
