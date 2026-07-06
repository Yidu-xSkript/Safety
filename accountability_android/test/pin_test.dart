import 'package:flutter_test/flutter_test.dart';
import 'package:accountability_android/security/pin.dart';

void main() {
  group('Pin', () {
    test('verifies a correct PIN against its stored hash', () {
      final stored = Pin.hash('482193', salt: 'abc', iterations: 1000);
      expect(Pin.verify('482193', stored), true);
    });
    test('rejects a wrong PIN', () {
      final stored = Pin.hash('482193', salt: 'abc', iterations: 1000);
      expect(Pin.verify('000000', stored), false);
    });
    test('is PBKDF2 format and never stores the raw PIN', () {
      final stored = Pin.hash('482193', salt: 'abc', iterations: 1000);
      expect(stored.contains('482193'), false);
      final parts = stored.split(':');
      expect(parts.length, 4);
      expect(parts[0], 'pbkdf2');
    });
    test('uses a random salt so two hashes of the same PIN differ, and verify still works', () {
      final a = Pin.hash('482193', iterations: 1000);
      final b = Pin.hash('482193', iterations: 1000);
      expect(a == b, false);                 // random salt
      expect(Pin.verify('482193', a), true);
      expect(Pin.verify('000000', a), false);
    });
  });
}
