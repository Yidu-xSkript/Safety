import 'package:flutter_test/flutter_test.dart';
import 'package:accountability_android/security/pin.dart';

void main() {
  group('Pin', () {
    test('verifies a correct PIN against its stored hash', () {
      final stored = Pin.hash('4821', salt: 'abc');
      expect(Pin.verify('4821', stored), true);
    });
    test('rejects a wrong PIN', () {
      final stored = Pin.hash('4821', salt: 'abc');
      expect(Pin.verify('0000', stored), false);
    });
    test('produces salt:hash format and never stores the raw PIN', () {
      final stored = Pin.hash('4821', salt: 'abc');
      expect(stored.contains('4821'), false);
      expect(stored.split(':').length, 2);
    });
  });
}
